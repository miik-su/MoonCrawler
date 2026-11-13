///|
/// Controlled fixture only: a minimal localhost/A DNS client, never a production resolver.
struct WireResolver {
  server : @socket.Addr
}

///|
extend WireResolver with @security.Resolver::{resolve_all}

///|
let dns_question : Bytes = b"\x09localhost\x00\x00\x01\x00\x01"

///|
impl @security.Resolver for WireResolver with fn resolve(self, host, port) {
  self.resolve_all(host, port)[0]
}

///|
impl @security.Resolver for WireResolver with fn resolve_all(self, host, port) {
  @async.with_timeout(1500, () => {
    if host != "localhost" {
      raise @security.Unknown
    }
    let client = @socket.UdpClient(self.server)
    defer client.close()
    let query = Buffer()
    query.write_bytes(b"\x13\x37\x01\x00\x00\x01\x00\x00\x00\x00\x00\x00")
    query.write_bytes(dns_question)
    client.send(query.to_bytes())
    let buffer = FixedArray::make(512, b'\x00')
    let n = client.recv(buffer)
    let data = Bytes::makei(n, i => buffer[i])
    if n < 12 + dns_question.length() ||
      data[:2] != b"\x13\x37" ||
      data[2] != b'\x81' ||
      data[4:6] != b"\x00\x01" ||
      data[12:12 + dns_question.length()] != dns_question {
      raise @security.Unknown
    }
    if data[3] == b'\x83' {
      raise @security.NotFound
    }
    if data[3] != b'\x80' ||
      data[6] != b'\x00' ||
      data[8:12] != b"\x00\x00\x00\x00" {
      raise @security.Unknown
    }
    let count = data[7].to_int()
    if count < 1 || count > 8 || n != 12 + dns_question.length() + count * 16 {
      raise @security.Unknown
    }
    let addresses : Array[@socket.Addr] = []
    for i in 0..<count {
      let p = 12 + dns_question.length() + i * 16
      if data[p:p + 12] != b"\xc0\x0c\x00\x01\x00\x01\x00\x00\x00\x00\x00\x04" {
        raise @security.Unknown
      }
      addresses.push(
        @socket.Addr::parse(
          "\{data[p + 12].to_int()}.\{data[p + 13].to_int()}.\{data[p + 14].to_int()}.\{data[p + 15].to_int()}:\{port}",
        ),
      )
    }
    addresses
  }) catch {
    @security.NotFound => raise @security.NotFound
    @async.TimeoutError => raise @security.Temporary
    _ => raise @security.Unknown
  }
}

///|
async fn dns_reply(
  server : @socket.UdpServer,
  answers : Array[Bytes],
  bad_id~ : Bool = false,
  missing~ : Bool = false,
) -> Unit {
  let buffer = FixedArray::make(512, b'\x00')
  let (n, peer) = server.recvfrom(buffer)
  let query = Bytes::makei(n, i => buffer[i])
  assert_eq(query[12:], dns_question[:])
  let out = Buffer()
  out.write_bytes(if bad_id { b"\x13\x38" } else { query[:2].to_owned() })
  out.write_bytes(
    if missing {
      b"\x81\x83\x00\x01\x00"
    } else {
      b"\x81\x80\x00\x01\x00"
    },
  )
  out.write_byte(answers.length().to_byte())
  out.write_bytes(b"\x00\x00\x00\x00")
  out.write_bytes(dns_question)
  for ip in answers {
    out.write_bytes(b"\xc0\x0c\x00\x01\x00\x01\x00\x00\x00\x00\x00\x04")
    out.write_bytes(ip)
  }
  server.sendto(out.to_bytes(), peer)
}

///|
struct WireFetcher {
  resolver : WireResolver
}

///|
impl @fetcher.UnsafeFetcher for WireFetcher with fn fetch(self, url, config) {
  let curl : @fetcher.CurlFetcher = { program: "curl", }
  curl.request(url, config, resolver=self.resolver)
}

///|
async test "TTL-zero DNS wire rebinding is blocked on a real HTTP redirect" {
  @async.with_timeout(10000, () => {
    let dns = @socket.UdpServer(@socket.Addr::parse("127.0.0.1:0"))
    defer dns.close()
    let http = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    defer http.close()
    let config = {
      ..@core.Config::default(),
      allowed_hosts: ["localhost"],
      allow_loopback: true,
      robots: false,
      delay_ms: 0,
      max_attempts: 1,
    }
    @async.with_task_group(group => {
      group.spawn_bg(() => {
        dns_reply(dns, [b"\x7f\x00\x00\x01"])
        dns_reply(dns, [b"\xa9\xfe\xa9\xfe"])
      })
      group.spawn_bg(() => {
        let (conn, _) = http.accept()
        defer conn.close()
        assert_eq(conn.read_request().path, "/start")
        conn.skip_request_body()
        conn.send_response(302, "Found", extra_headers={ "Location": "/next" })
        conn.end_response()
      })
      let crawler = @engine.Engine::new(
        config,
        WireFetcher::{ resolver: { server: dns.addr, }, },
        @storage.MemoryStore::new(),
      )
      crawler.seed("http://localhost:\{http.addr.port()}/start") |> ignore
      crawler.run()
      assert_eq(crawler.frontier.count(PermanentlyFailed), 1)
      assert_eq(crawler.pages().length(), 0)
      assert_true(crawler.frontier.snapshot()[0].error.contains("Security"))
    })
  })
}

///|
async test "wire DNS mixed answers mismatched IDs and NXDOMAIN fail closed" {
  @async.with_timeout(10000, () => {
    let dns = @socket.UdpServer(@socket.Addr::parse("127.0.0.1:0"))
    defer dns.close()
    let config = {
      ..@core.Config::default(),
      allowed_hosts: ["localhost"],
      allow_loopback: true,
    }
    let resolver = WireResolver::{ server: dns.addr, }
    let url = @url.parse("http://localhost/")
    @async.with_task_group(group => {
      group.spawn_bg(() => {
        dns_reply(dns, [b"\x08\x08\x08\x08", b"\x0a\x00\x00\x01"])
        dns_reply(dns, [b"\x7f\x00\x00\x01"], bad_id=true)
        dns_reply(dns, [], missing=true)
      })
      assert_true(
        try @security.resolve_checked(url, config, resolver~) catch {
          @core.Security(_) => true
          _ => false
        } noraise {
          _ => false
        },
      )
      assert_true(
        try @security.resolve_checked(url, config, resolver~) catch {
          @core.DnsUnknown => true
          _ => false
        } noraise {
          _ => false
        },
      )
      assert_true(
        try @security.resolve_checked(url, config, resolver~) catch {
          @core.Protocol(_) => true
          _ => false
        } noraise {
          _ => false
        },
      )
    })
  })
}
