///|
/// One hop only: the engine must apply Robots and scheduling to every redirect target.
pub(open) trait UnsafeFetcher {
  async fn fetch(Self, @url.Url, @core.Config) -> @core.Response
}

///|
pub(all) struct CurlFetcher {
  program : String
}

///|
pub extend CurlFetcher with UnsafeFetcher::{fetch}

///|
pub impl UnsafeFetcher for CurlFetcher with fn fetch(self, url, config) {
  self.request(url, config)
}

///|
/// Shell-free curl adapter. DNS is resolved/checked in MoonBit then pinned using --resolve.
/// No automatic redirect, ambient proxies, curlrc, cookies, or credentials.
pub async fn CurlFetcher::request(
  self : CurlFetcher,
  url : @url.Url,
  config : @core.Config,
  verb~ : String = "GET",
  headers~ : Map[String, String] = {},
) -> @core.Response {
  config.validate()
  guard verb == "GET" || verb == "HEAD" else {
    raise @core.Invalid("only GET and HEAD supported")
  }
  @async.with_timeout(config.timeout_ms, () => {
    let ip = @security.resolve_checked(url, config)
    let seconds = (config.timeout_ms.to_double() / 1000.0).to_string()
    let args = [
      "--disable",
      "--silent",
      "--show-error",
      "--globoff",
      "--path-as-is",
      "--noproxy",
      "*",
      "--proxy",
      "",
      "--proto",
      "=http,https",
      "--max-redirs",
      "0",
      "--connect-timeout",
      seconds,
      "--max-time",
      seconds,
      "--max-filesize",
      config.max_body_bytes.to_string(),
      "--resolve",
      "\{url.host}:\{url.port}:\{ip}",
      "--include",
      "--compressed",
      "--write-out",
      "%{stderr}MOONCRAWLER_REMOTE=%{remote_ip}\n",
      "--user-agent",
      config.user_agent,
    ]
    if verb == "HEAD" {
      args.push("--head")
    }
    for name, value in headers {
      let n = name.to_lower()
      if n != "accept" &&
        n != "accept-language" &&
        n != "if-none-match" &&
        n != "if-modified-since" {
        raise @core.Invalid("header not in safe request allowlist")
      }
      if value.contains_any(chars="\r\n\u0000") {
        raise @core.Invalid("header injection")
      }
      args.push("--header")
      args.push("\{name}: \{value}")
    }
    args.push("--url")
    args.push(url.key())
    let output = @shell.Cmd(self.program, args).output(
      timeout_ms=config.timeout_ms,
      max_output_bytes=config.max_body_bytes + config.max_header_bytes + 4096,
    )
    if output.exit_code() != 0 {
      if [5, 6, 7, 18, 28, 52, 55, 56].contains(output.exit_code()) {
        raise @core.Network("curl transport exit \{output.exit_code()}")
      }
      raise @core.Protocol("curl transport exit \{output.exit_code()}")
    }
    if output.stderr().trim().to_owned() != "MOONCRAWLER_REMOTE=" + ip {
      raise @core.Security("connected peer differs from pinned destination")
    }
    decode(url, output.stdout_bytes(), config)
  })
}

///|
/// Decode bounded HTTP headers followed by the already decompressed response body.
pub fn decode(
  url : @url.Url,
  bytes : Bytes,
  config : @core.Config,
) -> @core.Response raise {
  let mut offset = 0
  for ;; {
    let rest = bytes[offset:].to_owned()
    let end = rest.find(b"\r\n\r\n").unwrap_or(-1)
    if end < 0 || offset + end + 4 > config.max_header_bytes {
      raise @core.Capacity("response headers exceed limit or incomplete")
    }
    let head = @utf8.decode(rest[:end].to_owned())
    let lines = head.split("\r\n").to_array()
    let status_parts = lines[0].to_owned().split(" ").to_array()
    guard status_parts.length() >= 2 &&
      ["HTTP/1.0", "HTTP/1.1", "HTTP/2", "HTTP/3"].contains(
        status_parts[0].to_owned(),
      ) &&
      status_parts[1].length() == 3 &&
      status_parts[1].iter().all(c => c >= '0' && c <= '9') else {
      raise @core.Protocol("invalid HTTP status")
    }
    let status = @string.parse_int(status_parts[1])
    if status < 100 || status > 599 {
      raise @core.Protocol("invalid status code")
    }
    if status == 101 {
      raise @core.Protocol("protocol upgrade unsupported")
    }
    offset += end + 4
    if status >= 100 && status < 200 && status != 101 {
      continue
    }
    let headers : Map[String, String] = Map([])
    for i in 1..<lines.length() {
      let pair = lines[i].to_owned().split(":").to_array()
      guard pair.length() >= 2 else { raise @core.Protocol("invalid header") }
      let name = pair[0].to_owned().to_lower()
      if !token(name) || !header_value(lines[i].to_owned()) {
        raise @core.Protocol(
          "invalid response header token or control character",
        )
      }
      let value = pair[1:].map(x => x.to_owned()).join(":").trim().to_owned()
      if headers.contains(name) &&
        [
          "location", "content-type", "content-length", "transfer-encoding", "retry-after",
        ].contains(name) {
        raise @core.Protocol("ambiguous response header")
      }
      if name != "set-cookie" {
        headers[name] = match headers.get(name) {
          Some(old) => old + ", " + value
          None => value
        }
      }
    }
    if headers.contains("content-length") &&
      headers.contains("transfer-encoding") {
      raise @core.Protocol("conflicting HTTP framing fields")
    }
    let raw_body = bytes[offset:].to_owned()
    if raw_body.length() > config.max_body_bytes {
      raise @core.Capacity("decoded response body exceeds limit")
    }
    let content_type = headers.get("content-type").unwrap_or("").to_lower()
    if content_type.contains("charset=") &&
      !content_type.contains("charset=utf-8") &&
      !content_type.contains("charset=\"utf-8\"") &&
      !content_type.contains("charset=us-ascii") {
      raise @core.Protocol("unsupported charset; install a decoding adapter")
    }
    let body = @utf8.decode(raw_body)
    return { url, status, headers, body, }
  }
}
