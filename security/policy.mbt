///|
/// Conservative routable IPv4 profile; IPv6 is not enabled in this adapter.
pub fn public_ipv4(ip : String, allow_loopback~ : Bool = false) -> Bool {
  let parts = ip.split(".").to_array()
  if parts.length() != 4 {
    return false
  }
  let nums : Array[Int32] = []
  for p in parts {
    if p.is_empty() ||
      (p.length() > 1 && p[0] == '0') ||
      p.iter().any(c => c < '0' || c > '9') {
      return false
    }
    let n = @string.parse_int(p) catch { _ => return false }
    if n < 0 || n > 255 {
      return false
    }
    nums.push(n)
  }
  let a = nums[0]
  if a == 127 {
    return allow_loopback
  }
  let address = (nums[0].reinterpret_as_uint() << 24) |
    (nums[1].reinterpret_as_uint() << 16) |
    (nums[2].reinterpret_as_uint() << 8) |
    nums[3].reinterpret_as_uint()
  let denied : Array[(UInt32, Int32)] = [
    (0x00000000U, 8),
    (0x0a000000U, 8),
    (0x64400000U, 10),
    (0x7f000000U, 8),
    (0xa9fe0000U, 16),
    (0xac100000U, 12),
    (0xc0000000U, 24),
    (0xc0000200U, 24),
    (0xc0586300U, 24),
    (0xc0a80000U, 16),
    (0xc6120000U, 15),
    (0xc6336400U, 24),
    (0xcb007100U, 24),
    (0xe0000000U, 4),
    (0xf0000000U, 4),
  ]
  !denied.any(range => (address & (0xffffffffU << (32 - range.1))) == range.0)
}

///|
pub fn check_url(
  url : @url.Url,
  config : @core.Config,
) -> Unit raise @core.CrawlError {
  if !config.host_allowed(url.host) {
    raise @core.Security("host outside allowlist")
  }
  if url.port != 80 &&
    url.port != 443 &&
    !(config.allow_loopback &&
    (url.host == "localhost" || url.host == "127.0.0.1")) {
    raise @core.Security("nonstandard port blocked")
  }
  let host = url.host
  if host == "localhost" ||
    host.has_suffix(".localhost") ||
    host.has_suffix(".local") ||
    host.has_suffix(".internal") ||
    host.has_suffix(".home") ||
    !host.contains(".") {
    if !(config.allow_loopback && host == "localhost") {
      raise @core.Security("local or ambiguous hostname blocked")
    }
  }
  let last = host.split(".").to_array().last().unwrap().to_owned()
  if last.iter().all(c => c >= '0' && c <= '9') || host.has_prefix("0x") {
    if !public_ipv4(host, allow_loopback=config.allow_loopback) {
      raise @core.Security("nonpublic or ambiguous IP literal")
    }
  }
}

///|
/// Resolve once, validate, and return the exact address the transport MUST pin.
pub async fn resolve_checked(url : @url.Url, config : @core.Config) -> String {
  check_url(url, config)
  let addr = @socket.Addr::resolve(url.host, port=url.port, protocol=OnlyV4)
  let ip = addr.to_string().split(":").to_array()[0].to_owned()
  if !public_ipv4(ip, allow_loopback=config.allow_loopback) {
    raise @core.Security("resolved destination is not public IPv4")
  }
  ip
}
