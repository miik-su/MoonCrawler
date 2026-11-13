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
  let encoded = @utf8.encode(text)
  if encoded.length() > 16777216 {
    raise @core.Capacity("job record exceeds write limit")
  }
  let temp = directory + "/staging-" + nonce() + ".tmp"
  let stage = if name == "index.json" {
    "checkpoint"
  } else if name.has_prefix("event-") {
    "event"
  } else {
    "shard"
  }
  {
    let file = @fs.open(
      temp,
      mode=WriteOnly,
      create_mode=CreateNew,
      permission=0o600,
    )
    defer file.close()
    let half = encoded.length() / 2
    file.write(encoded[:half].to_owned())
    probe(stage + "_partial")
    file.write(encoded[half:].to_owned())
    file.sync()
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
      probe=self.probe,
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
      let removed = try @fs.remove(self.directory + "/" + name) catch {
        _ => false
      } noraise {
        _ => true
      }
      if removed {
        (self.probe)("cleanup_removed")
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
  let pages : Map[String, @core.Page] = Map([])
  let catalog = scan_catalog(directory, retain=batch => {
    for page in batch {
      pages[page.url] = page
    }
  })
  let snapshot = Snapshot::{
    version: 1,
    config: catalog.config,
    tasks: catalog.tasks,
    pages: pages.values().to_array(),
    saved_at: catalog.saved_at,
  }
  (Some(snapshot), catalog.sequence, catalog.job_id)
}
