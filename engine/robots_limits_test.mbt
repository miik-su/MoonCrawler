///|
struct RobotsChain {
  paths : Array[String]
}

///|
impl @fetcher.UnsafeFetcher for RobotsChain with fn fetch(self, url, config) {
  self.paths.push(url.path)
  if url.path == "/robots.txt" || url.path.has_prefix("/r") {
    assert_true(config.max_body_bytes >= 512000)
    let next = match url.path {
      "/robots.txt" => "/r1"
      "/r1" => "/r2"
      "/r2" => "/r3"
      "/r3" => "/r4"
      "/r4" => "/r5"
      _ => ""
    }
    if next.is_empty() {
      { url, status: 200, headers: {}, body: "User-agent: *\nAllow: /", }
    } else {
      { url, status: 302, headers: { "location": next }, body: "", }
    }
  } else {
    { url, status: 200, headers: { "content-type": "text/html" }, body: "ok", }
  }
}

///|
async test "robots budget is independent and follows five hops with page redirects disabled" {
  let config = {
    ..@core.Config::default(),
    allowed_hosts: ["example.com"],
    max_redirects: 0,
    max_body_bytes: 128,
    delay_ms: 0,
  }
  let site = RobotsChain::{ paths: [], }
  let e = @engine.Engine::new(config, site, @storage.MemoryStore::new())
  assert_true(e.seed("https://example.com/"))
  e.run()
  assert_true(site.paths.contains("/r5"))
  assert_eq(e.frontier.count(Succeeded), 1)
}
