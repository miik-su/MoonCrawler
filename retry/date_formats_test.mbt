///|
test "all HTTP date formats and obsolete year interpretation" {
  let now = @time.PlainDateTime::of(2030, 1, 1).to_unix_second() * 1000L
  for
    date in [
      "Tue, 01 Jan 2030 00:00:01 GMT", "Tuesday, 01-Jan-30 00:00:01 GMT", "Tue Jan  1 00:00:01 2030",
    ] {
    assert_eq(@retry.retry_after(date, now_ms=now), Some(1000))
  }
  assert_eq(
    @retry.retry_after("Tuesday, 01-Jan-81 00:00:00 GMT", now_ms=now),
    Some(0),
  )
  assert_eq(
    @retry.retry_after("Tue, 31 Feb 2030 00:00:00 GMT", now_ms=now),
    None,
  )
}
