///|
test "structural amplification is rejected before DOM construction" {
  let response : @core.Response = {
    url: @url.parse("https://example.com/"),
    status: 200,
    headers: { "content-type": "text/html" },
    body: "<div>".repeat(5000),
  }
  assert_true(
    try @parser.extract(response) catch {
      @core.Capacity(_) => true
      _ => false
    } noraise {
      _ => false
    },
  )
}
