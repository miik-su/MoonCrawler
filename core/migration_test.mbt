///|
test "legacy config migration never grants open crawl scope" {
  let value = @json.to_json(@core.Config::default())
  if value is Object(fields) {
    fields.remove("schema_version") |> ignore
    fields.remove("allow_any_public_host") |> ignore
  }
  assert_true(
    try @core.decode_config(value) catch {
      _ => true
    } noraise {
      _ => false
    },
  )
  let scoped = { ..@core.Config::default(), allowed_hosts: ["example.com"], }
  assert_eq(@core.decode_config(@json.to_json(scoped)).schema_version, 2)
}
