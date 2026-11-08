///|
async test "atomic checkpoint round trip rejects corruption and preserves successful tasks" {
  let dir = @fs.tmpdir(prefix="mooncrawler-test-")
  defer @fs.rmdir(dir, recursive=true)
  let store = @storage.FileStore::open(dir)
  defer store.close()
  assert_true(
    try @storage.FileStore::open(dir) catch {
      _ => true
    } noraise {
      second => {
        second.close()
        false
      }
    },
  )
  let config = @core.Config::default()
  let f = @frontier.Frontier::new(config)
  assert_true(
    f.enqueue(
      {
        url: @url.parse("https://example.com"),
        depth: 0,
        priority: 0,
        source: "",
      },
      0L,
    ),
  )
  let lease = f.claim(0L).unwrap()
  let snapshot : @storage.Snapshot = {
    version: 1,
    config,
    tasks: f.snapshot(),
    pages: [],
    saved_at: 1L,
  }
  let adapter : &@storage.Storage = store
  adapter.save(snapshot)
  let loaded = adapter.load().unwrap()
  let recovered = @frontier.restore(config, loaded.tasks, 2L)
  assert_eq(recovered.count(RetryPending), 1)
  f.complete(lease)
  adapter.save({ ..snapshot, tasks: f.snapshot(), })
  assert_eq(
    @frontier.restore(config, adapter.load().unwrap().tasks, 3L).count(
      Succeeded,
    ),
    1,
  )
  @fs.write_file(dir + "/checkpoint.tmp", "interrupted write")
  assert_eq(adapter.load().unwrap().tasks.length(), 1)
  @fs.write_file(dir + "/checkpoint.json", "{broken")
  assert_true(
    try adapter.load() catch {
      _ => true
    } noraise {
      _ => false
    },
  )
}
