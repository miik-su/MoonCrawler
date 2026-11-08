///|
pub(open) trait Parser {
  fn parse(Self, @core.Response) -> @core.Page raise
}

///|
pub(all) struct HtmlParser {}

///|
pub extend HtmlParser with Parser::{parse}

///|
pub impl Parser for HtmlParser with fn parse(_self, response) {
  extract(response)
}

///|
fn link(base : @url.Url, value : String) -> String? {
  try @url.resolve(base, value).key() catch {
    _ => None
  } noraise {
    s => Some(s)
  }
}

///|
fn add_unique(
  output : Array[String],
  seen : Map[String, Bool],
  value : String?,
) -> Unit {
  if value is Some(s) && !seen.contains(s) && output.length() < 10000 {
    seen[s] = true
    output.push(s)
  }
}

///|
/// HTML5 DOM supplied by moonbit-community/html. Iterative traversal avoids recursive extraction.
pub fn extract(response : @core.Response) -> @core.Page raise @core.CrawlError {
  let ct = response.headers.get("content-type").unwrap_or("").to_lower()
  if !ct.has_prefix("text/html") && !ct.has_prefix("application/xhtml+xml") {
    raise @core.Protocol("unsupported page content type")
  }
  // The upstream tree builder has no node budget. Bound input before DOM construction.
  if response.body.length() > 524288 {
    raise @core.Capacity("HTML parser input exceeds 512K code units")
  }
  let doc = @html.parse(response.body)
  if doc.nodes.length() > 100000 {
    raise @core.Capacity("HTML node budget exceeded")
  }
  let mut base = response.url
  for i in 0..<doc.nodes.length() {
    if doc.get_tag_name(i) == Some("base") {
      if doc.get_attribute(i, "href") is Some(href) {
        base = @url.resolve(response.url, href) catch { _ => response.url }
      }
      break
    }
  }
  let links : Array[String] = []
  let images : Array[String] = []
  let seen_links : Map[String, Bool] = Map([])
  let seen_images : Map[String, Bool] = Map([])
  let mut title = ""
  let mut description = ""
  let mut canonical = ""
  let metadata : Map[String, String] = { "content_type": ct }
  for i in 0..<doc.nodes.length() {
    match doc.get_tag_name(i) {
      Some("title") =>
        if title.is_empty() {
          title = doc.get_text_content(i).trim().to_owned()
        }
      Some("a") | Some("area") => {
        let rel = doc.get_attribute(i, "rel").unwrap_or("").to_lower()
        if !rel.split(" ").any(x => x == "nofollow") {
          if doc.get_attribute(i, "href") is Some(href) {
            add_unique(links, seen_links, link(base, href))
          }
        }
      }
      Some("img") =>
        if doc.get_attribute(i, "src") is Some(src) {
          add_unique(images, seen_images, link(base, src))
        }
      Some("meta") =>
        if doc.get_attribute(i, "name") is Some(name) &&
          doc.get_attribute(i, "content") is Some(content) {
          metadata[name.to_lower()] = content
          if name.to_lower() == "description" {
            description = content
          }
        }
      Some("link") =>
        if doc.get_attribute(i, "rel").unwrap_or("").to_lower() == "canonical" {
          if doc.get_attribute(i, "href") is Some(href) {
            canonical = link(base, href).unwrap_or("")
          }
        }
      _ => ()
    }
  }
  let text = StringBuilder()
  let stack : Array[Int32] = [doc.body_element]
  while !stack.is_empty() {
    let i = stack.pop().unwrap()
    match doc.get_node(i) {
      Some(TextNode(s)) => {
        text.write_string(s)
        text.write_string(" ")
      }
      Some(ElementNode(e)) =>
        if e.tag_name != "script" &&
          e.tag_name != "style" &&
          e.tag_name != "noscript" &&
          e.tag_name != "template" {
          for j = e.children.length() - 1; j >= 0; j = j - 1 {
            stack.push(e.children[j])
          }
        }
      _ => ()
    }
  }
  {
    url: response.url.key(),
    title,
    description,
    text: text.to_string().trim().to_owned(),
    links,
    images,
    canonical,
    metadata,
  }
}
