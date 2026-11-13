# Configuration

`init CONFIG.json` writes schema version 2. `core.decode_config` migrates known
0.1 keys without implicitly allowing arbitrary hosts. Missing unrelated required fields
are errors. `validate` checks bounds before network activity. Use the saved config
when resuming. No credentials are saved by the bundled adapter.

| Field | Default | Meaning |
| --- | --- | --- |
| max_depth | 3 | seed depth 0; accepted range 0..100 |
| max_pages | 1000 | total discovered task budget, 1..100,000 |
| concurrency | 4 | async workers, 1..128 |
| per_host | 1 | simultaneous requests per host, 1..concurrency |
| delay_ms | 1000 | minimum request-start interval per host, 0..60000ms |
| timeout_ms | 15000 | whole-hop deadline, up to 300000ms |
| max_body_bytes | 2097152 | decompressed body limit, up to 16 MiB |
| max_header_bytes | 65536 | total header limit, up to 1 MiB |
| max_redirects | 5 | page redirect chain, 0..20 |
| max_robots_redirects | 5 | independent Robots redirect chain, 5..20 |
| max_robots_bytes | 1048576 | independent Robots body budget, 512000..16777216 |
| robots_cache_capacity | 256 | bounded Origin cache, 1..10000; expired entries removed first |
| max_total_page_bytes | 134217728 | aggregate serialized UTF-8 pages, up to 1 GiB |
| max_total_metadata_bytes | 16777216 | aggregate serialized metadata, no larger than the page budget |
| max_attempts | 3 | total attempts including first, 1..10 |
| lease_ms | 120000 | Frontier library deadline; Engine uses restart recovery, not runtime lease stealing |
| user_agent | MoonCrawler/0.2.2 | crawler product token/version, no CR/LF; saved/custom values remain unchanged |
| allowed_hosts | [] | exact normalized hostname allowlist; empty is rejected by default |
| allow_any_public_host | false | explicit opt-in to open public crawling when allowlist is empty |
| schema_version | 2 | known legacy keys migrated; unsupported versions rejected |
| denied_paths | [] | case-sensitive URL path prefixes |
| denied_extensions | .pdf,.zip,.png,.jpg,.js,.css | case-insensitive path suffixes |
| include_query | true | query participates in dedup; false deliberately merges query variants |
| robots | true | fetch and enforce origin Robots rules |
| allow_loopback | false | explicit local fixture development; private LAN remains blocked |

The engine always applies hostname/IP/redirect safety. Disabling Robots does not
disable security. IP pinning avoids a second DNS lookup at connect time.
Cross-host redirects require the target to satisfy allowed_hosts and Robots too.
Keep discovered host scope small for predictable memory and runtime.

`max_pages` limits all tasks, including failed or blocked URLs, rather than promising
that many successful pages. Rejected links are skipped. Snapshot and parser bounds
apply independently. Default file storage is intended for bounded single-process jobs.

`pause JOBDIR` writes a cooperative stop marker. It is a request, not immediate
termination; current network calls may finish. Scheduling waits check the stop marker,
release admission and requeue their task. Delayed redirects are already durable.
`resume JOBDIR` clears that marker while holding the exclusive job lock.

Errors in a page are persisted in its Task and may produce a terminal failure while
the job continues. Invalid configuration, seed safety failures and storage failures
cause command failure. status/stats shows saved states, not a live process health probe.
