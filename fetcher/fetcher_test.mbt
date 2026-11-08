///|
test "response status headers interim response and resource limits" {
  let u = @url.parse("https://example.com")
  let c = { ..@core.Config::default(), allow_any_public_host: true, }
  let r = @fetcher.decode(
    u, b"HTTP/1.1 100 Continue\r\n\r\nHTTP/1.1 429 Too Many\r\nRetry-After: 12\r\nContent-Type: text/html; charset=utf-8\r\n\r\nhello",
    c,
  )
  assert_eq(r.status, 429)
  assert_eq(r.headers["retry-after"], "12")
  assert_eq(r.body, "hello")
  let small = { ..c, max_body_bytes: 2, }
  assert_true(
    try @fetcher.decode(u, b"HTTP/1.1 200 OK\r\n\r\nabc", small) catch {
      _ => true
    } noraise {
      _ => false
    },
  )
  assert_true(
    try
      @fetcher.decode(
        u, b"HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=gbk\r\n\r\nx", c,
      )
    catch {
      _ => true
    } noraise {
      _ => false
    },
  )
}
