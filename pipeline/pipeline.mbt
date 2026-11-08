///|
pub trait Processor {
  process(Self, @core.Page) -> @core.Page? raise
}

///|
pub(all) struct CleanText {}

///|
pub impl Processor for CleanText with fn process(_self, page) {
  let b = StringBuilder()
  let mut space = false
  let mut started = false
  for c in page.text {
    if c == ' ' || c == '\n' || c == '\r' || c == '\t' || c == '\u00a0' {
      space = started
    } else {
      if space { b.write_string(" "); space = false }
      b.write_char(c)
      started = true
    }
  }
  Some({ ..page, text: b.to_string() })
}

///|
pub fn run(page : @core.Page, processors : Array[&Processor]) -> @core.Page? raise {
  let mut result = Some(page)
  for processor in processors {
    if result is Some(p) { result = processor.process(p) } else { break }
  }
  result
}
