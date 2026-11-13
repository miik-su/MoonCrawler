///|
priv struct Catalog {
  config : @core.Config
  tasks : Array[@core.Task]
  saved_at : Int64
  sequence : Int32
  job_id : String
  records : Array[String]
  pages : Map[String, (Int32, Int32)]
  selected : Map[Int32, Bool]
  max_batch_pages : Int32
  checkpoint_records : Int32
  checkpoint_sequence : Int32
}

///|
/// Validate one bounded record at a time and retain identities/locations, not bodies.
async fn scan_catalog(
  directory : String,
  retain~ : (Array[@core.Page]) -> Unit = _ => (),
) -> Catalog {
  let raw = unwrapped(directory + "/index.json")
  if raw is Object(fields) && fields.get("config") is Some(config) {
    fields["config"] = @core.upgrade_config(config)
  }
  let index : Index = @json.from_json(raw)
  if index.format != 2 ||
    index.sequence < 0 ||
    index.saved_at < 0L ||
    index.job_id.is_empty() {
    raise @core.Storage("invalid job index")
  }
  index.config.validate()
  if index.shards.length() > index.config.max_pages * 2 + 2 {
    raise @core.Capacity("oversized shard index")
  }
  let records : Array[String] = []
  let unique : Map[String, Bool] = Map([])
  for name in index.shards {
    if !name.has_prefix("shard-") ||
      !name.has_suffix(".json") ||
      name.contains_any(chars="/\\:") ||
      unique.contains(name) {
      raise @core.Storage("invalid or duplicate shard path")
    }
    unique[name] = true
    records.push(name)
  }
  let events : Array[Int32] = []
  for name in @fs.readdir(directory) {
    if name.has_prefix("event-") && name.has_suffix(".json") {
      let seq = @string.parse_int(name[6:name.length() - 5]) catch {
        _ => raise @core.Storage("invalid journal filename")
      }
      if seq <= 0 || name != "event-\{seq}.json" {
        raise @core.Storage("noncanonical journal filename")
      }
      if seq > index.sequence {
        events.push(seq)
      }
    }
  }
  events.sort()
  for seq in events {
    records.push("event-\{seq}.json")
  }
  let tasks : Map[String, @core.Task] = Map([])
  let pages : Map[String, (Int32, Int32)] = Map([])
  let ledger = @core.PageLedger::new()
  let mut sequence = index.sequence
  let mut saved_at = index.saved_at
  let mut max_batch_pages = 0
  for record in 0..<records.length() {
    let delta : Delta = @json.from_json(
      unwrapped(directory + "/" + records[record]),
    )
    let checkpoint = record < index.shards.length()
    let expected = if checkpoint { index.sequence } else { sequence + 1 }
    if !checkpoint && events[record - index.shards.length()] != expected {
      raise @core.Storage("journal sequence gap")
    }
    if delta.sequence != expected ||
      delta.job_id != index.job_id ||
      delta.saved_at < 0L {
      raise @core.Storage("record sequence, identity or time mismatch")
    }
    for task in delta.tasks {
      @core.validate_task(index.config, task)
      let key = task.request.url.key(include_query=index.config.include_query)
      if checkpoint && tasks.contains(key) {
        raise @core.Storage("duplicate checkpoint task")
      }
      tasks[key] = task
      if tasks.length() > index.config.max_pages {
        raise @core.Capacity("too many recovered tasks")
      }
    }
    ledger.commit(index.config, delta.pages)
    retain(delta.pages)
    max_batch_pages = max_batch_pages.max(delta.pages.length())
    for i in 0..<delta.pages.length() {
      let key = delta.pages[i].url
      if checkpoint && pages.contains(key) {
        raise @core.Storage("duplicate checkpoint page")
      }
      pages[key] = (record, i)
    }
    if !checkpoint {
      sequence = expected
      saved_at = delta.saved_at
    }
  }
  let selected : Map[Int32, Bool] = Map([])
  for location in pages.values() {
    selected[location.0] = true
  }
  {
    config: index.config,
    tasks: tasks.values().to_array(),
    saved_at,
    sequence,
    job_id: index.job_id,
    records,
    pages,
    selected,
    max_batch_pages,
    checkpoint_records: index.shards.length(),
    checkpoint_sequence: index.sequence,
  }
}

///|
async fn Catalog::read_record(
  self : Catalog,
  directory : String,
  record : Int32,
) -> Delta {
  let delta : Delta = @json.from_json(
    unwrapped(directory + "/" + self.records[record]),
  )
  let expected = if record < self.checkpoint_records {
    self.checkpoint_sequence
  } else {
    self.checkpoint_sequence + record - self.checkpoint_records + 1
  }
  if delta.job_id != self.job_id || delta.sequence != expected {
    raise @core.Storage("record identity or sequence changed")
  }
  delta
}

///|
async fn Catalog::visit(
  self : Catalog,
  directory : String,
  visit : async (@core.Page) -> Unit,
) -> Unit {
  for record in 0..<self.records.length() {
    // Do not decode task-only or wholly superseded records twice.
    if !self.selected.contains(record) {
      continue
    }
    let delta = self.read_record(directory, record)
    for i in 0..<delta.pages.length() {
      let page = delta.pages[i]
      if self.pages.get(page.url) == Some((record, i)) {
        visit(page)
      }
    }
  }
}
