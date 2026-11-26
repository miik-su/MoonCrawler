///|
async fn main {
  let args = @env.args()
  let dir = args[2]
  if args[1] == "init" {
    let store = @storage.FileStore::open(dir + "/job")
    defer store.close()
    let config = { ..@core.Config::default(), allowed_hosts: ["example.com"], }
    let text = String::make(1048576, 'x')
    let pages = Array::makei(65, i => @core.Page::{
      url: "https://example.com/\{i}",
      text,
      title: "",
      description: "",
      canonical: "",
      metadata: {},
      links: [],
      images: [],
    })
    store.save({ version: 1, config, tasks: [], pages, saved_at: 0L, })
    return
  }
  let start = @env.now()
  let (count, batch) = if args[1] == "metadata" {
    let store = @storage.FileStore::open(dir + "/job")
    defer store.close()
    let (state, ledger) = store.load_metadata().unwrap()
    (ledger.count(), state.pages.length())
  } else if args[1] == "full-restore" {
    let store = @storage.FileStore::open(dir + "/job")
    defer store.close()
    let saved = store.load().unwrap()
    (saved.pages.length(), saved.pages.length())
  } else if args[1] == "catalog" {
    let reader = @storage.PageReader::open(dir + "/job")
    defer reader.close()
    (reader.export_jsonl(dir + "/catalog.jsonl"), reader.max_batch_pages())
  } else {
    let store = @storage.FileStore::open(dir + "/job")
    defer store.close()
    let saved = store.load().unwrap()
    (
      @storage.export_jsonl(saved.pages.iter(), dir + "/full.jsonl"),
      saved.pages.length(),
    )
  }
  assert_eq(count, 65)
  let report : Json = {
    "mode": @json.to_json(args[1]),
    "pages": @json.to_json(count),
    "text_payload_bytes": 68157440,
    "wall_elapsed_ms": @json.to_json(@env.now() - start),
  }
  if report is Object(fields) {
    let field = if args[1] == "metadata" || args[1] == "full-restore" {
      "retained_page_bodies"
    } else {
      "max_batch_pages"
    }
    fields[field] = @json.to_json(batch)
  }
  @fs.write_file(dir + "/ready.json", report.stringify())
  while !@fs.exists(dir + "/release") {
    @async.sleep(10)
  }
}
