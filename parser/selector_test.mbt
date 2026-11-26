///|
test "bounded selectors extract first matching text and attribute" {
  let p = @parser.SelectorParser::new([
    { name: "title", selector: "H1", attribute: None, },
    { name: "summary", selector: ".Summary", attribute: None, },
    { name: "id", selector: "[data-id]", attribute: Some("data-id"), },
    { name: "link", selector: "#source", attribute: Some("href"), },
  ])
  let page = p.parse({
    url: @url.parse("https://example.com/"),
    status: 200,
    headers: { "content-type": "text/html" },
    body: "<h1>Moon</h1><p class='small Summary' data-id='m1'>Hello</p><p class=Summary>Later</p><a id=source href='/info'>Source</a>",
  })
  assert_eq(page.metadata.get("extract.title"), Some("Moon"))
  assert_eq(page.metadata.get("extract.summary"), Some("Hello"))
  assert_eq(page.metadata.get("extract.id"), Some("m1"))
  assert_eq(page.metadata.get("extract.link"), Some("/info"))
  assert_true(
    try
      @parser.SelectorParser::new([
        { name: "invalid", selector: "article > p", attribute: None, },
      ])
    catch {
      @core.Invalid(_) => true
      _ => false
    } noraise {
      _ => false
    },
  )
}
