///|
fn token(name : String) -> Bool {
  !name.is_empty() &&
  name
  .iter()
  .all(c => {
    (c >= 'a' && c <= 'z') ||
    (c >= '0' && c <= '9') ||
    "!#$%&'*+-.^_`|~".contains(c.to_string())
  })
}

///|
fn header_value(value : String) -> Bool {
  value.iter().all(c => (c.to_int() >= 32 && c.to_int() != 127) || c == '\t')
}
