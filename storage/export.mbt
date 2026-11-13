///|
/// Write one JSONL record at a time. Pages are still resident; no aggregate JSONL string.
/// Exclusive output creation refuses overwrite. A failed write can leave a partial output.
pub async fn export_jsonl(pages : Iter[@core.Page], path : String) -> Int32 {
  check_export_path(path)
  let file = @fs.open(
    path,
    mode=WriteOnly,
    create_mode=CreateNew,
    permission=0o600,
  )
  defer file.close()
  let mut count = 0
  for page in pages {
    file.write(@json.to_json(page).stringify() + "\n")
    count += 1
  }
  file.sync()
  count
}

///|
fn check_export_path(path : String) -> Unit raise @core.CrawlError {
  let name = path
    .replace_all(old="\\", new="/")
    .split("/")
    .to_array()
    .last()
    .unwrap_or("")
    .to_owned()
    .to_lower()
  if ["index.json", "checkpoint.json", "job.lock", "pause"].contains(name) ||
    (
      (name.has_prefix("event-") || name.has_prefix("shard-")) &&
      name.has_suffix(".json")
    ) ||
    (name.has_prefix("staging-") && name.has_suffix(".tmp")) {
    raise @core.Invalid("export filename is reserved for job storage")
  }
}
