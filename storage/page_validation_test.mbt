///|
async test "invalid and duplicate pages are rejected before journal publication" {
  let dir = @fs.tmpdir(prefix="crawler-page-contract-")
  defer @fs.rmdir(dir, recursive=true)
  let store = @storage.FileStore::open(dir)
  defer store.close()
  let adapter : &@storage.Storage = store
  let config = {
    ..@core.Config::default(),
    allowed_hosts: ["example.com"],
    max_total_page_bytes: 1024,
    max_total_metadata_bytes: 512,
  }
  adapter.save({ version: 1, config, tasks: [], pages: [], saved_at: 0L, })
  let page : @core.Page = {
    url: "https://example.com/",
    title: "",
    description: "",
    text: "ok",
    links: [],
    images: [],
    canonical: "",
    metadata: {},
  }
  for
    bad in [
      { ..page, url: "invalid", },
      { ..page, url: "https://other.com/", },
      { ..page, text: String::make(2048, 'x'), },
    ] {
    assert_true(
      try adapter.commit_batch(config, [], [bad], 1L) catch {
        _ => true
      } noraise {
        _ => false
      },
    )
    assert_false(@fs.exists(dir + "/event-1.json"))
  }
  assert_true(
    try adapter.commit_batch(config, [], [page, page], 1L) catch {
      _ => true
    } noraise {
      _ => false
    },
  )
  adapter.commit_batch(config, [], [page], 1L)
  assert_eq(adapter.load().unwrap().pages.length(), 1)
}
