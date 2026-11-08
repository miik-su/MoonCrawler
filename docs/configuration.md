# Configuration

`init CONFIG.json` writes all required fields. Config is a strict, versioned-by-code
MoonBit record; unknown JSON keys are ignored by FromJson, missing required fields
are errors. `validate` checks bounds before network activity. Use the saved config
when resuming. No credentials are saved by the bundled adapter.

| Field | Default | Meaning |
| --- | --- | --- |
| max_depth | 3 | seed depth 0; accepted range 0..100 |
| max_pages | 1000 | total discovered task budget, 1..1,000,000 |
| concurrency | 4 | async workers, 1..128 |
| per_host | 1 | simultaneous requests per host, 1..concurrency |
| delay_ms | 1000 | minimum request-start interval per host |
| timeout_ms | 15000 | whole-hop deadline, up to 300000ms |
| max_body_bytes | 2097152 | decompressed body limit, up to 16 MiB |
| max_header_bytes | 65536 | total header limit, up to 1 MiB |
| max_redirects | 5 | each page/Robots redirect chain, 0..20 |
| max_attempts | 3 | total attempts including first, 1..10 |
| lease_ms | 120000 | lease duration; must exceed twice timeout_ms |
| user_agent | MoonCrawler/0.1 | crawler product token/version, no CR/LF |
| allowed_hosts | [] | exact normalized hostname allowlist; empty permits public destinations |
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
termination; current hops/retries finish their current task and then checkpoint.
`resume JOBDIR` clears that marker while holding the exclusive job lock.

Errors in a page are persisted in its Task and may produce a terminal failure while
the job continues. Invalid configuration, seed safety failures and storage failures
cause command failure. status/stats shows saved states, not a live process health probe.
