///|
async fn main {
  let args = @env.args()
  let body = match args[1] {
    "nested" =>
      Array::make(2000, "<div>").join("") +
      "text" +
      Array::make(2000, "</div>").join("")
    "malformed" => Array::make(600, "<b><i>x</b></i>").join("")
    "long_attribute" =>
      "<div title='" + String::make(500000, 'x') + "'>text</div>"
    "entities" => "<p>" + Array::make(60000, "&amp;").join("") + "</p>"
    _ => fail("unknown probe fixture")
  }
  let start = @env.now()
  let response : @core.Response = {
    url: @url.parse("https://example.com/"),
    status: 200,
    headers: { "content-type": "text/html" },
    body,
  }
  let result : Json = try {
    let page = @parser.extract(response)
    { "outcome": "parsed", "text_units": @json.to_json(page.text.length()) }
  } catch {
    e =>
      {
        "outcome": "rejected",
        "reason": match e {
          @core.Capacity(message) | @core.Protocol(message) => message
          _ => "other crawl error"
        },
      }
  }
  let report : Json = {
    "fixture": @json.to_json(args[1]),
    "input_units": @json.to_json(body.length()),
    "elapsed_ms": @json.to_json(@env.now() - start),
    "result": result,
  }
  @fs.write_file(args[2] + "/ready.json", report.stringify())
  // Stay alive so the controller can read the OS high-water memory counter.
  while !@fs.exists(args[2] + "/release") {
    @async.sleep(10)
  }
}
