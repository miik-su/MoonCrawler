///|
fn main raise {
  let config = {
    ..@core.Config::default(),
    max_pages: 100000,
    allow_any_public_host: true,
  }
  let start = @env.now()
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
  let selected = f.claim(0L, eligible=r => r.url.host != "a.example").unwrap()
  let initial = f.candidate_checks()
  for _ in 0..<100 {
    f.claim(0L, eligible=_ => false) |> ignore
  }
  let result : Json = {
    "model": "host-blocked-100k",
    "tasks": 100000,
    "blocked_host_tasks": 99999,
    "eligible_host_tasks": 1,
    "selected_host": @json.to_json(selected.request.url.host),
    "initial_candidate_checks": @json.to_json(initial),
    "subsequent_polls": 100,
    "subsequent_candidate_checks": @json.to_json(f.candidate_checks() - initial),
    "wall_elapsed_ms": @json.to_json(@env.now() - start),
    "network_requests": 0,
    "cpu_time_measured": false,
  }
  let many_start = @env.now()
  let many = @frontier.Frontier::new(config)
  for i in 0..<10000 {
    many.enqueue(
      {
        url: @url.parse("https://h\{i}.example/"),
        depth: 0,
        priority: i,
        source: "",
      },
      0L,
    )
    |> ignore
  }
  let one = many.claim(0L, eligible=r => r.url.host == "h0.example").unwrap()
  let first_checks = many.candidate_checks()
  for _ in 0..<10 {
    many.claim(0L, eligible=_ => false) |> ignore
  }
  let hosts : Json = {
    "model": "10k-distinct-hosts",
    "hosts": 10000,
    "selected_host": @json.to_json(one.request.url.host),
    "initial_candidate_checks": @json.to_json(first_checks),
    "blocked_polls": 10,
    "blocked_candidate_checks": @json.to_json(
      many.candidate_checks() - first_checks,
    ),
    "wall_elapsed_ms": @json.to_json(@env.now() - many_start),
    "complexity": "linear in nonempty hosts per claim",
    "network_requests": 0,
  }
  println(@json.to_json([result, hosts]).stringify(indent=2))
}
