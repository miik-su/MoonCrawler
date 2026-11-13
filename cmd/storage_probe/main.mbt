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
  let (count, batch) = if args[1] == "catalog" {
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
    "max_batch_pages": @json.to_json(batch),
    "wall_elapsed_ms": @json.to_json(@env.now() - start),
  }
  @fs.write_file(dir + "/ready.json", report.stringify())
  while !@fs.exists(dir + "/release") {
    @async.sleep(10)
  }
}
