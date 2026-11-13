///|
async fn main {
  let args = @env.args()
  let dir = args[2]
  let config = { ..@core.Config::default(), allowed_hosts: ["example.com"], }
  if args[1] == "init" {
    let store = @storage.FileStore::open(dir)
    defer store.close()
    store.save({ version: 1, config, tasks: [], pages: [], saved_at: 0L, })
    return
  }
  if args[1] == "verify" {
    let store = @storage.FileStore::open(dir)
    defer store.close()
    let saved = store.load().unwrap()
    let committed = args[3] != "event_staged" && args[3] != "event_partial"
    assert_eq(saved.pages.length(), if committed { 1 } else { 0 })
    assert_eq(saved.tasks.length(), if committed { 1 } else { 0 })
    if committed {
      assert_eq(saved.pages[0].text, "new")
      assert_eq(saved.tasks[0].state, Succeeded)
    }
    return
  }
  let store = @storage.FileStore::open(dir, probe=stage => {
    if stage == args[3] {
      @fs.write_file(dir + "/ready", stage)
      // Parent forcibly terminates this process; no store.close/defer may run.
      for ;; {
        @async.sleep(1000)
      }
    }
  })
  defer store.close()
  store.load() |> ignore
  let frontier = @frontier.Frontier::new(config)
  frontier.enqueue(
    {
      url: @url.parse("https://example.com/"),
      depth: 0,
      priority: 0,
      source: "",
    },
    0L,
  )
  |> ignore
  frontier.complete(frontier.claim(0L).unwrap())
  let page : @core.Page = {
    url: "https://example.com/",
    title: "",
    description: "",
    text: "new",
    links: [],
    images: [],
    canonical: "",
    metadata: {},
  }
  store.commit_batch(config, frontier.snapshot(), [page], 1L)
  store.save({
    version: 1,
    config,
    tasks: frontier.snapshot(),
    pages: [page],
    saved_at: 1L,
  })
}
