///|
test "temporary failures retain cooldown separately from explicit rules" {
  let cache = @robots.Cache::new()
  for status in [429, 503, 500, 302] {
    cache.update("https://example.com", status, "", 100L, retry_after_ms=600000)
    |> ignore
    assert_eq(cache.retry_in("https://example.com", 101L), Some(599999))
    assert_true(cache.get("https://example.com", 600100L) is None)
  }
  cache.update("https://example.com", 200, "User-agent: *\nDisallow: /", 1L)
  |> ignore
  assert_eq(cache.retry_in("https://example.com", 2L), None)
  assert_false(
    cache.get("https://example.com", 2L).unwrap().allows("MoonCrawler", "/"),
  )
  cache.update("https://example.com", 404, "", 3L) |> ignore
  assert_true(
    cache.get("https://example.com", 4L).unwrap().allows("MoonCrawler", "/"),
  )
}
