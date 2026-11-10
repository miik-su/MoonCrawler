///|
test "100K task model examines hosts rather than blocked task count" {
  let config = {
    ..@core.Config::default(),
    allow_any_public_host: true,
    max_pages: 100000,
  }
  let f = @frontier.Frontier::new(config)
  for i in 0..<99999 {
    f.enqueue(
      {
        url: @url.parse("https://a.example/\{i}"),
        depth: 0,
        priority: 9,
        source: "",
      },
      0L,
    )
    |> ignore
  }
  f.enqueue(
    {
      url: @url.parse("https://b.example/"),
      depth: 0,
      priority: 0,
      source: "",
    },
    0L,
  )
  |> ignore
  let task = f.claim(0L, eligible=r => r.url.host != "a.example").unwrap()
  assert_eq(task.request.url.host, "b.example")
  let before = f.candidate_checks()
  for _ in 0..<100 {
    assert_true(f.claim(0L, eligible=_ => false) is None)
  }
  assert_eq(f.candidate_checks() - before, 100)
}
