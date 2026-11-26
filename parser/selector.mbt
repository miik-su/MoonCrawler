///|
pub(all) struct Field {
  name : String
  selector : String
  attribute : String?
}

///|
priv enum Selector {
  Tag(String)
  Class(String)
  Id(String)
  Attribute(String)
}

///|
pub struct SelectorParser {
  priv fields : Array[(Field, Selector)]
}

///|
pub extend SelectorParser with Parser::{parse}

///|
fn identifier(value : String) -> Bool {
  !value.is_empty() &&
  value.length() <= 128 &&
  value
  .iter()
  .all(c => {
    (c >= 'a' && c <= 'z') ||
    (c >= 'A' && c <= 'Z') ||
    (c >= '0' && c <= '9') ||
    c == '_' ||
    c == '-'
  })
}

///|
fn compile_selector(value : String) -> Selector raise @core.CrawlError {
  let (key, ctor) : (String, (String) -> Selector) = if value.has_prefix(".") {
    (value[1:].to_owned(), s => Class(s))
  } else if value.has_prefix("#") {
    (value[1:].to_owned(), s => Id(s))
  } else if value.has_prefix("[") && value.has_suffix("]") {
    (value[1:value.length() - 1].to_owned(), s => Attribute(s))
  } else {
    (value, s => Tag(s.to_lower()))
  }
  if !identifier(key) {
    raise @core.Invalid("unsupported selector syntax")
  }
  ctor(key)
}

///|
/// Compile up to 32 single-element selectors. None extracts text, Some extracts
/// an attribute verbatim. Results use extract.NAME metadata keys.
pub fn SelectorParser::new(
  fields : Array[Field],
) -> SelectorParser raise @core.CrawlError {
  if fields.length() > 32 {
    raise @core.Capacity("selector field limit")
  }
  let names : Map[String, Bool] = Map([])
  let compiled = []
  for field in fields {
    if !identifier(field.name) || names.contains(field.name) {
      raise @core.Invalid("duplicate or invalid extraction field")
    }
    if field.attribute is Some(attribute) && !identifier(attribute) {
      raise @core.Invalid("invalid extraction attribute")
    }
    names[field.name] = true
    compiled.push((field, compile_selector(field.selector)))
  }
  { fields: compiled, }
}

///|
fn Selector::matches(
  self : Selector,
  doc : @html.Document,
  node : Int32,
) -> Bool {
  guard doc.get_tag_name(node) is Some(tag) else { return false }
  match self {
    Tag(name) => tag == name
    Class(name) =>
      doc
      .get_attribute(node, "class")
      .unwrap_or("")
      .replace_all(old="\t", new=" ")
      .replace_all(old="\n", new=" ")
      .replace_all(old="\r", new=" ")
      .replace_all(old="\u000c", new=" ")
      .split(" ")
      .any(part => part == name)
    Id(name) => doc.get_attribute(node, "id") == Some(name)
    Attribute(name) => doc.has_attribute(node, name.to_lower())
  }
}

///|
pub impl Parser for SelectorParser with fn parse(self, response) {
  let (doc, ct) = parse_document(response)
  let page = extract_document(doc, response, ct)
  for (field, selector) in self.fields {
    for node in 0..<doc.nodes.length() {
      if !selector.matches(doc, node) {
        continue
      }
      let value = match field.attribute {
        None => Some(doc.get_text_content(node).trim().to_owned())
        Some(name) => doc.get_attribute(node, name.to_lower())
      }
      if value is Some(value) {
        if value.length() > 4096 {
          raise @core.Capacity("extraction field exceeds 4096 code units")
        }
        page.metadata["extract." + field.name] = value
      }
      break
    }
  }
  page
}
