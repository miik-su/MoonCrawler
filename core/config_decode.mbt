///|
/// Upgrade legacy 0.1 keys without granting an implicit open crawl scope.
pub fn upgrade_config(value : Json) -> Json {
  match value {
    Object(fields) => {
      let defaults = @json.to_json(Config::default())
      if defaults is Object(defaults) {
        for
          key in [
            "schema_version", "allow_any_public_host", "max_robots_redirects", "max_robots_bytes",
            "robots_cache_capacity", "max_total_page_bytes", "max_total_metadata_bytes",
          ] {
          if !fields.contains(key) {
            fields[key] = defaults[key]
          }
        }
      }
      value
    }
    _ => value
  }
}

///|
pub fn decode_config(value : Json) -> Config raise {
  let config : Config = @json.from_json(upgrade_config(value))
  config.validate()
  config
}
