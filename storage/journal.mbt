///|
priv struct Index {
  job_id : String
  format : Int32
  sequence : Int32
  config : @core.Config
  saved_at : Int64
  shards : Array[String]
} derive(ToJson, FromJson)

///|
priv struct Delta {
  job_id : String
  sequence : Int32
  tasks : Array[@core.Task]
  pages : Array[@core.Page]
  saved_at : Int64
} derive(ToJson, FromJson)

///|
priv struct Envelope {
  payload : String
  checksum : UInt64
} derive(ToJson, FromJson)

///|
fn checksum(text : String) -> UInt64 {
  for byte in @utf8.encode(text); hash = 14695981039346656037UL {
    continue (hash ^ byte.to_uint64()) * 1099511628211UL
  } nobreak {
    hash
  }
}

///|
fn wrap(value : Json) -> String {
  let payload = value.stringify()
  @json.to_json(Envelope::{ payload, checksum: checksum(payload), }).stringify()
}

///|
async fn bounded_read(path : String, limit~ : Int32 = 16777216) -> String {
  if @fs.kind(path, follow_symlink=false) != Regular {
    raise @core.Storage("expected regular job file")
  }
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  let bytes = Buffer()
  while file.read_some(max_len=8192) is Some(chunk) {
    if bytes.length() + chunk.length() > limit {
      raise @core.Capacity("job record exceeds bounded read")
    }
    bytes.write_bytes(chunk)
  }
  @utf8.decode(bytes.to_bytes())
}

///|
async fn unwrapped(path : String) -> Json {
  let e : Envelope = @json.from_json(
    @json.parse(bounded_read(path), reject_duplicate_keys=true),
  )
  if checksum(e.payload) != e.checksum {
    raise @core.Storage("job record checksum mismatch")
  }
  @json.parse(e.payload, reject_duplicate_keys=true)
}

///|
fn nonce() -> String raise @core.CrawlError {
  guard @env.rand(16) is Some(bytes) else {
    raise @core.Storage("OS randomness unavailable")
  }
  bytes.iter().map(b => b.to_int().to_string()).to_array().join("-")
}

///|
async fn atomic_file(
  directory : String,
  name : String,
  text : String,
  replace~ : Bool = false,
  probe~ : async (String) -> Unit = _ => (),
) -> Unit {
  if @utf8.encode(text).length() > 16777216 {
    raise @core.Capacity("job record exceeds write limit")
  }
  let temp = directory + "/staging-" + nonce() + ".tmp"
  @fs.write_file(temp, text, create_mode=CreateNew, permission=0o600, sync=Full)
  let stage = if name == "index.json" {
    "checkpoint"
  } else if name.has_prefix("event-") {
    "event"
  } else {
    "shard"
  }
  probe(stage + "_staged")
  @fs.rename(temp, directory + "/" + name, replace~)
  probe(stage + "_published")
}

///|
pub async fn read_text(path : String, limit~ : Int32 = 1048576) -> String {
  bounded_read(path, limit~)
}

///|
pub fn apply_batch(
  previous : Snapshot,
  tasks : Array[@core.Task],
  pages : Array[@core.Page],
  now : Int64,
) -> Snapshot raise @core.CrawlError {
  let task_map : Map[String, @core.Task] = Map([])
  let page_map : Map[String, @core.Page] = Map([])
  for t in previous.tasks {
    task_map[t.request.url.key(include_query=previous.config.include_query)] = t
  }
  for p in previous.pages {
    page_map[p.url] = p
  }
  for t in tasks {
    @core.validate_task(previous.config, t)
    task_map[t.request.url.key(include_query=previous.config.include_query)] = t
  }
  for p in pages {
    @core.validate_page(previous.config, p) |> ignore
    page_map[p.url] = p
  }
  {
    ..previous,
    tasks: task_map.values().to_array(),
    pages: page_map.values().to_array(),
    saved_at: now,
  }
}

///|
async fn FileStore::write_checkpoint(
  self : FileStore,
  snapshot : Snapshot,
) -> Unit {
  validate(snapshot)
  if self.job_id.is_empty() {
    self.job_id = nonce()
  }
  let prefix = "shard-" + nonce()
  let shards : Array[String] = []
  for i = 0; i < snapshot.tasks.length(); i = i + 128 {
    let name = "\{prefix}-t-\{i}.json"
    let tasks = snapshot.tasks[i:(i + 128).min(snapshot.tasks.length())].to_owned()
    atomic_file(
      self.directory,
      name,
      wrap(
        @json.to_json(Delta::{
          job_id: self.job_id,
          sequence: self.sequence,
          tasks,
          pages: [],
          saved_at: snapshot.saved_at,
        }),
      ),
    )
    shards.push(name)
  }
  let batch : Array[@core.Page] = []
  let mut used = 0
  let mut part = 0
  for page in snapshot.pages {
    let size = @utf8.encode(@json.to_json(page).stringify()).length() * 2 + 256
    if !batch.is_empty() && (used + size > 8388608 || batch.length() >= 128) {
      shards.push(self.page_shard(prefix, part, batch, snapshot.saved_at))
      part += 1
      batch.clear()
      used = 0
    }
    batch.push(page)
    used += size
  }
  if !batch.is_empty() {
    shards.push(self.page_shard(prefix, part, batch, snapshot.saved_at))
  }
  let index = Index::{
    job_id: self.job_id,
    format: 2,
    sequence: self.sequence,
    config: snapshot.config,
    saved_at: snapshot.saved_at,
    shards,
  }
  atomic_file(
    self.directory,
    "index.json",
    wrap(@json.to_json(index)),
    replace=true,
    probe=self.probe,
  )
  self.job_config = Some(snapshot.config)
  self.ledger = @core.PageLedger::new()
  self.ledger.commit(snapshot.config, snapshot.pages)
  (self.probe)("cleanup_started")
  for name in @fs.readdir(self.directory) {
    let old_shard = name.has_prefix("shard-") &&
      name.has_suffix(".json") &&
      !name.has_prefix(prefix)
    let old_event = if name.has_prefix("event-") && name.has_suffix(".json") {
      let seq = @string.parse_int(name[6:name.length() - 5]) catch { _ => -1 }
      seq >= 0 && seq <= self.sequence
    } else {
      false
    }
    if old_shard || old_event {
      @fs.remove(self.directory + "/" + name) catch {
        _ => ()
      }
    }
  }
}

