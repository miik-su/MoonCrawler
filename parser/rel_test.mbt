///|
test "rel tokens accept ASCII whitespace mixed case and multiple values" {
  let response : @core.Response = {
    url: @url.parse("https://example.com/"),
    status: 200,
    headers: { "content-type": "text/html" },
    body: "<link rel='alternate&#9;CaNoNiCaL&#10;next' href='/canonical'><a rel='NoFoLlOw&#9;ugc' href='/tab'>x</a><a rel='ugc&#10;nofollow' href='/line'>x</a><area rel='nofollow&#12;sponsored' href='/form'><a rel='nofollowed' href='/keep'>yes</a><a rel='ugc&#13;NOFOLLOW' href='/cr'>x</a><a rel='nofollow&#160;ugc' href='/nbsp'>yes</a>",
  }
  let page = @parser.extract(response)
  assert_eq(page.canonical, "https://example.com/canonical")
  assert_eq(page.links, ["https://example.com/keep", "https://example.com/nbsp"])
}
