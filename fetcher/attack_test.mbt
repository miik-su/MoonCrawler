///|
async test "decompressed output bound stops a highly compressible response" {
  @async.with_timeout(10000, () => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    defer server.close()
    @async.with_task_group(group => {
      group.spawn_bg(() => {
        let (conn, _) = server.accept()
        defer conn.close()
        ignore(conn.read_request())
        conn.skip_request_body()
        try {
          conn.send_response(200, "OK", extra_headers={
            "Content-Type": "text/html",
            "Content-Encoding": "gzip",
          })
          let encoder = @gzip.Encoder(conn)
          encoder.write(String::make(131072, 'x'))
          encoder.end()
          conn.end_response()
        } catch {
          _ => ()
        }
      })
      let config = {
        ..@core.Config::default(),
        allowed_hosts: ["127.0.0.1"],
        allow_loopback: true,
        max_body_bytes: 1024,
      }
      let fetcher : @fetcher.CurlFetcher = { program: "curl", }
      assert_true(
        try
          fetcher.request(
            @url.parse("http://127.0.0.1:\{server.addr.port()}/"),
            config,
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

///|
#cfg(not(platform="windows"))
async test "curl refuses an untrusted TLS certificate" {
  let fixture = @fs.tmpdir(prefix="mooncrawler-tls-")
  defer @fs.rmdir(fixture, recursive=true)
  let generated = @shell.Cmd("openssl", [
    "req",
    "-x509",
    "-newkey",
    "rsa:2048",
    "-nodes",
    "-keyout",
    fixture + "/key.pem",
    "-out",
    fixture + "/cert.pem",
    "-days",
    "1",
    "-subj",
    "/CN=localhost",
  ]).output(timeout_ms=10000)
  generated.check()
  @async.with_timeout(10000, () => {
    // Reserve a test port, then use the external TLS endpoint rather than an
    // upstream API annotated "internal testing only". Readiness retries below
    // tolerate process startup; a failed TCP connect never counts as TLS refusal.
    let reservation = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    let port = reservation.addr.port()
    reservation.close()
    @async.with_task_group(group => {
      let serving = group.spawn(
        () => {
          @shell.Cmd("openssl", [
            "s_server",
            "-accept",
            "127.0.0.1:\{port}",
            "-cert",
            fixture + "/cert.pem",
            "-key",
            fixture + "/key.pem",
            "-www",
            "-naccept",
            "1",
            "-quiet",
          ]).output(timeout_ms=8000)
        },
        no_wait=true,
      )
      defer serving.cancel()
      let config = {
        ..@core.Config::default(),
        allowed_hosts: ["localhost"],
        allow_loopback: true,
      }
      let fetcher : @fetcher.CurlFetcher = { program: "curl", }
      let mut rejected_certificate = false
      for _ in 0..<40 {
        let result = try {
          fetcher.request(@url.parse("https://localhost:\{port}/"), config)
          |> ignore
          0
        } catch {
          @core.Network(_) => 1
          @core.Protocol(message) =>
            if message == "curl transport exit 60" {
              2
            } else {
              0
            }
          _ => 0
        }
        if result == 1 {
          @async.sleep(50)
          continue
        }
        rejected_certificate = result == 2
        break
      }
      assert_true(rejected_certificate)
    })
  })
}

///|
// The pinned toolchain cannot condition imports by OS. This filesystem import
// is retained for the Unix-only fixture; its type reference is intentional on Windows.
#cfg(platform="windows")
let _unix_fixture_imports : Unit = ignore((_ : @fs.File?) => ())
