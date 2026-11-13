///|
async test "catalog rejects duplicate checkpoint records and duplicate task identities" {
  let config = { ..@core.Config::default(), allowed_hosts: ["example.com"], }
  for duplicate_file in [true, false] {
    let dir = @fs.tmpdir(prefix="crawler-catalog-duplicate-")
    defer @fs.rmdir(dir, recursive=true)
    let task : @core.Task = {
      request: {
        url: @url.parse("https://example.com/"),
        depth: 0,
        priority: 0,
        source: "",
      },
      state: Pending,
      attempts: 0,
      generation: 0,
      ready_at: 0L,
      lease_until: 0L,
      error: "",
      redirect_url: "",
      redirect_hops: 0,
      continuation: false,
    }
    {
      let store = FileStore::open(dir)
      defer store.close()
      store.save({ version: 1, config, tasks: [task], pages: [], saved_at: 0L, })
    }
    let index : Index = @json.from_json(unwrapped(dir + "/index.json"))
    if duplicate_file {
      atomic_file(
        dir,
        "index.json",
        wrap(
          @json.to_json({ ..index, shards: [index.shards[0], index.shards[0]], }),
        ),
        replace=true,
      )
    } else {
      let shard : Delta = @json.from_json(
        unwrapped(dir + "/" + index.shards[0]),
      )
      atomic_file(
        dir,
        index.shards[0],
        wrap(@json.to_json({ ..shard, tasks: [task, task], })),
        replace=true,
      )
    }
    assert_true(
      try PageReader::open(dir) catch {
        @core.Storage(_) => true
        _ => false
      } noraise {
        r => {
          r.close()
          false
        }
      },
    )
  }
}

///|
async test "catalog rejects ambiguous event filenames" {
  let dir = @fs.tmpdir(prefix="crawler-catalog-name-")
  defer @fs.rmdir(dir, recursive=true)
  {
    let store = FileStore::open(dir)
    defer store.close()
    let config = { ..@core.Config::default(), allowed_hosts: ["example.com"], }
    store.save({ version: 1, config, tasks: [], pages: [], saved_at: 0L, })
  }
  @fs.write_file(dir + "/event-01.json", "invalid")
  assert_true(
    try PageReader::open(dir) catch {
      @core.Storage(_) => true
      _ => false
    } noraise {
      r => {
        r.close()
        false
      }
    },
  )
}
