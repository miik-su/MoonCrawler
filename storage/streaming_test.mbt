///|
async test "streaming compaction preserves latest pages and budgets" {
  let directory = @fs.tmpdir(prefix="crawler-streaming-")
  defer @fs.rmdir(directory, recursive=true)
  let config = { ..@core.Config::default(), allowed_hosts: ["example.com"], }
  let page : @core.Page = {
    url: "https://example.com/",
    title: "",
    description: "",
    text: "first",
    links: [],
    images: [],
    canonical: "",
    metadata: {},
  }
  {
    let file = @storage.FileStore::open(directory)
    defer file.close()
    let store : &@storage.Storage = file
    store.save({ version: 1, config, tasks: [], pages: [page], saved_at: 1L, })
    store.commit_batch(config, [], [{ ..page, text: "latest", }], 2L)
    let (state, ledger) = file.load_metadata().unwrap()
    assert_eq(state.pages.length(), 0)
    assert_eq(ledger.count(), 1)
    file.compact()
    assert_false(@fs.exists(directory + "/event-1.json"))
    assert_eq(file.load_metadata().unwrap().1.size(), ledger.size())
  }
  let reader = @storage.PageReader::open(directory)
  defer reader.close()
  assert_eq(reader.read_page(page.url).unwrap().text, "latest")
}
