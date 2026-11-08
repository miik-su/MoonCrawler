///|
test "CIDR edges and every IPv6 authority profile fail closed" {
  for
    ip in [
      "100.64.0.0", "100.127.255.255", "172.16.0.0", "172.31.255.255", "198.18.0.0",
      "198.19.255.255", "192.0.2.1", "198.51.100.1", "203.0.113.1",
    ] {
    assert_false(@security.public_ipv4(ip))
  }
  for
    ip in [
      "100.63.255.255", "100.128.0.0", "172.15.255.255", "172.32.0.0", "198.17.255.255",
      "198.20.0.0",
    ] {
    assert_true(@security.public_ipv4(ip))
  }
  for
    url in [
      "http://[::ffff:127.0.0.1]/", "http://[fe80::1]/", "http://[fc00::1]/", "http://[fe80::1%25eth0]/",
    ] {
    assert_true(
      try @url.parse(url) catch {
        _ => true
      } noraise {
        _ => false
      },
    )
  }
}
