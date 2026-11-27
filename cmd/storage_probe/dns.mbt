///|
// The entire fixture runs in disposable Linux mount and network namespaces.
async fn check_system_cname(dir : String) -> Unit {
  assert_true(@async.platform is Linux)
  for kind in ["mnt", "net"] {
    let current = @shell.Cmd("readlink", ["/proc/self/ns/" + kind]).output(
      timeout_ms=3000,
    )
    let system = @shell.Cmd("readlink", ["/proc/1/ns/" + kind]).output(
      timeout_ms=3000,
    )
    current.check()
    system.check()
    assert_true(
      current.stdout() != system.stdout(),
      msg="requires a private Linux namespace",
    )
  }
  @shell.Cmd("ip", ["link", "set", "lo", "up"]).run(timeout_ms=3000)
  @shell.Cmd("mount", ["--bind", dir + "/nsswitch.conf", "/etc/nsswitch.conf"]).run(
    timeout_ms=3000,
  )
  @shell.Cmd("mount", ["--bind", dir + "/resolv.conf", "/etc/resolv.conf"]).run(
    timeout_ms=3000,
  )
  let dns = @socket.UdpServer(@socket.Addr::parse("127.0.0.1:53"))
  defer dns.close()
  let config = {
    ..@core.Config::default(),
    allowed_hosts: ["public.example", "private.example"],
  }
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      group.spawn_bg(no_wait=true, () => {
        for ;; {
          reply_to_alias(dns)
        }
      })
      let ip = @security.resolve_checked(
        @url.parse("https://public.example/"),
        config,
      )
      assert_eq(ip, "8.8.8.8")
      println(
        "SystemResolver public.example CNAME terminal IPv4 accepted: " + ip,
      )
      let system = @security.SystemResolver::{ }
      assert_eq(
        system.resolve("private.example", 443).to_string(),
        "10.0.0.1:443",
      )
      let denied = try
        @security.resolve_checked(
          @url.parse("https://private.example/"),
          config,
        )
      catch {
        @core.Security(reason) => reason
        err => raise err
      } noraise {
        _ => ""
      }
      assert_eq(denied, "resolved destination is not public IPv4")
      println(
        "SystemResolver private.example CNAME terminal IPv4 10.0.0.1 rejected: " +
        denied,
      )
    })
  })
}

///|
// Answer only the two fixture names. No HTTP client is started.
async fn reply_to_alias(dns : @socket.UdpServer) -> Unit {
  let data = FixedArray::make(512, b'\x00')
  let (n, client) = dns.recvfrom(data)
  let query = Bytes::makei(n, i => data[i])
  let public_name = b"\x06public\x07example\x00"
  let private_name = b"\x07private\x07example\x00"
  assert_true(n >= 12 + public_name.length() + 4)
  let (name, target, address) = if query[12:12 + public_name.length()] ==
    public_name[:] {
    (public_name, b"\x0dpublic-target\x07example\x00", b"\x08\x08\x08\x08")
  } else {
    assert_true(n >= 12 + private_name.length() + 4)
    assert_eq(query[12:12 + private_name.length()], private_name[:])
    (private_name, b"\x0eprivate-target\x07example\x00", b"\x0a\x00\x00\x01")
  }
  let qtype = 12 + name.length()
  let is_a = query[qtype:qtype + 2] == b"\x00\x01"
  assert_true(is_a || query[qtype:qtype + 2] == b"\x00\x1c")
  assert_eq(query[qtype + 2:qtype + 4], b"\x00\x01"[:])
  let reply = Buffer()
  reply.write_bytes(query[:2].to_owned())
  if !is_a {
    reply.write_bytes(b"\x81\x80\x00\x01\x00\x00\x00\x00\x00\x00")
    reply.write_bytes(query[12:qtype + 4].to_owned())
    dns.sendto(reply.to_bytes(), client)
    return
  }
  reply.write_bytes(b"\x81\x80\x00\x01\x00\x02\x00\x00\x00\x00")
  reply.write_bytes(query[12:qtype + 4].to_owned())
  reply.write_bytes(b"\xc0\x0c\x00\x05\x00\x01\x00\x00\x00\x00\x00")
  reply.write_byte(target.length().to_byte())
  reply.write_bytes(target)
  reply.write_bytes(target)
  reply.write_bytes(b"\x00\x01\x00\x01\x00\x00\x00\x00\x00\x04")
  reply.write_bytes(address)
  dns.sendto(reply.to_bytes(), client)
}
