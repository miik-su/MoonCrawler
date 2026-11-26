# Focused verification

## Coverage feedback and virtual power cut

`moon run tools/coverage_guided.mbtx` builds an instrumented native child and
runs a small offline campaign against URL, Robots, HTTP decoding, HTML and
Sitemap. Only new nonzero compiler counter slots promote mutations into the
parent corpus. It reports counts before and after mutation, successful reuse
of retained inputs, and unexpected subprocess failures. Malformed inputs
rejected by a parser are normal outcomes. Counter totals are not a percentage
of branch coverage, and ASCII mutations do not cover all encodings or DOM inputs.

`moon run tools/power_cut.mbtx` runs in an isolated Linux QEMU environment
with a fresh raw ext4 disk image for each stage. The writer signals the host over
serial. The host kills the whole VM process, then boots a new VM on the same disk
and checks task/page recovery. The guest has no network or host-mounted directories.
Compilation and tests run only on the configured targets; no full suite or
registry publication is invoked by this workflow.
[Specialized CI](https://github.com/miik-su/MoonCrawler/actions/workflows/specialized.yml)
· [Archived results and boundary](../evidence/2026-11-26-specialized/README.md)

A successful virtual test concerns the guest kernel, ext4 and the selected QEMU
block options. It does not reproduce power removal from physical disks, controller
cache loss, dishonest flush acknowledgments, Windows/macOS or other filesystems.
The fixture creates and flushes an initial job on an existing mounted directory.

## Current maintenance checks

The [0.3.0 maintenance model and focused evidence](https://github.com/miik-su/MoonCrawler/tree/main/evidence/2026-11-26-0.3.0)
cover the Sitemap and selector profile, conditional CLI round trip, streamed
compaction interruption, HTML fixtures and separate-process restore comparison.
See the [2026-11-20 historical maintenance evidence](../evidence/2026-11-20-maintenance/README.md).
The [focused workflow](https://github.com/miik-su/MoonCrawler/actions/workflows/focused.yml)
records source SHA and target platform in artifacts under `_build/readiness`.
Run `moon run tools/readiness_evidence.mbtx` from the checkout to reproduce
the compiler, formatting, API, transport, parser and archive checks. The
workflow additionally checks selected queue, policy, storage and CLI paths.
The parser group includes media types and structure budgets; the deterministic
mutation group covers URL, Robots, response headers, Sitemap and HTML.

Model commands (local processes and synthetic data):

```sh
moon run tools/storage_profile.mbtx -- restore
moon run tools/parser_profile.mbtx
moon run tools/crash_probe.mbtx
```

The saved 65 MiB storage and 100K-task models use synthetic inputs. Their
reports retain the measured source, workload, platform and limits. A current
focused pass validates selected behavior and does not remeasure their capacity.

## Current preparation checks (2026-11-14)

See [readiness results](../evidence/2026-11-14-readiness/README.md).
Reproduce with `moon run tools/readiness_evidence.mbtx`: Native warning-denial,
format/interface checks, the affected fetcher files and local package extraction
with an offline example. It never publishes or changes registry authentication.
Automatic focused CI records these checks independently on its three platforms;
historical performance evidence is retained below without relabelling its source.
The manual release workflow still supports explicitly requested broader validation.
The Unix certificate fixture uses an openssl subprocess and requires curl exit 60;
it no longer calls an upstream TLS-server API marked internal. Initial strict CI
at `79e599f` exposed that fixture dependency. The corrected `aceb4f2` passed on
all three platforms; [raw results and artifact hashes](../evidence/2026-11-14-readiness/platforms/README.md)
preserve the exact source revision. Windows has no TLS-server fixture claim.

## Runtime baseline: 0.2.3 (2026-11-13)

See [new evidence](../evidence/2026-11-13-0.2.3/README.md) for ten focused groups,
actual UDP DNS A records with TTL=0 and a real curl/HTTP redirect, eleven forced
process-kill stages and a 65 MiB full-restore versus catalog-export comparison.
Reproduce from the historical source recorded in that report using
`moon run tools/publish_evidence.mbtx 2026-11-13-0.2.3`.
The automatic focused workflow now targets all three operating systems. Its
platform results/artifacts are authoritative for what actually ran; no full suite
was requested or invoked. macOS memory values are sampled RSS rather than peaks.
The [completed matrix run](https://github.com/miik-su/MoonCrawler/actions/runs/43421224981)
passed on Windows 2022, Ubuntu 24.04 and macOS 15 at source `76a44fe`.
[Permanent platform logs and JSON](../evidence/2026-11-13-0.2.3/platforms/README.md)
include the original artifact ZIP digests, source identity and measured results.

## Historical: 0.2.2 (2026-11-13)

See [recorded results and raw logs](../evidence/2026-11-13/README.md) and
[remediation boundaries](review-0.2.2.md). New selected fixtures cover Robots
temporary failures/restart, ASCII rel tokens, unsolicited cached 304 rejection,
streaming JSONL, injected DNS answers with actual loopback curl, 10K hosts,
forced process termination and fresh-process parser working-set profiles.
Reproduce using `moon run tools/publish_evidence.mbtx 2026-11-13`.
Full suite and three-platform workflow remain manual and were not invoked for
this run, following the requested focused-test scope.

## Historical: 2026-11-08

MoonBit `0.10.17+d971670cd`, moon `0.1.20261023`, Windows native, curl `8.21.0`.
Only selected tests ran; no unfiltered `moon test` or full dependency suite.

## 0.2 audit regressions

See [remediation evidence](audit-upgrade.md). The final selected regression run
passed 18 tests across affected scope, migration, queue, retry, engine, HTTP,
journal and deterministic mutation files. Separate capacity, identity/gap,
filesystem, cache and gzip tests also passed. The 65 MiB segmented checkpoint
round-trip passed; it is not a throughput benchmark. CLI smoke passed with the
new default-deny configuration and journal recovery.

Full suite and three-platform checks are available only through the manual release
workflow. They were not invoked. The TLS server fixture is Unix-only and remains
a CI verification gate. The bounded mutation corpus is not a coverage-guided fuzz campaign.

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
