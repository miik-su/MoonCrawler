///|
/// Use a locked FileStore without retaining committed page bodies. Obtain
/// state with store.load_metadata() and pass it when resuming an existing job.
pub fn Engine::new_streaming(
  config : @core.Config,
  fetcher : &@fetcher.UnsafeFetcher,
  store : @storage.FileStore,
  state? : (@storage.Snapshot, @core.PageLedger),
) -> Engine raise @core.CrawlError {
  let engine = Engine::new(
    config,
    fetcher,
    store,
    snapshot?=state.map(s => s.0),
  )
  let ledger = state.map(s => s.1.copy()).unwrap_or(@core.PageLedger::new())
  { ..engine, streaming: Some(store), ledger, }
}

///|
pub fn Engine::page_count(self : Engine) -> Int32 {
  self.ledger.count()
}

///|
/// Visit pages after run returns. Streaming engines read from their locked job.
pub async fn Engine::visit_pages(
  self : Engine,
  visit : async (@core.Page) -> Unit,
) -> Unit {
  match self.streaming {
    Some(store) => store.visit_pages(visit)
    None =>
      for page in self.pages.values() {
        visit(page)
      }
  }
}
