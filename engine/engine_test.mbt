///|
struct Fixture {
  requests : Array[String]
  counts : Map[String, Int]
}

///|
impl @fetcher.Fetcher for Fixture with fn fetch(self, url, _config) {
  self.requests.push(url.key())
  let count = self.counts.get(url.path).unwrap_or(0) + 1
  self.counts[url.path] = count
  let (status, headers, body) : (Int, Map[String, String], String) = match url.path {
    "/robots.txt" => (200, {"content-type": "text/plain"}, "User-agent: *\nDisallow: /private")
    "/" => (200, {"content-type": "text/html"}, "<title>Home</title><a href='/next'>next</a><a href='/private'>private</a><a href='/retry'>retry</a><a href='/redirect'>redirect</a><a href='/escape'>escape</a><a href='/'>loop</a>")
    "/retry" => if count == 1 { (503, {"retry-after": "0"}, "") } else { (200, {"content-type": "text/html"}, "<p>recovered") }
    "/redirect" => (302, {"location": "/next"}, "")
    "/escape" => (302, {"location": "http://127.0.0.1/secret"}, "")
    _ => (200, {"content-type": "text/html"}, "<title>Next</title><a href='/'>home</a>")
  }
  {url, status, headers, body}
}

///|
async test "crawl integration discovers deduplicates retries enforces robots and safe redirects then resumes" {
  let config = { ..@core.Config::default(), delay_ms: 0, allowed_hosts: ["example.com"], max_pages: 20 }
  let fixture = Fixture::{ requests: [], counts: {} }
  let store = @storage.MemoryStore::new()
  let e = @engine.Engine::new(config, fixture, store)
  assert_true(e.seed("https://example.com/"))
  e.run()
  assert_eq(e.frontier.count(Succeeded), 4)
  assert_eq(e.frontier.count(PermanentlyFailed), 2)
  assert_false(fixture.requests.contains("https://example.com/private"))
  assert_false(fixture.requests.contains("http://127.0.0.1/secret"))
  assert_eq(fixture.counts["/retry"], 2)
  assert_eq(fixture.counts["/robots.txt"], 1)
  assert_eq(e.pages().length(), 3)
  let saved = (store as &@storage.Storage).load().unwrap()
  let restored = @engine.Engine::new(config, fixture, store, snapshot=saved)
  let before = fixture.requests.length()
  restored.run()
  assert_eq(fixture.requests.length(), before)
}

///|
async test "cooperative pause leaves pending work and a durable resume point" {
  let config = @core.Config::default()
  let fixture = Fixture::{ requests: [], counts: {} }
  let store = @storage.MemoryStore::new()
  let e = @engine.Engine::new(config, fixture, store)
  assert_true(e.seed("https://example.com"))
  e.run(should_stop=() => true)
  assert_eq(e.frontier.count(Pending), 1)
  assert_eq(fixture.requests.length(), 0)
  assert_eq((store as &@storage.Storage).load().unwrap().tasks.length(), 1)
}
