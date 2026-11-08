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
  let b = nums[1]
  let c = nums[2]
  if a == 127 {
    return allow_loopback
  }
  !(a == 0 ||
  a == 10 ||
  a >= 224 ||
  (a == 100 && b >= 64 && b <= 127) ||
  (a == 169 && b == 254) ||
  (a == 172 && b >= 16 && b <= 31) ||
  (a == 192 && (b == 168 || b == 0 || (b == 88 && c == 99))) ||
  (a == 198 && (b == 18 || b == 19 || (b == 51 && c == 100))) ||
  (a == 203 && b == 0 && c == 113))
}

///|
pub fn check_url(
  url : @url.Url,
  config : @core.Config,
) -> Unit raise @core.CrawlError {
  if !@url.allowed(url, config.allowed_hosts) {
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
