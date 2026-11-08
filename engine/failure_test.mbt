///|
struct FailingStore {
  memory : @storage.MemoryStore
  mut writes : Int32
  mut fail_at : Int32
}

///|
impl @storage.Storage for FailingStore with fn save(self, value) {
  self.writes += 1
  if self.writes == self.fail_at {
    raise @core.Storage("injected disk write failure")
  }
  (self.memory as &@storage.Storage).save(value)
}

///|
impl @storage.Storage for FailingStore with fn load(self) {
  (self.memory as &@storage.Storage).load()
}

///|
struct OnePage {}

///|
impl @fetcher.Fetcher for OnePage with fn fetch(_self, url, _config) {
  {
    url,
    status: 200,
    headers: { "content-type": "text/html" },
    body: "<title>one</title><p>stable",
  }
}

///|
async test "checkpoint write failure propagates and previous lease safely replays" {
  let config = {
    ..@core.Config::default(),
    concurrency: 1,
    per_host: 1,
    max_pages: 1,
    robots: false,
    delay_ms: 0,
  }
  let store = FailingStore::{
    memory: @storage.MemoryStore::new(),
    writes: 0,
    fail_at: 3,
  }
  let e = @engine.Engine::new(config, OnePage::{ }, store)
  assert_true(e.seed("https://example.com"))
  assert_true(
    try e.run() catch {
      _ => true
    } noraise {
      _ => false
    },
  )
  let saved = (store as &@storage.Storage).load().unwrap()
  assert_eq(saved.tasks[0].state, Running)
  store.fail_at = -1
  let restored = @engine.Engine::new(
    config,
    OnePage::{ },
    store,
    snapshot=saved,
  )
  restored.run()
  assert_eq(restored.frontier.count(Succeeded), 1)
  assert_eq(restored.pages().length(), 1)
}
