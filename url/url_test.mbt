///|
test "normalization preserves queries and escaped separators" {
  let a = @url.parse("HTTPS://Example.COM:443/a/../b#x")
  assert_eq(a.key(), "https://example.com/b")
  assert_eq(
    @url.parse("https://example.com/%7e/%2f").key(),
    "https://example.com/~/%2F",
  )
  assert_eq(@url.resolve(a, "../c?x=1").key(), "https://example.com/c?x=1")
  assert_eq(@url.resolve(a, "?x=2").key(), "https://example.com/b?x=2")
  assert_eq(@url.parse("https://example.com/a//b").path, "/a//b")
  assert_eq(
    @url.resolve(a, "article?next=https://other.com").key(),
    "https://example.com/article?next=https://other.com",
  )
  assert_true(
    @url.parse("https://example.com/a?x=1").key() !=
    @url.parse("https://example.com/a?x=2").key(),
  )
}

///|
test "URL rejects credentials ambiguous hosts controls and bad escapes" {
  for
    s in [
      "file:///etc/passwd", "http://u:p@example.com", "http://[::1]/", "https://例子.com",
      "https://a/%xx", "https://a/\r\n", "http://a:0/",
    ] {
    assert_true(
      try @url.parse(s) catch {
        _ => true
      } noraise {
        _ => false
      },
    )
  }
}
