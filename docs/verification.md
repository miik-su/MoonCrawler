# Focused verification (2026-11-08)

MoonBit `0.10.17+d971670cd`, moon `0.1.20261023`, Windows native, curl `8.21.0`.
Only selected tests ran; no unfiltered `moon test` or full dependency suite.

| Selected file | Evidence |
| --- | --- |
| url/url_test.mbt | normalization, escaped separators, relative links and rejection |
| core/config_test.mbt | bounds and injection rejection |
| frontier/frontier_test.mbt | priority, dedup, stale lease fencing and recovery |
| frontier/scale_test.mbt | 10,000 tasks, duplicates, ordering and cancellation |
| retry/retry_test.mbt | transient policy, jitter and delta/date Retry-After |
| scheduler/scheduler_test.mbt | capacity, delay, cooldown and pause |
| robots/robots_test.mbt | groups, precedence, wildcards, expiry, UTF-8 and escapes |
| security/security_test.mbt | private/special IPs, metadata, numeric forms and ports |
| fetcher/fetcher_test.mbt | interim responses, headers, bounds and charset rejection |
| fetcher/network_test.mbt | real loopback curl and no automatic redirect |
| fetcher/limits_test.mbt | actual oversized response and stalled-server timeout |
| parser/parser_test.mbt | malformed multilingual HTML, base/canonical and links |
| pipeline/pipeline_test.mbt | multilingual whitespace cleanup |
| storage/storage_test.mbt | exclusion lock, atomic round-trip, temp write and corruption |
| engine/engine_test.mbt | discovery, retry, Robots, redirect safety, stop and resume |
| engine/failure_test.mbt | injected storage failure propagates; old lease safely replays |
| tools/cli_smoke.mbtx | init/validate/crawl/resume/status/export, real local HTTP, 2 pages, no repeated request |

Select files appropriate to a change:

```sh
moon test frontier/scale_test.mbt --target native
moon test engine/engine_test.mbt engine/failure_test.mbt --target native
moon test fetcher/network_test.mbt fetcher/limits_test.mbt --target native
moon run tools/cli_smoke.mbtx
moon check --target native
moon fmt --check
moon info --target native
```

This demonstrates selected behavior, not complete RFC compliance, platform
certification or production throughput. CI runs a selected subset as requested.
