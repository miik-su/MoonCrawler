///|
priv struct Group {
  agents : Array[String]
  rules : Array[(String, Bool)]
}

///|
pub struct Rules {
  priv groups : Array[Group]
  sitemaps : Array[String]
}

///|
pub fn parse(text : String) -> Rules {
  let groups : Array[Group] = []
  let sitemaps : Array[String] = []
  let mut group : Group = { agents: [], rules: [], }
  for raw in text.split("\n") {
    let line = raw.to_owned().split("#").to_array()[0].trim().to_owned()
    let pair = line.split(":").to_array()
    if pair.length() < 2 {
      continue
    }
    let name = pair[0].trim().to_owned().to_lower()
    let value = pair[1:].map(x => x.to_owned()).join(":").trim().to_owned()
    match name {
      "user-agent" => {
        if !group.rules.is_empty() {
          groups.push(group)
          group = { agents: [], rules: [], }
        }
        group.agents.push(value.to_lower())
      }
      "allow" | "disallow" =>
        if !group.agents.is_empty() && !value.is_empty() {
          group.rules.push((value, name == "allow"))
        }
      "sitemap" => sitemaps.push(value)
      _ => ()
    }
  }
  if !group.agents.is_empty() {
    groups.push(group)
  }
  { groups, sitemaps, }
}

///|
/// Linear wildcard matcher; '$' only anchors the final position.
fn matches(pattern : String, path : String) -> Bool {
  let anchored = pattern.has_suffix("$")
  let p = if anchored {
    pattern[:pattern.length() - 1].to_owned()
  } else {
    pattern + "*"
  }
  for i = 0, j = 0, star = -1, mark = 0 {
    if j == path.length() {
      let mut k = i
      while k < p.length() && p[k] == '*' {
        k += 1
      }
      break k == p.length()
    }
    if i < p.length() && p[i] == '*' {
      continue i + 1, j, i, j
    }
    if i < p.length() && p[i] == path[j] {
      continue i + 1, j + 1, star, mark
    }
    if star >= 0 {
      continue star + 1, mark + 1, star, mark + 1
    }
    break false
  }
}

///|
fn hex_value(b : Byte) -> Int32 {
  let n = b.to_int()
  if n >= 48 && n <= 57 {
    n - 48
  } else if n >= 65 && n <= 70 {
    n - 55
  } else if n >= 97 && n <= 102 {
    n - 87
  } else {
    -1
  }
}

///|
/// RFC 9309 octet comparison: decode ASCII unreserved escapes, encode UTF-8 octets,
/// and keep reserved escapes distinct from literal reserved characters.
fn octets(value : String) -> String {
  let bytes = @utf8.encode(value)
  let out = StringBuilder()
  let digits = "0123456789ABCDEF"
  for i = 0; i < bytes.length(); {
    let n = bytes[i].to_int()
    if n == 37 && i + 2 < bytes.length() {
      let a = hex_value(bytes[i + 1])
      let b = hex_value(bytes[i + 2])
      if a >= 0 && b >= 0 {
        let v = a * 16 + b
        if (v >= 65 && v <= 90) ||
          (v >= 97 && v <= 122) ||
          (v >= 48 && v <= 57) ||
          v == 45 ||
          v == 46 ||
          v == 95 ||
          v == 126 {
          out.write_char(v.unsafe_to_char())
        } else {
          out.write_string("%")
          out.write_string(digits[a:a + 1].to_owned())
          out.write_string(digits[b:b + 1].to_owned())
        }
        continue i + 3
      }
    }
    if n >= 128 {
      out.write_string("%")
      out.write_string(digits[n / 16:n / 16 + 1].to_owned())
      out.write_string(digits[n % 16:n % 16 + 1].to_owned())
    } else {
      out.write_char(n.unsafe_to_char())
    }
    continue i + 1
  }
  out.to_string()
}

///|
pub fn Rules::allows(self : Rules, agent : String, path : String) -> Bool {
  let token = agent.to_lower().split("/").to_array()[0].to_owned()
  let mut specificity = -1
  for group in self.groups {
    for a in group.agents {
      let n = if a == "*" { 0 } else if a == token { a.length() } else { -1 }
      specificity = specificity.max(n)
    }
  }
  let mut best = -1
  let mut allowed = true
  let path = octets(path)
  for group in self.groups {
    if !group.agents.any(a => {
        (specificity == 0 && a == "*") || (specificity > 0 && a == token)
      }) {
      continue
    }
    for (pattern, allow) in group.rules {
      let pattern = octets(pattern)
      if matches(pattern, path) {
        let score = @utf8.encode(
          pattern.replace(old="*", new="").replace(old="$", new=""),
        ).length()
        if score > best || (score == best && allow) {
          best = score
          allowed = allow
        }
      }
    }
  }
  allowed
}

///|
pub fn Rules::sitemaps(self : Rules) -> Array[String] {
  self.sitemaps.copy()
}

///|
pub struct Cache {
  entries : Map[String, (Rules, Int64)]
}

///|
pub fn Cache::new() -> Cache {
  { entries: {}, }
}

///|
pub fn Cache::get(self : Cache, origin : String, now : Int64) -> Rules? {
  match self.entries.get(origin) {
    Some((rules, expires)) => if now < expires { Some(rules) } else { None }
    None => None
  }
}

///|
/// 4xx except 429 = unavailable/allow; network, 429 and 5xx = deny for five minutes.
pub fn Cache::update(
  self : Cache,
  origin : String,
  status : Int32,
  body : String,
  now : Int64,
) -> Rules {
  let (rules, ttl) = if status >= 200 && status < 300 {
    (parse(body), 86400000L)
  } else if status >= 400 && status < 500 && status != 429 {
    (parse(""), 3600000L)
  } else {
    (parse("User-agent: *\nDisallow: /"), 300000L)
  }
  self.entries[origin] = (rules, now + ttl)
  rules
}
