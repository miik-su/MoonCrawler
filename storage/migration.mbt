///|
fn decode_snapshot(value : Json) -> Snapshot raise {
  if value is Object(fields) {
    if fields.get("config") is Some(config) {
      fields["config"] = @core.upgrade_config(config)
    }
    if fields.get("tasks") is Some(Array(tasks)) {
      for task in tasks {
        if task is Object(t) {
          if !t.contains("redirect_url") {
            t["redirect_url"] = Json::string("")
          }
          if !t.contains("redirect_hops") {
            t["redirect_hops"] = Json::number(0)
          }
          if !t.contains("continuation") {
            t["continuation"] = Json::boolean(false)
          }
        }
      }
    }
  }
  @json.from_json(value)
}
