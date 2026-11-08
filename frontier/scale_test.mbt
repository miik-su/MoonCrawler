///|
test "ten thousand canonical tasks preserve priority uniqueness and cancellation" {
  let config = {
    ..{ ..@core.Config::default(), allow_any_public_host: true, },
    max_pages: 10000,
  }
  let f = @frontier.Frontier::new(config)
  for i in 0..<10000 {
    let request : @core.Request = {
      url: @url.parse("https://example.com/\{i}"),
      depth: 0,
      priority: i,
      source: "",
    }
    assert_true(f.enqueue(request, 0L))
    assert_false(f.enqueue(request, 0L))
  }
  assert_true(f.cancel(@url.parse("https://example.com/9999")))
  for i = 9998; i >= 0; i = i - 1 {
    let task = f.claim(0L).unwrap()
    assert_eq(task.request.priority, i)
    f.complete(task)
  }
  assert_false(f.has_work())
  assert_true(f.claim(0L) is None)
}
