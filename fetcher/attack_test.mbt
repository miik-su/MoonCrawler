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
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    defer server.close()
    @async.with_task_group(group => {
      group.spawn_bg(() => {
        let (conn, _) = server.accept()
        defer conn.close()
        try {
          let tls = @tls.Tls::server(
            conn,
            private_key_file=fixture + "/key.pem",
            private_key_type=PEM,
            certificate_file=fixture + "/cert.pem",
            certificate_type=PEM,
          )
          defer tls.close()
          tls.write("HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
        } catch {
          _ => ()
        }
      })
      let config = {
        ..@core.Config::default(),
        allowed_hosts: ["localhost"],
        allow_loopback: true,
      }
      let fetcher : @fetcher.CurlFetcher = { program: "curl", }
      assert_true(
        try
          fetcher.request(
            @url.parse("https://localhost:\{server.addr.port()}/"),
            config,
          )
        catch {
          @core.Protocol(_) => true
          _ => false
        } noraise {
          _ => false
        },
      )
    })
  })
}

///|
// The pinned toolchain cannot condition imports by OS. The Unix-only fixture
// intentionally retains these imports; type references document that fact on Windows.
#cfg(platform="windows")
let _unix_fixture_imports : Unit = {
  ignore((_ : @tls.Tls?) => ())
  ignore((_ : @fs.File?) => ())
}
