///|
test "cache bounds origins and reclaims expired entries" {
  let c = @robots.Cache::new(capacity=2)
  c.update("a", 200, "", 0L) |> ignore
  c.update("b", 200, "", 0L) |> ignore
  c.update("c", 200, "", 0L) |> ignore
  assert_true(c.get("a", 1L) is None)
  assert_true(c.get("c", 1L) is Some(_))
  c.update("d", 200, "", 86400001L) |> ignore
  assert_true(c.get("b", 86400001L) is None)
}
