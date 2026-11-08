///|
test "default scope rejects omission and exact hosts do not include subdomains" {
  assert_true(
    try @core.Config::default().validate() catch {
      _ => true
    } noraise {
      _ => false
    },
  )
  let c = { ..@core.Config::default(), allowed_hosts: ["example.com"], }
  c.validate()
  assert_true(c.host_allowed("example.com"))
  assert_false(c.host_allowed("sub.example.com"))
  assert_false(c.host_allowed("other.com"))
}
