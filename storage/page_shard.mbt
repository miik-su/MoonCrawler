///|
async fn FileStore::page_shard(
  self : FileStore,
  prefix : String,
  part : Int32,
  pages : Array[@core.Page],
  now : Int64,
) -> String {
  let name = "\{prefix}-p-\{part}.json"
  let value = Delta::{
    job_id: self.job_id,
    sequence: self.sequence,
    tasks: [],
    pages,
    saved_at: now,
  }
  atomic_file(
    self.directory,
    name,
    wrap(@json.to_json(value)),
    probe=self.probe,
  )
  name
}
