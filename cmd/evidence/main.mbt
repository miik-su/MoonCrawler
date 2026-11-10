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
  println(result.stringify(indent=2))
}
