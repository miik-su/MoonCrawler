///|
async test "foreign job records and missing journal sequence fail closed" {
  let a = @fs.tmpdir(prefix="mooncrawler-job-a-")
  let b = @fs.tmpdir(prefix="mooncrawler-job-b-")
  defer @fs.rmdir(a, recursive=true)
  defer @fs.rmdir(b, recursive=true)
  let sa = @storage.FileStore::open(a)
  let sb = @storage.FileStore::open(b)
  defer sa.close()
  defer sb.close()
  let aa : &@storage.Storage = sa
  let bb : &@storage.Storage = sb
  let config = { ..@core.Config::default(), allowed_hosts: ["example.com"], }
  let snapshot : @storage.Snapshot = {
    version: 1,
    config,
    tasks: [],
    pages: [],
    saved_at: 0L,
  }
  aa.save(snapshot)
  bb.save(snapshot)
  aa.commit_batch(config, [], [], 1L)
  bb.commit_batch(config, [], [], 1L)
  @fs.write_file(a + "/event-1.json", @fs.read_file(b + "/event-1.json").text())
  assert_true(
    try aa.load() catch {
      _ => true
    } noraise {
      _ => false
    },
  )
  bb.commit_batch(config, [], [], 2L)
  @fs.remove(b + "/event-1.json")
  assert_true(
    try bb.load() catch {
      _ => true
    } noraise {
      _ => false
    },
  )
}
