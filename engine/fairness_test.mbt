///|
struct ParallelSite {
  counts : Map[String, Int32]
  mut robots_active : Int32
  mut robots_peak : Int32
}

///|
impl @fetcher.UnsafeFetcher for ParallelSite with fn fetch(self, url, _config) {
  let key = url.origin() + url.path
  self.counts[key] = self.counts.get(key).unwrap_or(0) + 1
  if url.path == "/robots.txt" {
    self.robots_active += 1
    self.robots_peak = self.robots_peak.max(self.robots_active)
    @async.sleep(30)
    self.robots_active -= 1
    { url, status: 200, headers: {}, body: "User-agent: *\nAllow: /", }
  } else {
    {
      url,
      status: 200,
      headers: { "content-type": "text/html" },
      body: "<p>ok",
    }
  }
}

///|
async test "host admission leaves workers for other origins and robots flights overlap" {
  let site = ParallelSite::{ counts: {}, robots_active: 0, robots_peak: 0, }
  let config = {
    ..@core.Config::default(),
    allowed_hosts: ["a.example", "b.example"],
    delay_ms: 0,
  }
  let e = @engine.Engine::new(config, site, @storage.MemoryStore::new())
  for
    u in [
      "https://a.example/1", "https://a.example/2", "https://a.example/3", "https://b.example/1",
    ] {
    assert_true(e.seed(u))
  }
  e.run()
  assert_eq(site.robots_peak, 2)
  assert_eq(site.counts["https://a.example/robots.txt"], 1)
  assert_eq(e.frontier.count(Succeeded), 4)
}
