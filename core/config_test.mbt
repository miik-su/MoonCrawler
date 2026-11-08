///|
test "configuration bounds fail before execution" {
  let c = @core.Config::default()
  c.validate()
  let bad1 = { ..c, concurrency: 0 }
  let bad2 = { ..c, user_agent: "bot\r\nX: y" }
  let bad3 = { ..c, max_attempts: 0 }
  assert_true(try bad1.validate() catch { _ => true } noraise { _ => false })
  assert_true(try bad2.validate() catch { _ => true } noraise { _ => false })
  assert_true(try bad3.validate() catch { _ => true } noraise { _ => false })
}
