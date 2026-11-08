///|
async test "job lock nonregular paths fail before opening" {
  let dir = @fs.tmpdir(prefix="mooncrawler-path-")
  defer @fs.rmdir(dir, recursive=true)
  @fs.mkdir(dir + "/job.lock")
  assert_true(
    try @storage.FileStore::open(dir) catch {
      _ => true
    } noraise {
      store => {
        store.close()
        false
      }
    },
  )
}
