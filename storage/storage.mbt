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
}

///|
pub async fn FileStore::open(directory : String) -> FileStore {
  @fs.mkdir(directory, recursive=true, allow_exist=true)
  let lock_file = @fs.open(
    directory + "/job.lock",
    mode=ReadWrite,
    create_mode=OpenOrCreate,
  )
  errdefer lock_file.close()
  if !lock_file.try_lock(Exclusive) {
    raise @core.Storage("job directory already locked")
  }
  { directory, lock_file, }
}

///|
pub fn FileStore::close(self : FileStore) -> Unit {
  self.lock_file.unlock()
  self.lock_file.close()
}

///|
pub impl Storage for FileStore with fn save(self, snapshot) {
  validate(snapshot)
  let bytes = @utf8.encode(@json.to_json(snapshot).stringify())
  if bytes.length() > 67108864 {
    raise @core.Capacity("checkpoint exceeds 64 MiB; use a custom store")
  }
  let temp = self.directory + "/checkpoint.tmp"
  @fs.write_file(temp, bytes, sync=Full)
  @fs.rename(temp, self.directory + "/checkpoint.json", replace=true)
}

///|
pub impl Storage for FileStore with fn load(self) {
  read_snapshot(self.directory)
}

///|
/// Atomic snapshot reads can be used by status while the writer owns the job lock.
pub async fn read_snapshot(directory : String) -> Snapshot? {
  let path = directory + "/checkpoint.json"
  if !@fs.exists(path) {
    return None
  }
  if @fs.file_size(path) > 67108864L {
    raise @core.Capacity("checkpoint exceeds read limit")
  }
  let data = @fs.read_file(path)
  let snapshot : Snapshot = @json.from_json(
    @json.parse(data.text(), max_nesting_depth=64, reject_duplicate_keys=true),
  )
  validate(snapshot)
  Some(snapshot)
}

///|
pub fn validate(snapshot : Snapshot) -> Unit raise @core.CrawlError {
  if snapshot.version != 1 {
    raise @core.Storage("unsupported checkpoint version")
  }
  ignore(@frontier.restore(snapshot.config, snapshot.tasks, snapshot.saved_at))
  if snapshot.pages.length() > snapshot.config.max_pages {
    raise @core.Storage("too many checkpoint pages")
  }
  let seen : Map[String, Bool] = Map([])
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
