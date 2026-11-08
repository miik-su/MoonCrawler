///|
test "host capacity delays and pause do not block other hosts" {
  let s = @scheduler.Scheduler::new({
    ..@core.Config::default(),
    allow_any_public_host: true,
  })
  assert_true(s.acquire("a", 0L))
  assert_false(s.acquire("a", 0L))
  assert_true(s.acquire("b", 0L))
  s.release("a")
  assert_false(s.acquire("a", 999L))
  assert_true(s.acquire("a", 1000L))
  s.release("a")
  s.defer_host("a", 10000L)
  assert_false(s.acquire("a", 9999L))
  s.pause()
  assert_false(s.acquire("c", 10000L))
  s.unpause()
  assert_true(s.acquire("c", 10000L))
}
