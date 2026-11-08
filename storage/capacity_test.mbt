///|
async test "segmented checkpoint supports aggregate pages above 64 MiB" {
  let dir = @fs.tmpdir(prefix="mooncrawler-large-")
  defer @fs.rmdir(dir, recursive=true)
  let store = @storage.FileStore::open(dir)
  defer store.close()
  let config = { ..@core.Config::default(), allowed_hosts: ["example.com"], }
  let body = String::make(524288, 'x')
  let pages : Array[@core.Page] = []
  for i in 0..<130 {
    pages.push({
      url: "https://example.com/\{i}",
      title: "",
      description: "",
      text: body,
      links: [],
      images: [],
      canonical: "",
      metadata: {},
    })
  }
  let adapter : &@storage.Storage = store
  adapter.save({ version: 1, config, tasks: [], pages, saved_at: 1L, })
  let restored = adapter.load().unwrap()
  assert_eq(restored.pages.length(), 130)
  assert_eq(restored.pages[129].text.length(), 524288)
}
