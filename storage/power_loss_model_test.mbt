///|
// These tests change only a synthetic job's persisted file view with the writer
// closed. They do not cut power or model an OS/device write cache.
async fn power_fixture(
  dir : String,
  compact~ : String = "",
  later_event~ : Bool = false,
) -> String {
  let mut stop_before_cleanup = false
  let store = @storage.FileStore::open(dir, probe=stage => {
    if stop_before_cleanup && stage == "checkpoint_published" {
      raise @core.Storage("fixture stopped before cleanup")
    }
  })
  defer store.close()
  let config = { ..@core.Config::default(), allowed_hosts: ["example.com"], }
  store.save({ version: 1, config, tasks: [], pages: [], saved_at: 0L, })
  let index = @fs.read_file(dir + "/index.json").text()
  let frontier = @frontier.Frontier::new(config)
  let url = @url.parse("https://example.com/")
  assert_true(frontier.enqueue({ url, source: "", depth: 0, priority: 0, }, 0L))
  frontier.complete(frontier.claim(0L).unwrap())
  let page : @core.Page = {
    url: url.key(),
    title: "",
    description: "",
    text: "committed",
    canonical: "",
    links: [],
    images: [],
    metadata: {},
  }
  store.commit_batch(config, frontier.snapshot(), [page], 1L)
  if later_event {
    store.commit_batch(config, [], [], 2L)
  }
  if compact == "before_cleanup" {
    stop_before_cleanup = true
    assert_true(
      try store.compact() catch {
        @core.Storage(message) => message == "fixture stopped before cleanup"
        _ => false
      } noraise {
        _ => false
      },
    )
  } else if compact == "after_cleanup" {
    store.compact()
  }
  index
}

///|
async fn power_snapshot(dir : String) -> @storage.Snapshot {
  let store = @storage.FileStore::open(dir)
  defer store.close()
  store.load().unwrap()
}

///|
async test "unpublished staging is ignored" {
  let dir = @fs.tmpdir(prefix="crawler-power-model-")
  defer @fs.rmdir(dir, recursive=true)
  power_fixture(dir) |> ignore
  @fs.rename(dir + "/event-1.json", dir + "/staging-cut.tmp")
  let snapshot = power_snapshot(dir)
  assert_eq(snapshot.tasks.length(), 0)
  assert_eq(snapshot.pages.length(), 0)
}

///|
async test "missing final published WAL has no surviving gap witness" {
  let dir = @fs.tmpdir(prefix="crawler-power-model-")
  defer @fs.rmdir(dir, recursive=true)
  power_fixture(dir) |> ignore
  assert_eq(power_snapshot(dir).pages.length(), 1)
  @fs.remove(dir + "/event-1.json")
  let snapshot = power_snapshot(dir)
  assert_eq(snapshot.tasks.length(), 0)
  assert_eq(snapshot.pages.length(), 0)
}

///|
async test "lost WAL with a later record is rejected" {
  let dir = @fs.tmpdir(prefix="crawler-power-model-")
  defer @fs.rmdir(dir, recursive=true)
  power_fixture(dir, later_event=true) |> ignore
  @fs.remove(dir + "/event-1.json")
  assert_true(
    try power_snapshot(dir) catch {
      @core.Storage(message) => message == "journal sequence gap"
      _ => false
    } noraise {
      _ => false
    },
  )
}

///|
async test "torn published WAL is rejected" {
  let dir = @fs.tmpdir(prefix="crawler-power-model-")
  defer @fs.rmdir(dir, recursive=true)
  power_fixture(dir) |> ignore
  let path = dir + "/event-1.json"
  let bytes = @fs.read_file(path).binary()
  @fs.write_file(path, bytes[:bytes.length() / 2].to_owned())
  assert_true(
    try power_snapshot(dir) catch {
      _ => true
    } noraise {
      _ => false
    },
  )
}

///|
async test "rolled-back index before cleanup can replay the WAL" {
  let dir = @fs.tmpdir(prefix="crawler-power-model-")
  defer @fs.rmdir(dir, recursive=true)
  let old = power_fixture(dir, compact="before_cleanup")
  assert_true(@fs.exists(dir + "/event-1.json"))
  assert_true(@fs.read_file(dir + "/index.json").text() != old)
  @fs.write_file(dir + "/index.json", old)
  let snapshot = power_snapshot(dir)
  assert_eq(snapshot.tasks.length(), 1)
  assert_eq(snapshot.tasks[0].state, Succeeded)
  assert_eq(snapshot.pages.length(), 1)
  assert_eq(snapshot.pages[0].text, "committed")
}

///|
async test "rolled-back initial index after cleanup can hide committed data" {
  let dir = @fs.tmpdir(prefix="crawler-power-model-")
  defer @fs.rmdir(dir, recursive=true)
  let old = power_fixture(dir, compact="after_cleanup")
  assert_false(@fs.exists(dir + "/event-1.json"))
  assert_eq(power_snapshot(dir).pages.length(), 1)
  @fs.write_file(dir + "/index.json", old)
  let snapshot = power_snapshot(dir)
  assert_eq(snapshot.tasks.length(), 0)
  assert_eq(snapshot.pages.length(), 0)
}
