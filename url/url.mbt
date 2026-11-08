///|
pub suberror UrlError {
  Invalid(String)
} derive(Debug)

///|
pub(all) struct Url {
  scheme : String
  host : String
  port : Int32
  path : String
  query : String
} derive(Debug, Eq, ToJson, FromJson)

///|
fn clean_path(path : String) -> String {
  let parts : Array[String] = []
  let input = path.split("/").to_array()
  for i, part in input {
    match part {
      "." => if i == input.length() - 1 { parts.push("") }
      ".." => {
        if !parts.is_empty() {
          ignore(parts.pop())
        }
        if i == input.length() - 1 {
          parts.push("")
        }
      }
      _ => if i > 0 { parts.push(part.to_owned()) }
    }
  }
  "/" + parts.join("/")
}

///|
fn hex(c : UInt16) -> Int32 {
  if c >= '0' && c <= '9' {
    c.to_int() - 48
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 87
  } else if c >= 'A' && c <= 'F' {
    c.to_int() - 55
  } else {
    -1
  }
}

///|
fn escapes(s : String) -> String raise UrlError {
  let out = StringBuilder()
  for i = 0; i < s.length(); {
    if s[i] == '%' {
      guard i + 2 < s.length() else {
        raise Invalid("truncated percent escape")
      }
      let a = hex(s[i + 1])
      let b = hex(s[i + 2])
      guard a >= 0 && b >= 0 else { raise Invalid("invalid percent escape") }
      let n = a * 16 + b
      if (n >= 65 && n <= 90) ||
        (n >= 97 && n <= 122) ||
        (n >= 48 && n <= 57) ||
        n == 45 ||
        n == 46 ||
        n == 95 ||
        n == 126 {
        out.write_char(n.unsafe_to_char())
      } else {
        out.write_string(s[i:i + 3].to_owned().to_upper())
      }
      continue i + 3
    }
    out.write_string(s[i:i + 1].to_owned())
    continue i + 1
  }
  out.to_string()
}

///|
/// Strict ASCII HTTP URL profile. IDNs must be supplied as punycode; IPv6 is rejected.
pub fn parse(input : String) -> Url raise UrlError {
  guard input.length() <= 8192 else {
    raise Invalid("URL exceeds 8192 code units")
  }
  for c in input {
    if c.to_int() <= 32 || c.to_int() >= 127 || c == '\\' {
      raise Invalid("URL requires ASCII encoding and no whitespace/backslash")
    }
  }
  let no_fragment = input.split("#").to_array()[0].to_owned()
  let (scheme, rest) = if no_fragment.to_lower().has_prefix("https://") {
    ("https", no_fragment[8:].to_owned())
  } else if no_fragment.to_lower().has_prefix("http://") {
    ("http", no_fragment[7:].to_owned())
  } else {
    raise Invalid("only http and https are accepted")
  }
  let stop = for i in 0..<rest.length() {
    if rest[i] == '/' || rest[i] == '?' {
      break i
    }
  } nobreak {
    rest.length()
  }
  let authority = rest[:stop].to_owned().to_lower()
  guard !authority.is_empty() && !authority.contains_any(chars="@[]%") else {
    raise Invalid("invalid authority")
  }
  let hp = authority.split(":").to_array()
  guard hp.length() <= 2 else { raise Invalid("IPv6 unsupported") }
  let host = hp[0].to_owned().trim_end(chars=".").to_owned()
  guard !host.is_empty() && host.length() <= 253 else {
    raise Invalid("invalid hostname length")
  }
  for label in host.split(".") {
    if label.is_empty() ||
      label.length() > 63 ||
      label.has_prefix("-") ||
      label.has_suffix("-") {
      raise Invalid("invalid hostname label")
    }
    for c in label {
      if !((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-') {
        raise Invalid("invalid hostname")
      }
    }
  }
  let port = if hp.length() == 2 {
    if hp[1].is_empty() || hp[1].iter().any(c => c < '0' || c > '9') {
      raise Invalid("invalid port")
    }
    @string.parse_int(hp[1]) catch {
      _ => raise Invalid("invalid port")
    }
  } else if scheme == "https" {
    443
  } else {
    80
  }
  guard port > 0 && port <= 65535 else {
    raise Invalid("port outside 1..65535")
  }
  let tail = rest[stop:].to_owned().split("?").to_array()
  let raw_path = tail[0].to_owned()
  let path = clean_path(
    escapes(if raw_path.is_empty() { "/" } else { raw_path }),
  )
  let query = if tail.length() > 1 {
    "?" + escapes(tail[1:].map(x => x.to_owned()).join("?"))
  } else {
    ""
  }
  { scheme, host, port, path, query, }
}

///|
pub fn Url::origin(self : Url) -> String {
  let port = if (self.scheme == "https" && self.port == 443) ||
    (self.scheme == "http" && self.port == 80) {
    ""
  } else {
    ":\{self.port}"
  }
  "\{self.scheme}://\{self.host}\{port}"
}

///|
pub fn Url::key(self : Url, include_query~ : Bool = true) -> String {
  self.origin() + self.path + (if include_query { self.query } else { "" })
}

///|
pub fn resolve(base : Url, reference : String) -> Url raise UrlError {
  let r = reference.trim().to_owned()
  if r.has_prefix("//") {
    return parse(base.scheme + ":" + r)
  }
  if r.split("/").to_array()[0].to_owned().split("?").to_array()[0].contains(
      ":",
    ) &&
    !r.has_prefix("/") &&
    !r.has_prefix("?") &&
    !r.has_prefix("#") {
    return parse(r)
  }
  if r.is_empty() || r.has_prefix("#") {
    return base
  }
  if r.has_prefix("?") {
    return parse(base.origin() + base.path + r)
  }
  if r.has_prefix("/") {
    return parse(base.origin() + r)
  }
  let parts = base.path.split("/").to_array()
  let parent = parts[:parts.length() - 1].map(x => x.to_owned()).join("/")
  parse(base.origin() + parent + "/" + r)
}

///|
pub fn allowed(
  url : Url,
  hosts : Array[String],
  denied_prefixes~ : Array[String] = [],
  denied_extensions~ : Array[String] = [],
) -> Bool {
  (hosts.is_empty() || hosts.contains(url.host)) &&
  !denied_prefixes.any(p => url.path.has_prefix(p)) &&
  !denied_extensions.any(e => url.path.to_lower().has_suffix(e.to_lower()))
}
