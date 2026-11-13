///|
struct ChangingResolver {
  mut calls : Int32
}

///|
impl @security.Resolver for ChangingResolver with fn resolve(self, _host, port) {
  self.calls += 1
  @socket.Addr::parse(
    "\{if self.calls == 1 { "127.0.0.1" } else { "169.254.169.254" }}:\{port}",
  ) catch {
    _ => raise @security.Unknown
  }
}

///|
async test "actual curl pins the checked answer and rejects a changed private answer before connection" {
  @async.with_timeout(10000, () => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    defer server.close()
    let dns = ChangingResolver::{ calls: 0, }
    let url = @url.parse("http://localhost:\{server.addr.port()}/")
    let config = {
      ..@core.Config::default(),
      allowed_hosts: ["localhost"],
      allow_loopback: true,
    }
    let fetcher : @fetcher.CurlFetcher = { program: "curl", }
    @async.with_task_group(group => {
      group.spawn_bg(() => {
        let (conn, _) = server.accept()
        defer conn.close()
        let request = conn.read_request()
        assert_true(
          request.headers.get("Host").unwrap().has_prefix("localhost:"),
        )
        conn.skip_request_body()
        conn.send_response(200, "OK", extra_headers={
          "Content-Type": "text/html",
        })
        conn.write("pinned")
        conn.end_response()
      })
      assert_eq(fetcher.request(url, config, resolver=dns).body, "pinned")
      assert_eq(dns.calls, 1)
      assert_true(
        try fetcher.request(url, config, resolver=dns) catch {
          @core.Security(_) => true
          _ => false
        } noraise {
          _ => false
        },
      )
      assert_eq(dns.calls, 2)
    })
  })
}
