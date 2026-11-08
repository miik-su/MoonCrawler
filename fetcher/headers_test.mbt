///|
test "response parser rejects folded controls duplicates ambiguous framing and upgrades" {
  let config = @core.Config::default()
  let url = @url.parse("https://example.com/")
  for
    response in [
      "HTTP/1.1 101 Switch\r\n\r\n", "HTTP/1.1 +20 OK\r\n\r\n", "HTTP/1.1 200 OK\r\nBad Name: x\r\n\r\n",
      "HTTP/1.1 200 OK\r\n folded: x\r\n\r\n", "HTTP/1.1 302 Found\r\nLocation: /a\r\nLocation: /b\r\n\r\n",
      "HTTP/1.1 200 OK\r\nContent-Length: 1\r\nTransfer-Encoding: chunked\r\n\r\nx",
    ] {
    assert_true(
      try @fetcher.decode(url, @utf8.encode(response), config) catch {
        _ => true
      } noraise {
        _ => false
      },
    )
  }
}
