///|
async fn main {
  let args = @env.args()
  guard args.length() == 2 else { abort("expected one corpus JSON path") }
  guard @json.parse(@fs.read_file(args[1]).text()) is Object(fields) &&
    fields.get("mode") is Some(String(mode)) &&
    fields.get("input") is Some(String(input)) &&
    input.length() <= 16384 else {
    abort("invalid corpus record")
  }
  let target = @url.parse("https://example.com/")
  let outcome = match mode {
    "url" => {
      let parsed = Some(@url.parse(input)) catch { _ => None }
      if parsed is Some(url) {
        assert_eq(@url.parse(url.key()).key(), url.key())
      }
      parsed is Some(_)
    }
    "robots" => {
      let rules = @robots.parse(input)
      let again = @robots.parse(input)
      for path in ["/", "/private", "/private/child?x=1"] {
        assert_eq(
          rules.allows("MoonCrawler", path),
          again.allows("MoonCrawler", path),
        )
      }
      true
    }
    "fetcher" => {
      let response = Some(
        @fetcher.decode(target, @utf8.encode(input), {
          ..@core.Config::default(),
          max_body_bytes: 4096,
          max_header_bytes: 4096,
        }),
      ) catch {
        _ => None
      }
      if response is Some(value) {
        assert_eq(value.url.key(), target.key())
        assert_true(@utf8.encode(value.body).length() <= 4096)
      }
      response is Some(_)
    }
    "parser" => {
      let page = Some(
        @parser.extract({
          url: target,
          status: 200,
          headers: { "content-type": "text/html" },
          body: input,
        }),
      ) catch {
        _ => None
      }
      if page is Some(value) {
        assert_eq(value.url, target.key())
        assert_true(value.links.length() <= 10000)
      }
      page is Some(_)
    }
    "sitemap" => {
      let doc = Some(@sitemap.parse(input)) catch { _ => None }
      if doc is Some(value) {
        assert_true(value.locations.length() <= 10000)
        assert_true(
          value.locations.iter().all(s => !s.is_empty() && s.length() <= 2048),
        )
      }
      doc is Some(_)
    }
    _ => abort("unknown fuzz target")
  }
  let result : Json = { "accepted": @json.to_json(outcome) }
  println(result.stringify())
}
