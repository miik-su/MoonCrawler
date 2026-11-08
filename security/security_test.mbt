///|
test "SSRF ranges alternate literals and metadata are denied" {
  for
    ip in [
      "127.0.0.1", "10.1.2.3", "172.16.0.1", "192.168.1.1", "169.254.169.254", "100.64.0.1",
      "198.18.0.1", "0.0.0.0", "224.0.0.1", "255.255.255.255", "127.1", "2130706433",
      "0177.0.0.1", "0x7f000001", "::1", "::ffff:127.0.0.1",
    ] {
    assert_false(@security.public_ipv4(ip))
  }
  assert_true(@security.public_ipv4("8.8.8.8"))
  assert_true(@security.public_ipv4("127.0.0.1", allow_loopback=true))
  let c = { ..@core.Config::default(), allow_any_public_host: true, }
  for
    u in [
      "http://localhost/", "http://metadata.internal/", "http://2130706433/", "https://example.com:8080/",
    ] {
    assert_true(
      try @security.check_url(@url.parse(u), c) catch {
        _ => true
      } noraise {
        _ => false
      },
    )
  }
}
