///|
test "redirect continuation persists deadline and does not consume a retry" {
  let config = { ..@core.Config::default(), allowed_hosts: ["example.com"], }
  let f = @frontier.Frontier::new(config)
  assert_true(
    f.enqueue(
      {
        url: @url.parse("https://example.com/start"),
        depth: 0,
        priority: 0,
        source: "",
      },
      100000L,
    ),
  )
  let lease = f.claim(100000L).unwrap()
  f.follow(lease, @url.parse("https://example.com/target"), 1, 130000L)
  let restored = @frontier.restore(config, f.snapshot(), 110000L)
  assert_true(restored.claim(129999L) is None)
  let next = restored.claim(130000L).unwrap()
  assert_eq(next.attempts, 1)
  assert_eq(next.redirect_url, "https://example.com/target")
  assert_eq(next.redirect_hops, 1)
}
