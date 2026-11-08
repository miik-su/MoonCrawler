///|
async test "journal replay compaction partial files and sequence gaps" {
  let dir = @fs.tmpdir(prefix="mooncrawler-wal-")
  defer @fs.rmdir(dir, recursive=true)
  let store = @storage.FileStore::open(dir)
  defer store.close()
  let config = { ..@core.Config::default(), allowed_hosts: ["example.com"], }
  let f = @frontier.Frontier::new(config)
  let adapter : &@storage.Storage = store
  adapter.save({ version: 1, config, tasks: [], pages: [], saved_at: 0L, })
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
  adapter.commit_batch(config, f.drain_changes(), [], 1L)
  let lease = f.claim(1L).unwrap()
  adapter.commit_batch(config, f.drain_changes(), [], 2L)
  f.complete(lease)
  adapter.commit_batch(config, f.drain_changes(), [], 3L)
  let saved = adapter.load().unwrap()
  let first_record = @fs.read_file(dir + "/event-1.json").text()
  assert_eq(saved.tasks[0].state, Succeeded)
  @fs.write_file(dir + "/staging-aborted.tmp", "half-written")
  assert_eq(adapter.load().unwrap().tasks[0].state, Succeeded)
  adapter.save(saved)
  @fs.write_file(dir + "/event-1.json", first_record)
  assert_eq(adapter.load().unwrap().tasks.length(), 1)
  adapter.commit_batch(config, [], [], 4L)
  @fs.write_file(dir + "/event-4.json", "truncated")
  assert_true(
    try adapter.load() catch {
      _ => true
    } noraise {
      _ => false
    },
  )
}
