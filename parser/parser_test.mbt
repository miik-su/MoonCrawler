///|
test "HTML5 malformed multilingual DOM extraction base and nofollow" {
  let response : @core.Response = {
    url: @url.parse("https://example.com/start"),
    status: 200,
    headers: { "content-type": "text/html; charset=utf-8" },
    body: "<title>中文 &amp; Moon</title><base href='/docs/'><meta name='description' content='demo'><link rel=canonical href='article'><body><p>Hello <b>世界</p><a href='../next#x'>Next</a><a href='javascript:alert(1)'>bad</a><a rel=nofollow href='/ignored'>skip</a><img src='pic.png'><script>secret()</script>",
  }
  let page = @parser.extract(response)
  assert_eq(page.title, "中文 & Moon")
  assert_eq(page.description, "demo")
  assert_eq(page.links, ["https://example.com/next"])
  assert_eq(page.images, ["https://example.com/docs/pic.png"])
  assert_eq(page.canonical, "https://example.com/docs/article")
  assert_false(page.text.contains("secret"))
  assert_true(page.text.contains("世界"))
}
