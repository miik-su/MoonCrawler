# Read saved pages without retaining every body

`PageReader` holds the job lock until `close()`. Stop/pause the crawler before
opening a reader. It validates all indexed records and keeps page locations;
`read_page` loads one containing record and `visit_pages` streams the latest versions.
Do not collect every returned page if you want bounded body retention.

```mbt check
///|
async test {
  let dir = @fs.tmpdir(prefix="crawler-reader-example-")
  defer @fs.rmdir(dir, recursive=true)
  {
    let store = @storage.FileStore::open(dir)
    defer store.close()
    let config = { ..@core.Config::default(), allowed_hosts: ["example.com"], }
    store.save({ version: 1, config, tasks: [], pages: [], saved_at: 0L, })
  }
  let reader = @storage.PageReader::open(dir)
  defer reader.close()
  assert_eq(reader.page_count(), 0)
  assert_true(reader.read_page("https://example.com/missing") is None)
  assert_eq(reader.export_jsonl(dir + "/pages.jsonl"), 0)
}
```

CLI `export JOBDIR OUTPUT.jsonl` uses this reader. Output is exclusive and synchronized;
failed writes may leave a partial output. Reserved job filenames are rejected.
Legacy monolithic checkpoints migrate once through the <=64 MiB compatibility path.
Engine resume still materializes pages; reader metadata is O(tasks + pages + records),
and decoding a bounded record takes additional memory. This is not constant total RSS.
