///|
/// Write one JSONL record at a time. Pages are still resident; no aggregate JSONL string.
/// Exclusive output creation refuses overwrite. A failed write can leave a partial output.
pub async fn export_jsonl(pages : Iter[@core.Page], path : String) -> Int32 {
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
