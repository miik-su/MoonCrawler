///|
test "10K distinct hosts expose linear admission checks and preserve priority" {
  let config = {
    ..@core.Config::default(),
    allow_any_public_host: true,
    max_pages: 10000,
  }
  let queue = @frontier.Frontier::new(config)
  for i in 0..<10000 {
    assert_true(
      queue.enqueue(
        {
          url: @url.parse("https://h\{i}.example/"),
          depth: 0,
          priority: i,
          source: "",
        },
        0L,
      ),
    )
  }
  let selected = queue
    .claim(0L, eligible=r => r.url.host == "h0.example")
    .unwrap()
  assert_eq(selected.request.url.host, "h0.example")
  assert_eq(queue.candidate_checks(), 10000)
  let highest = queue.claim(0L).unwrap()
  assert_eq(highest.request.priority, 9999)
  let before = queue.candidate_checks()
  for _ in 0..<10 {
    assert_true(queue.claim(0L, eligible=_ => false) is None)
  }
  assert_eq(queue.candidate_checks() - before, 99980)
}
