///|
async test "real transport rejects oversized responses and times out stalled servers" {
  @async.with_timeout(10000, () => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    defer server.close()
    @async.with_task_group(group => {
      group.spawn_bg(() => {
        let (conn, _) = server.accept()
        defer conn.close()
        ignore(conn.read_request())
        conn.skip_request_body()
        conn.send_response(200, "OK", extra_headers={
          "Content-Type": "text/html",
          "Content-Length": "20",
        })
        conn.write("01234567890123456789")
        conn.end_response()
      })
      let c = {
        ..@core.Config::default(),
        allow_loopback: true,
        max_body_bytes: 4,
      }
      let fetcher : @fetcher.CurlFetcher = { program: "curl", }
      assert_true(
        try
          fetcher.request(
            @url.parse("http://127.0.0.1:\{server.addr.port()}/"),
            c,
          )
        catch {
          _ => true
        } noraise {
          _ => false
        },
      )
    })
    @async.with_task_group(group => {
      group.spawn_bg(() => {
        let (conn, _) = server.accept()
        defer conn.close()
        ignore(conn.read_request())
        @async.sleep(150)
      })
      let c = {
        ..@core.Config::default(),
        allow_loopback: true,
        timeout_ms: 40,
      }
      let fetcher : @fetcher.CurlFetcher = { program: "curl", }
      assert_true(
        try
          fetcher.request(
            @url.parse("http://127.0.0.1:\{server.addr.port()}/"),
            c,
          )
        catch {
          _ => true
        } noraise {
          _ => false
        },
      )
    })
  })
}
