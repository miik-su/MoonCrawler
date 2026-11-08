///|
test "bounded deterministic URL Robots and HTTP mutation corpus" {
  let alphabet = "abcXYZ0123./:%?#[]\\\r\n\t *$<>@-_=;"
  let mut seed = 42U
  for n in 0..<256 {
    let input = StringBuilder()
    for _ in 0..<(n % 80) {
      seed = seed * 1664525U + 1013904223U
      let i = (seed % alphabet.length().reinterpret_as_uint()).reinterpret_as_int()
      input.write_string(alphabet[i:i + 1].to_owned())
    }
    let text = input.to_string()
    let url = try @url.parse("https://example.com/" + text) catch {
      _ => None
    } noraise {
      u => Some(u)
    }
    if url is Some(u) {
      assert_eq(@url.parse(u.key()).key(), u.key())
    }
    let rules = @robots.parse(
      "User-agent: *\nDisallow: /blocked/" + text + "\nAllow: /safe",
    )
    assert_true(rules.allows("MoonCrawler", "/safe"))
    try
      @fetcher.decode(
        @url.parse("https://example.com"),
        @utf8.encode("HTTP/1.1 200 OK\r\n" + text + "\r\n\r\nx"),
        @core.Config::default(),
      )
    catch {
      _ => ()
    } noraise {
      _ => ()
    }
  }
}
