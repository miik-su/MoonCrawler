///|
async test "real curl transport sends headers and leaves redirects to engine" {
  @async.with_timeout(10000, () => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    defer server.close()
    @async.with_task_group(group => {
      group.spawn_bg(() => {
        let (conn, _) = server.accept()
        defer conn.close()
        let request = conn.read_request()
        assert_eq(request.headers.get("User-Agent"), Some("MoonCrawler/0.1"))
        assert_eq(request.path, "/start?x=1")
        conn.skip_request_body()
        conn.send_response(302, "Found", extra_headers={
          "Location": "/next",
          "Content-Type": "text/html",
        })
        conn.write("<p>redirect")
        conn.end_response()
      })
      let config = {
        ..{ ..@core.Config::default(), allow_any_public_host: true, },
        allow_loopback: true,
      }
      let fetcher : @fetcher.CurlFetcher = { program: "curl", }
      let response = fetcher.request(
        @url.parse("http://127.0.0.1:\{server.addr.port()}/start?x=1"),
        config,
      )
      assert_eq(response.status, 302)
      assert_eq(response.headers["location"], "/next")
      assert_eq(response.body, "<p>redirect")
    })
  })
}
