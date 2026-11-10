///|
test "oversized rules and pathological matching fail closed" {
  assert_false(
    @robots.parse("User-agent: *\nDisallow: /" + String::make(2049, 'a')).allows(
      "bot", "/safe",
    ),
  )
  let text = StringBuilder()
  text.write_string("User-agent: *\n")
  for _ in 0..<4097 {
    text.write_string("Disallow: /blocked\n")
  }
  assert_false(@robots.parse(text.to_string()).allows("bot", "/safe"))
}
