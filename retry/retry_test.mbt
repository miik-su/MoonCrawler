///|
test "only transient responses retry with capped jitter and Retry-After floor" {
  assert_true(@retry.retryable(429))
  assert_true(@retry.retryable(503))
  assert_false(@retry.retryable(404))
  assert_false(@retry.retryable(403))
  assert_eq(@retry.retry_after("12"), Some(12000))
  assert_eq(@retry.retry_after("-1"), None)
  assert_eq(@retry.delay(1, 0U), 1000)
  assert_eq(@retry.delay(10, 123U), 60000)
  assert_eq(@retry.delay(1, 7U, retry_after_ms=120000), 120000)
}
