///|
test "agent groups longest rule allow ties wildcards and anchors" {
  assert_true(
    @robots.parse("User-agent: *\nDisallow: /a****\nAllow: /ab").allows(
      "bot", "/ab",
    ),
  )
  let rules = @robots.parse(
    "User-agent: *\nDisallow: /\nUser-agent: MoonCrawler\nDisallow: /private*\nAllow: /private/public\nDisallow: /*.pdf$\nUser-agent: MoonCrawler\nAllow: /private/public\nSitemap: https://example.com/map.xml",
  )
  assert_true(rules.allows("MoonCrawler/0.1", "/index"))
  assert_false(rules.allows("MoonCrawler/0.1", "/private/x"))
  assert_true(rules.allows("MoonCrawler/0.1", "/private/public"))
  assert_false(rules.allows("MoonCrawler/0.1", "/file.pdf"))
  assert_true(rules.allows("MoonCrawler/0.1", "/file.pdf?x=1"))
  assert_false(rules.allows("other", "/index"))
  assert_eq(rules.sitemaps().length(), 1)
}

///|
test "robots failure policy and expiry" {
  let c = @robots.Cache::new()
  assert_false(c.update("https://a", 503, "", 0L).allows("bot", "/"))
  assert_true(c.get("https://a", 299999L) is Some(_))
  assert_true(c.get("https://a", 300000L) is None)
  assert_true(c.update("https://a", 404, "", 0L).allows("bot", "/"))
}

///|
test "robots matches UTF8 and unreserved escapes but preserves escaped slashes" {
  let rules = @robots.parse(
    "User-agent: *\nDisallow: /中文\nDisallow: /%7eprivate\nDisallow: /escaped%2Fpath",
  )
  assert_false(rules.allows("bot", "/%E4%B8%AD%E6%96%87"))
  assert_false(rules.allows("bot", "/~private"))
  assert_false(rules.allows("bot", "/escaped%2fpath"))
  assert_true(rules.allows("bot", "/escaped/path"))
}
