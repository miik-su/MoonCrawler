///|
test "dedup priority fenced lease and bounded recovery" {
  let f = @frontier.Frontier::new(@core.Config::default())
  let a : @core.Request = {
    url: @url.parse("https://example.com"),
    depth: 0,
    priority: 0,
    source: "",
  }
  assert_true(f.enqueue(a, 0L))
  assert_false(f.enqueue(a, 0L))
  let b = { ..a, url: @url.parse("https://example.com/b"), priority: 9, }
  assert_true(f.enqueue(b, 0L))
  let lease = f.claim(0L).unwrap()
  assert_eq(lease.request.url.path, "/b")
  assert_eq(f.recover_expired(120000L), 1)
  let next = f.claim(120000L).unwrap()
  assert_true(
    try f.complete(lease) catch {
      _ => true
    } noraise {
      _ => false
    },
  )
  f.complete(next)
  assert_eq(f.count(Succeeded), 1)
  let restored = @frontier.restore(
    @core.Config::default(),
    f.snapshot(),
    120001L,
  )
  assert_eq(restored.count(Succeeded), 1)
  assert_false(restored.enqueue(b, 120001L))
}
