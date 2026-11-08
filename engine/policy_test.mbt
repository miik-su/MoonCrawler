///|
struct PolicyFixture {
  requested : Array[String]
}

///|
impl @fetcher.UnsafeFetcher for PolicyFixture with fn fetch(self, url, _config) {
  self.requested.push(url.path)
  match url.path {
    "/redirect" =>
      {
        url,
        status: 302,
        headers: { "location": "/private/file.pdf" },
        body: "",
      }
    "/not-modified" => { url, status: 304, headers: {}, body: "", }
    _ =>
      {
        url,
        status: 200,
        headers: { "content-type": "text/html" },
        body: "<p>unexpected",
      }
  }
}

///|
async test "redirect filters reject before target request and uncached 304 fails" {
  let config = {
    ..@core.Config::default(),
    allowed_hosts: ["example.com"],
    denied_paths: ["/private"],
    robots: false,
    delay_ms: 0,
  }
  let fixture = PolicyFixture::{ requested: [], }
  let e = @engine.Engine::new(config, fixture, @storage.MemoryStore::new())
  assert_true(e.seed("https://example.com/redirect"))
  assert_true(e.seed("https://example.com/not-modified"))
  e.run()
  assert_false(fixture.requested.contains("/private/file.pdf"))
  assert_eq(e.frontier.count(SkippedByPolicy), 1)
  assert_eq(e.frontier.count(PermanentlyFailed), 1)
}
