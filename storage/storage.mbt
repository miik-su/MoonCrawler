///|
pub(all) struct Snapshot {
  version : Int32
  config : @core.Config
  tasks : Array[@core.Task]
  pages : Array[@core.Page]
  saved_at : Int64
} derive(ToJson, FromJson, Debug)

///|
pub(open) trait Storage {
  async fn save(Self, Snapshot) -> Unit
  async fn load(Self) -> Snapshot?
  async fn commit_batch(
    Self,
    @core.Config,
    Array[@core.Task],
    Array[@core.Page],
    Int64,
  ) -> Unit = _
}

///|
impl Storage with fn commit_batch(self, config, tasks, pages, now) {
  let previous = self
    .load()
    .unwrap_or({ version: 1, config, tasks: [], pages: [], saved_at: now, })
  self.save(apply_batch(previous, tasks, pages, now))
}

///|
pub struct MemoryStore {
  priv mut value : String?
}

///|
pub fn MemoryStore::new() -> MemoryStore {
  { value: None, }
}

///|
pub impl Storage for MemoryStore with fn save(self, snapshot) {
  validate(snapshot)
  self.value = Some(@json.to_json(snapshot).stringify())
}

///|
pub impl Storage for MemoryStore with fn load(self) {
  self.value.map(s => @json.from_json(@json.parse(s)))
}

///|
/// A locked single-process job directory. Keep this object alive until the crawl ends.
pub struct FileStore {
  directory : String
  priv lock_file : @fs.File
  priv mut sequence : Int32
  priv mut job_id : String
  priv mut job_config : @core.Config?
  priv mut ledger : @core.PageLedger
  priv probe : async (String) -> Unit
}

///|
/// The optional diagnostic probe runs at publication boundaries. It must not mutate
/// the store or directory. A probe error after publication has an ambiguous commit outcome.
pub async fn FileStore::open(
  directory : String,
  probe~ : async (String) -> Unit = _ => (),
) -> FileStore {
  @fs.mkdir(directory, recursive=true, allow_exist=true, permission=0o700)
  if @fs.kind(directory, follow_symlink=false) != Directory {
    raise @core.Storage("job directory must not be a symlink")
  }
  if @fs.exists(directory + "/job.lock") &&
    @fs.kind(directory + "/job.lock", follow_symlink=false) != Regular {
    raise @core.Storage("job lock must be a regular file")
  }
  let lock_file = @fs.open(
    directory + "/job.lock",
    mode=ReadWrite,
    create_mode=OpenOrCreate,
    permission=0o600,
  )
  errdefer lock_file.close()
  if !lock_file.try_lock(Exclusive) {
    raise @core.Storage("job directory already locked")
  }
  {
    directory,
    lock_file,
    sequence: 0,
    job_id: "",
    job_config: None,
    ledger: @core.PageLedger::new(),
    probe,
  }
}

///|
pub fn FileStore::close(self : FileStore) -> Unit {
  self.lock_file.unlock()
  self.lock_file.close()
}

///|
pub impl Storage for FileStore with fn save(self, snapshot) {
  self.write_checkpoint(snapshot)
}

///|
pub impl Storage for FileStore with fn load(self) {
  let (snapshot, sequence, job_id) = recover(self.directory)
  self.sequence = sequence
  self.job_id = if job_id.is_empty() { nonce() } else { job_id }
  self.job_config = snapshot.map(s => s.config)
  self.ledger = @core.PageLedger::new()
  if snapshot is Some(s) {
    self.ledger.commit(s.config, s.pages)
  }
  if snapshot is Some(saved) && !@fs.exists(self.directory + "/index.json") {
    self.write_checkpoint(saved)
  }
  snapshot
}

///|
/// Atomic snapshot reads can be used by status while the writer owns the job lock.
pub async fn read_snapshot(directory : String) -> Snapshot? {
  recover(directory).0 catch {
    _ => recover(directory).0
  }
}

///|
pub fn validate(snapshot : Snapshot) -> Unit raise @core.CrawlError {
  if snapshot.saved_at < 0L {
    raise @core.Storage("negative checkpoint time")
  }
  if snapshot.version != 1 {
    raise @core.Storage("unsupported checkpoint version")
  }
  snapshot.config.validate()
  let keys : Map[String, Bool] = Map([])
  for task in snapshot.tasks {
    @core.validate_task(snapshot.config, task)
    let key = task.request.url.key(include_query=snapshot.config.include_query)
    if keys.contains(key) || keys.length() >= snapshot.config.max_pages {
      raise @core.Storage("duplicate or oversized tasks")
    }
    keys[key] = true
  }
  if snapshot.pages.length() > snapshot.config.max_pages {
    raise @core.Storage("too many checkpoint pages")
  }
  let seen : Map[String, Bool] = Map([])
  let ledger = @core.PageLedger::new()
  ledger.commit(snapshot.config, snapshot.pages)
  for page in snapshot.pages {
    let url = @url.parse(page.url) catch {
      _ => raise @core.Storage("invalid page URL")
    }
    if url.key() != page.url || seen.contains(page.url) {
      raise @core.Storage("noncanonical or duplicate page")
    }
    seen[page.url] = true
  }
}

///|
pub fn jsonl(pages : Array[@core.Page]) -> String {
  let out = StringBuilder()
  for page in pages {
    out.write_string(@json.to_json(page).stringify())
    out.write_string("\n")
  }
  out.to_string()
}
