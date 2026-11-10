///|
struct ContractSite {
  mismatch : Bool
}

///|
impl @fetcher.UnsafeFetcher for ContractSite with fn fetch(self, url, _config) {
  {
    url: if self.mismatch {
      @url.parse("https://other.com/")
    } else {
      url
    },
    status: 200,
    headers: { "content-type": "text/html" },
    body: "<a href='http://127.0.0.1/'>bad</a><a href='http://192.168.1.1/'>bad</a><a href='/good'>good</a>",
  }
}

///|
struct ChangeIdentity {}

///|
impl @pipeline.Processor for ChangeIdentity with fn process(_self, page) {
  Some({ ..page, url: "invalid", })
}

///|
async test "fetcher and processor cannot change page identity" {
  let config = {
    ..@core.Config::default(),
    allowed_hosts: ["example.com"],
    robots: false,
    delay_ms: 0,
  }
  let a = @engine.Engine::new(
    config,
    ContractSite::{ mismatch: true, },
    @storage.MemoryStore::new(),
  )
  a.seed("https://example.com/") |> ignore
  a.run()
  assert_eq(a.pages().length(), 0)
  let b = @engine.Engine::new(
    config,
    ContractSite::{ mismatch: false, },
    @storage.MemoryStore::new(),
    processors=[ChangeIdentity::{ }],
  )
  b.seed("https://example.com/") |> ignore
  b.run()
  assert_eq(b.pages().length(), 0)
  assert_eq(b.frontier.count(PermanentlyFailed), 1)
}

///|
async test "private links do not consume the public crawl quota" {
  let config = {
    ..@core.Config::default(),
    allow_any_public_host: true,
    max_pages: 2,
    robots: false,
    delay_ms: 0,
  }
  let e = @engine.Engine::new(
    config,
    ContractSite::{ mismatch: false, },
    @storage.MemoryStore::new(),
  )
  e.seed("https://example.com/") |> ignore
  e.run()
  assert_eq(e.frontier.count(Succeeded), 2)
  assert_eq(e.pages().length(), 2)
}
