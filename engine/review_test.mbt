///|
struct RecoveringRobots {
  mut calls : Int32
  status : Int32
}

///|
impl @fetcher.UnsafeFetcher for RecoveringRobots with fn fetch(
  self,
  url,
  _config,
) {
  if url.path == "/robots.txt" {
    self.calls += 1
    if self.calls == 1 {
      if self.status == 0 {
        raise @core.Network("simulated temporary outage")
      }
      return {
        url,
        status: self.status,
        headers: { "retry-after": "600" },
        body: "",
      }
    }
    return { url, status: 200, headers: {}, body: "User-agent: *\nAllow: /", }
  }
  { url, status: 200, headers: { "content-type": "text/html" }, body: "ok", }
}

///|
async test "temporary robots failure persists a bounded retry and recovers after cooldown" {
  for status in [0, 429, 503] {
    let config = {
      ..@core.Config::default(),
      allowed_hosts: ["example.com"],
      delay_ms: 0,
      concurrency: 1,
    }
    let site = RecoveringRobots::{ calls: 0, status, }
    let store = @storage.MemoryStore::new()
    let engine = @engine.Engine::new(config, site, store)
    engine.seed("https://example.com/") |> ignore
    // Pause immediately after recording the retry; do not wait ten minutes in a test.
    engine.run(should_stop=() => engine.frontier.count(RetryPending) == 1)
    assert_eq(engine.frontier.count(BlockedByRobots), 0)
    assert_eq(engine.frontier.count(RetryPending), 1)
    let saved = store.load().unwrap()
    assert_true(
      saved.tasks[0].ready_at >=
      saved.saved_at + (if status == 0 { 290000L } else { 590000L }),
    )
    assert_eq(saved.tasks[0].attempts, 1)
    // Model elapsed wall time across restart without modifying the live cache clock.
    let due = { ..saved, tasks: saved.tasks.map(t => { ..t, ready_at: 0L, }), }
    let restored = @engine.Engine::new(config, site, store, snapshot=due)
    restored.run()
    assert_eq(restored.frontier.count(Succeeded), 1)
    assert_eq(site.calls, 2)
  }
}

///|
async test "exhausted robots failures are technical failures rather than permanent rule denies" {
  let config = {
    ..@core.Config::default(),
    allowed_hosts: ["example.com"],
    max_attempts: 1,
    delay_ms: 0,
  }
  let engine = @engine.Engine::new(
    config,
    RecoveringRobots::{ calls: 0, status: 503, },
    @storage.MemoryStore::new(),
  )
  engine.seed("https://example.com/") |> ignore
  engine.run()
  assert_eq(engine.frontier.count(PermanentlyFailed), 1)
  assert_eq(engine.frontier.count(BlockedByRobots), 0)
}

///|
struct Unsolicited304 {}

///|
impl @fetcher.UnsafeFetcher for Unsolicited304 with fn fetch(
  _self,
  url,
  _config,
) {
  { url, status: 304, headers: {}, body: "", }
}

///|
async test "304 fails without conditional request even when a saved representation exists" {
  let config = {
    ..@core.Config::default(),
    allowed_hosts: ["example.com"],
    robots: false,
    delay_ms: 0,
  }
  let page : @core.Page = {
    url: "https://example.com/",
    title: "old",
    description: "",
    text: "old",
    links: [],
    images: [],
    canonical: "",
    metadata: {},
  }
  let snapshot : @storage.Snapshot = {
    version: 1,
    config,
    tasks: [],
    pages: [page],
    saved_at: 0L,
  }
  let engine = @engine.Engine::new(
    config,
    Unsolicited304::{ },
    @storage.MemoryStore::new(),
    snapshot~,
  )
  engine.seed(page.url) |> ignore
  engine.run()
  assert_eq(engine.frontier.count(Succeeded), 0)
  assert_eq(engine.frontier.count(PermanentlyFailed), 1)
  assert_eq(engine.pages()[0].text, "old")
}
