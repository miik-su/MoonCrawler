///|
/// An exclusive, stable job reader. Retains task metadata and page locations only.
/// Close it before resuming the writer. One record (at most 16 MiB encoded) is decoded
/// at a time; decoding buffers/runtime are additional memory, not a hard RSS bound.
pub struct PageReader {
  priv store : FileStore
  priv catalog : Catalog
  priv mut closed : Bool
}

///|
/// Legacy checkpoints migrate once using the existing <=64 MiB compatibility path.
pub async fn PageReader::open(directory : String) -> PageReader {
  let store = FileStore::open(directory)
  errdefer store.close()
  if !@fs.exists(directory + "/index.json") {
    if store.load() is None {
      raise @core.Storage("no checkpoint found in job directory")
    }
  }
  { store, catalog: scan_catalog(directory), closed: false, }
}

///|
pub fn PageReader::close(self : PageReader) -> Unit {
  if !self.closed {
    self.closed = true
    self.store.close()
  }
}

///|
pub fn PageReader::page_count(self : PageReader) -> Int32 {
  self.catalog.pages.length()
}

///|
/// Diagnostic batch count, not a heap/byte measurement.
pub fn PageReader::max_batch_pages(self : PageReader) -> Int32 {
  self.catalog.max_batch_pages
}

///|
pub async fn PageReader::read_page(
  self : PageReader,
  canonical_url : String,
) -> @core.Page? {
  if self.closed {
    raise @core.Storage("page reader is closed")
  }
  guard self.catalog.pages.get(canonical_url) is Some((record, i)) else {
    return None
  }
  let delta = self.catalog.read_record(self.store.directory, record)
  guard delta.pages.get(i) is Some(page) && page.url == canonical_url else {
    raise @core.Storage("page location changed")
  }
  Some(page)
}

///|
/// Stable latest-version iteration; caller must not retain all pages for streaming memory use.
pub async fn PageReader::visit_pages(
  self : PageReader,
  visit : async (@core.Page) -> Unit,
) -> Unit {
  if self.closed {
    raise @core.Storage("page reader is closed")
  }
  self.catalog.visit(self.store.directory, visit)
}

///|
/// Refuses overwrite and synchronizes output. Failed writes may leave partial JSONL.
pub async fn PageReader::export_jsonl(
  self : PageReader,
  path : String,
) -> Int32 {
  if self.closed {
    raise @core.Storage("page reader is closed")
  }
  check_export_path(path)
  let file = @fs.open(
    path,
    mode=WriteOnly,
    create_mode=CreateNew,
    permission=0o600,
  )
  defer file.close()
  let mut count = 0
  self.visit_pages(page => {
    file.write(@json.to_json(page).stringify() + "\n")
    count += 1
  })
  file.sync()
  count
}
