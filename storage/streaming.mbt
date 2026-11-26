///|
fn Catalog::metadata(self : Catalog) -> Snapshot {
  {
    version: 1,
    config: self.config,
    tasks: self.tasks,
    pages: [],
    saved_at: self.saved_at,
  }
}

///|
/// The returned Snapshot carries task/config metadata only. A legacy monolithic
/// checkpoint is migrated through the existing bounded compatibility path.
pub async fn FileStore::load_metadata(
  self : FileStore,
) -> (Snapshot, @core.PageLedger)? {
  if !@fs.exists(self.directory + "/index.json") {
    if self.load() is None {
      return None
    }
  }
  let catalog = scan_catalog(self.directory)
  self.sequence = catalog.sequence
  self.job_id = catalog.job_id
  self.job_config = Some(catalog.config)
  self.ledger = catalog.ledger
  Some((catalog.metadata(), catalog.ledger.copy()))
}

///|
/// Read the locked job's latest pages in record order. Consume pages promptly.
pub async fn FileStore::visit_pages(
  self : FileStore,
  visit : async (@core.Page) -> Unit,
) -> Unit {
  if @fs.exists(self.directory + "/index.json") {
    scan_catalog(self.directory).visit(self.directory, visit)
  }
}

///|
/// Publish a replacement index after all new shards are synchronized, retaining
/// only one decoded source record plus a bounded destination shard batch.
pub async fn FileStore::compact(self : FileStore) -> Unit {
  let catalog = scan_catalog(self.directory)
  if catalog.job_id != self.job_id || catalog.sequence != self.sequence {
    raise @core.Storage("compaction job identity changed")
  }
  self.write_checkpoint_data(catalog.config, catalog.tasks, catalog.saved_at, visit => {
    catalog.visit(self.directory, visit)
  })
  self.ledger = catalog.ledger
}

///|
/// Status read can overlap an atomic writer. Missing or replaced records retry once.
pub async fn read_job_metadata(directory : String) -> (Snapshot, Int32)? {
  if !@fs.exists(directory + "/index.json") {
    return read_snapshot(directory).map(s => {
      ({ ..s, pages: [], }, s.pages.length())
    })
  }
  let catalog = scan_catalog(directory) catch { _ => scan_catalog(directory) }
  Some((catalog.metadata(), catalog.ledger.count()))
}
