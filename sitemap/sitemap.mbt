///|
pub(all) enum Kind {
  UrlSet
  Index
}

///|
pub(all) struct Document {
  kind : Kind
  locations : Array[String]
}

///|
fn invalid() -> @core.CrawlError {
  @core.Protocol("malformed or unsupported Sitemap XML")
}

///|
fn loc_value(text : String) -> String raise @core.CrawlError {
  let parts = text.trim().to_owned().split("&").to_array()
  let out = StringBuilder()
  out.write_string(parts[0].to_owned())
  for i in 1..<parts.length() {
    let part = parts[i].to_owned()
    let sections = part.split(";").to_array()
    guard sections.length() >= 2 else { raise invalid() }
    let entity = sections[0]
    match entity {
      "amp" => out.write_char('&')
      "lt" => out.write_char('<')
      "gt" => out.write_char('>')
      "apos" => out.write_char('\'')
      "quot" => out.write_char('"')
      _ => raise invalid()
    }
    out.write_string(part[entity.length() + 1:].to_owned())
  }
  let value = out.to_string()
  guard !value.is_empty() && value.length() <= 2048 else { raise invalid() }
  value
}

///|
fn space(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\r' || c == '\n'
}

///|
fn name_char(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '-' ||
  c == '_' ||
  c == ':' ||
  c == '.'
}

///|
/// Bounded, UTF-8 Sitemap subset. Only direct entry loc elements yield URLs.
/// DTD, entity declarations, CDATA and prefixed Sitemap elements are excluded.
pub fn parse(source : String) -> Document raise @core.CrawlError {
  if source.length() > 1048576 {
    raise @core.Capacity("Sitemap input exceeds 1 Mi code units")
  }
  let input = source.iter().to_array()
  let stack : Array[String] = []
  let locations : Array[String] = []
  let mut kind = UrlSet
  let mut entry = "url"
  let mut root_seen = false
  let mut location : String? = None
  let mut text = StringBuilder()
  let mut i = if input.get(0) == Some('\uFEFF') { 1 } else { 0 }
  while i < input.length() && space(input[i]) {
    i += 1
  }
  if i + 5 < input.length() &&
    String::from_array(input[i:i + 5].to_owned()) == "<?xml" &&
    space(input[i + 5]) {
    i += 6
    while i + 1 < input.length() && !(input[i] == '?' && input[i + 1] == '>') {
      if input[i] == '<' {
        raise invalid()
      }
      i += 1
    }
    if i + 1 >= input.length() {
      raise invalid()
    }
    i += 2
  }
  while i < input.length() {
    if input[i] != '<' {
      if stack.length() == 3 && stack[2] == "loc" {
        text.write_char(input[i])
      } else if stack.length() < 3 && !space(input[i]) {
        raise invalid()
      }
      i += 1
      continue
    }
    if i + 3 < input.length() &&
      input[i + 1] == '!' &&
      input[i + 2] == '-' &&
      input[i + 3] == '-' {
      i += 4
      while i + 2 < input.length() && !(input[i] == '-' && input[i + 1] == '-') {
        i += 1
      }
      if i + 2 >= input.length() || input[i + 2] != '>' {
        raise invalid()
      }
      i += 3
      continue
    }
    i += 1
    let closing = i < input.length() && input[i] == '/'
    if closing {
      i += 1
    }
    let start = i
    while i < input.length() && name_char(input[i]) {
      i += 1
    }
    if i == start || i - start > 128 {
      raise invalid()
    }
    let tag = String::from_array(input[start:i].to_owned())
    let attrs : Map[String, String] = Map([])
    while i < input.length() && space(input[i]) {
      while i < input.length() && space(input[i]) {
        i += 1
      }
      if closing || i >= input.length() || !name_char(input[i]) {
        break
      }
      let from = i
      while i < input.length() && name_char(input[i]) {
        i += 1
      }
      let name = String::from_array(input[from:i].to_owned())
      while i < input.length() && space(input[i]) {
        i += 1
      }
      guard i < input.length() && input[i] == '=' else { raise invalid() }
      i += 1
      while i < input.length() && space(input[i]) {
        i += 1
      }
      guard i < input.length() && (input[i] == '\'' || input[i] == '"') else {
        raise invalid()
      }
      let quote = input[i]
      i += 1
      let from = i
      while i < input.length() && input[i] != quote {
        if input[i] == '<' {
          raise invalid()
        }
        i += 1
      }
      guard i < input.length() && attrs.length() < 32 && !attrs.contains(name) else {
        raise invalid()
      }
      attrs[name] = String::from_array(input[from:i].to_owned())
      i += 1
    }
    let empty = !closing && i < input.length() && input[i] == '/'
    if empty {
      i += 1
    }
    guard i < input.length() && input[i] == '>' else { raise invalid() }
    i += 1
    if !closing {
      if stack.is_empty() {
        if root_seen ||
          (tag != "urlset" && tag != "sitemapindex") ||
          attrs.get("xmlns") !=
          Some("http://www.sitemaps.org/schemas/sitemap/0.9") {
          raise invalid()
        }
        root_seen = true
        if tag == "sitemapindex" {
          kind = Index
          entry = "sitemap"
        }
      } else if stack.length() == 1 && tag != entry {
        raise invalid()
      } else if stack.length() == 2 && tag == "loc" {
        if location is Some(_) {
          raise invalid()
        }
        text = StringBuilder()
      } else if stack.length() == 3 && stack[2] == "loc" {
        raise invalid()
      }
      if stack.length() >= 16 {
        raise @core.Capacity("Sitemap nesting limit")
      }
      if !stack.is_empty() && attrs.contains("xmlns") {
        raise invalid()
      }
      stack.push(tag)
    }
    if closing || empty {
      if stack.last() != Some(tag) {
        raise invalid()
      }
      if stack.length() == 3 && tag == "loc" {
        location = Some(loc_value(text.to_string()))
      }
      if stack.length() == 2 {
        guard location is Some(value) else { raise invalid() }
        if locations.length() >= 10000 {
          raise @core.Capacity("Sitemap location limit")
        }
        locations.push(value)
        location = None
      }
      stack.pop() |> ignore
    }
  }
  if !root_seen || !stack.is_empty() {
    raise invalid()
  }
  { kind, locations, }
}
