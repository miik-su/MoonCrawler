///|
struct StaticSite {}

///|
impl @fetcher.UnsafeFetcher for StaticSite with fn fetch(_self, url, _config) {
  let body = if url.path == "/robots.txt" {
    "User-agent: *\nDisallow: /private"
  } else if url.path == "/" {
    "<title>MoonCrawler</title><p>MoonBit crawler demo</p><a href='/article'>Article</a><a href='/private'>Private</a>"
  } else {
    "<title>Article</title><p>可恢复的 MoonBit 爬虫</p>"
  }
  {
    url,
    status: 200,
    headers: { "content-type": "text/html; charset=utf-8" },
    body,
  }
}

///|
async fn main {
  let config = {
    ..@core.Config::default(),
    allowed_hosts: ["example.com"],
    delay_ms: 0,
  }
  let memory = @storage.MemoryStore::new()
  let crawler = @engine.Engine::new(config, StaticSite::{ }, memory)
  ignore(crawler.seed("https://example.com"))
  crawler.run()
  println(@storage.jsonl(crawler.pages()))
}
