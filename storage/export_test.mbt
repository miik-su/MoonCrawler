///|
async test "streaming JSONL preserves records and refuses overwrite" {
  let dir = @fs.tmpdir(prefix="crawler-export-")
  defer @fs.rmdir(dir, recursive=true)
  let path = dir + "/pages.jsonl"
  let page : @core.Page = {
    url: "https://example.com/",
    title: "中文",
    description: "",
    text: "line\nquote\"",
    links: [],
    images: [],
    canonical: "",
    metadata: {},
  }
  let mut generated = 0
  let pages = Array::makei(100, i => i)
    .iter()
    .map(i => {
      generated += 1
      { ..page, url: "https://example.com/\{i}", }
    })
  assert_eq(generated, 0)
  assert_eq(@storage.export_jsonl(pages, path), 100)
  assert_eq(generated, 100)
  let lines = @fs.read_file(path).text().split("\n").to_array()
  assert_eq(lines.length(), 101)
  for i in 0..<100 {
    let loaded : @core.Page = @json.from_json(@json.parse(lines[i].to_owned()))
    assert_eq(loaded.url, "https://example.com/\{i}")
    assert_eq(loaded.text, page.text)
  }
  assert_true(
    try @storage.export_jsonl([page].iter(), path) catch {
      _ => true
    } noraise {
      _ => false
    },
  )
  assert_eq(@fs.read_file(path).text().split("\n").count(), 101)
}
