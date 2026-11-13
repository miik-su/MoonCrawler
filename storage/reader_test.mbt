///|
async test "page catalog returns only latest upserts and holds the job lock" {
  let dir = @fs.tmpdir(prefix="crawler-reader-")
  defer @fs.rmdir(dir, recursive=true)
  let config = { ..@core.Config::default(), allowed_hosts: ["example.com"], }
  let page : @core.Page = {
    url: "https://example.com/a",
    title: "",
    text: "old",
    description: "",
    canonical: "",
    metadata: {},
    links: [],
    images: [],
  }
  {
    let store = @storage.FileStore::open(dir)
    defer store.close()
    store.save({ version: 1, config, tasks: [], pages: [page], saved_at: 0L, })
    store.commit_batch(
      config,
      [],
      [{ ..page, text: "new", }, { ..page, url: "https://example.com/b", }],
      1L,
    )
  }
  let reader = @storage.PageReader::open(dir)
  defer reader.close()
  assert_eq(reader.page_count(), 2)
  assert_eq(reader.max_batch_pages(), 2)
  assert_eq(reader.read_page(page.url).unwrap().text, "new")
  assert_true(reader.read_page("https://example.com/missing") is None)
  assert_true(
    try @storage.FileStore::open(dir) catch {
      _ => true
    } noraise {
      other => {
        other.close()
        false
      }
    },
  )
  let found : Map[String, String] = Map([])
  reader.visit_pages(page => found[page.url] = page.text)
  assert_eq(found.length(), 2)
  assert_eq(found[page.url], "new")
  assert_eq(reader.export_jsonl(dir + "/export.jsonl"), 2)
  assert_true(
    try reader.export_jsonl(dir + "/event-999.json") catch {
      _ => true
    } noraise {
      _ => false
    },
  )
  assert_false(@fs.exists(dir + "/event-999.json"))
  assert_true(
    try reader.export_jsonl(dir + "/export.jsonl") catch {
      _ => true
    } noraise {
      _ => false
    },
  )
  reader.close()
  reader.close()
  assert_true(
    try reader.read_page(page.url) catch {
      _ => true
    } noraise {
      _ => false
    },
  )
  let store = @storage.FileStore::open(dir)
  defer store.close()
  let restored = store.load().unwrap()
  assert_eq(restored.pages.length(), 2)
}

///|
async test "catalog corruption and sequence gaps fail before output creation" {
  let dir = @fs.tmpdir(prefix="crawler-reader-corrupt-")
  defer @fs.rmdir(dir, recursive=true)
  let config = { ..@core.Config::default(), allowed_hosts: ["example.com"], }
  {
    let store = @storage.FileStore::open(dir)
    defer store.close()
    store.save({ version: 1, config, tasks: [], pages: [], saved_at: 0L, })
    store.commit_batch(config, [], [], 1L)
    store.commit_batch(config, [], [], 2L)
  }
  @fs.remove(dir + "/event-1.json")
  assert_true(
    try @storage.PageReader::open(dir) catch {
      _ => true
    } noraise {
      r => {
        r.close()
        false
      }
    },
  )
  // Opening failed readers must release their lock.
  let store = @storage.FileStore::open(dir)
  defer store.close()
}