///|
pub impl Storage for FileStore with fn commit_batch(
  self,
  config,
  tasks,
  pages,
  now,
) {
  config.validate()
  guard self.job_config is Some(current) &&
    current == config &&
    !self.job_id.is_empty() else {
    raise @core.Storage(
      "journal requires an initialized job with unchanged config",
    )
  }
  for task in tasks {
    @core.validate_task(config, task)
  }
  let sequence = self.sequence + 1
  self.ledger.check(config, pages) |> ignore
  let record = wrap(
    @json.to_json(Delta::{
      job_id: self.job_id,
      sequence,
      tasks,
      pages,
      saved_at: now,
    }),
  )
  if @utf8.encode(record).length() > 16777216 {
    raise @core.Capacity("incremental batch exceeds 16 MiB")
  }
  atomic_file(
    self.directory,
    "event-\{sequence}.json",
    record,
    probe=self.probe,
  )
  self.sequence = sequence
  self.ledger.commit(config, pages)
}

///|
async fn recover(directory : String) -> (Snapshot?, Int32, String) {
  if !@fs.exists(directory + "/index.json") {
    if !@fs.exists(directory + "/checkpoint.json") {
      return (None, 0, "")
    }
    let legacy = decode_snapshot(
      @json.parse(bounded_read(directory + "/checkpoint.json", limit=67108864)),
    )
    validate(legacy)
    return (Some(legacy), 0, "")
  }
  let index_json = unwrapped(directory + "/index.json")
  if index_json is Object(fields) {
    if fields.get("config") is Some(config) {
      fields["config"] = @core.upgrade_config(config)
    }
  }
  let index : Index = @json.from_json(index_json)
  if index.format != 2 || index.sequence < 0 {
    raise @core.Storage("unsupported job index")
  }
  let mut snapshot = Snapshot::{
    version: 1,
    config: index.config,
    tasks: [],
    pages: [],
    saved_at: index.saved_at,
  }
  let tasks : Map[String, @core.Task] = Map([])
  let pages : Map[String, @core.Page] = Map([])
  let ledger = @core.PageLedger::new()
  for name in index.shards {
    if !name.has_prefix("shard-") || name.contains_any(chars="/\\:") {
      raise @core.Storage("invalid shard path")
    }
    let shard : Delta = @json.from_json(unwrapped(directory + "/" + name))
    if shard.sequence != index.sequence || shard.job_id != index.job_id {
      raise @core.Storage("checkpoint sequence mismatch")
    }
    for task in shard.tasks {
      tasks[task.request.url.key(include_query=index.config.include_query)] = task
    }
    for page in shard.pages {
      pages[page.url] = page
    }
    ledger.commit(index.config, shard.pages)
  }
  let mut sequence = index.sequence
  let events : Array[Int32] = []
  for name in @fs.readdir(directory) {
    if name.has_prefix("event-") && name.has_suffix(".json") {
      let seq = @string.parse_int(name[6:name.length() - 5]) catch {
        _ => raise @core.Storage("invalid journal filename")
      }
      if seq > sequence {
        events.push(seq)
      }
    }
  }
  events.sort()
  for seq in events {
    if seq != sequence + 1 {
      raise @core.Storage("journal sequence gap")
    }
    let delta : Delta = @json.from_json(
      unwrapped(directory + "/event-\{seq}.json"),
    )
    if delta.sequence != seq || delta.job_id != index.job_id {
      raise @core.Storage("journal sequence mismatch")
    }
    for task in delta.tasks {
      tasks[task.request.url.key(include_query=index.config.include_query)] = task
    }
    for page in delta.pages {
      pages[page.url] = page
    }
    ledger.commit(index.config, delta.pages)
    snapshot = { ..snapshot, saved_at: delta.saved_at, }
    sequence = seq
  }
  snapshot = {
    ..snapshot,
    tasks: tasks.values().to_array(),
    pages: pages.values().to_array(),
  }
  validate(snapshot)
  (Some(snapshot), sequence, index.job_id)
}
