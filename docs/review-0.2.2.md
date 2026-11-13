# 0.2.2 follow-up — 2026-11-13

## Correctness changes

- Robots cache distinguishes temporary unreachability from parsed rule decisions.
  Network errors, 429, 5xx and unusable redirect responses fail closed and queue
  tasks for retry, bounded by max_attempts. Cooldown is at least five minutes,
  extended by Retry-After up to 24h. Exhaustion is a technical failure rather than
  BlockedByRobots. Epoch ready_at persists across restart; valid Disallow remains
  terminal. Cache limits and per-origin single-flight behavior are retained.
- HTML nofollow and canonical use case-insensitive token matching with exactly
  space, tab, LF, CR and form feed. NBSP remains part of a token.
- Engine sends no conditional request and rejects every 304, even with a saved
  Page. Direct CurlFetcher users may supply conditional headers, but Engine does
  not yet provide ETag/Last-Modified association or validator-aware recrawling.
- export_jsonl takes an iterator and writes/syncs one record at a time. CLI uses
  it and refuses overwrite. A failed write can leave a partial export. Recovery
  still loads a complete snapshot; lazy body reads and streaming recovery remain
  future architecture work. The legacy jsonl convenience function still exists.
- Default User-Agent and CLI banner match 0.2.2. Existing/custom configuration
  identifiers are preserved; Robots uses the product token before '/'.
- Page validation checks persisted identity/scope/payload, not DNS/IP authorization.
  Every connection must separately pass network policy and address validation.

## Evidence and interpretation

[Recorded run](../evidence/2026-11-13/README.md) contains source SHA, commands,
exit codes, raw logs and machine-readable models. Reproduce:

```sh
moon run tools/publish_evidence.mbtx 2026-11-13
```

The 10K-host fixture documents linear scanning per claim; the 100K-task fixture
documents concentration on one blocked host. Neither is a 100K real-page crawl.

Four fresh native debug parser processes exercise 2,000 nested divs, 600 malformed
formatting groups, a 500,000-code-unit attribute and 60,000 entities. Windows uses
PeakWorkingSet64; Linux uses VmHWM; macOS records sampled RSS only. Counters include
runtime and input generation. The controller kills stalled children after 30s.
These observations do not impose construction-time DOM limits. Upstream HTML 0.2.4
does not expose allocation/cancellation budgets; comprehensive peak-resource bounds
and coverage-guided fuzzing remain open.

Resolver.resolve_all lets capable adapters supply answer sets; any dangerous address
rejects the set before transport. A controlled changing resolver plus an actual
loopback HTTP/curl connection verifies one-resolution pinning and the next-hop
private-address rejection. This is not a wire-level authoritative DNS/TTL rebinding
experiment. SystemResolver exposes one selected IPv4 address, not the full RRset.

The crash tool forcibly terminates a native writer via SIGKILL/TerminateProcess
after event staging, event publication, checkpoint staging, checkpoint publication
and before old-record cleanup. Recovery checks task/Page consistency and successful
lock reacquisition. Staged-but-unpublished events are absent; published events replay.
Publication may survive a lost caller acknowledgement, matching at-least-once behavior.
FileStore's optional diagnostic probe must not mutate the job or be used for business
logic; errors after publication have an ambiguous commit outcome.
This does not simulate disk-controller cache loss, filesystem damage or power loss.

## Release status

Full tests were not requested and were not run. The manual workflow can run focused
checks and optional full_suite on Windows, Ubuntu and macOS, uploading platform
evidence separately. A configured workflow is not a completed certification.

Native static HTML, public IPv4 and UTF-8/ASCII remain the supported profile.
IPv6, GBK, browser rendering, distributed workers and large-job lazy recovery are
future extensions. No AI model weights are included: the queue models are synthetic
test fixtures. See [dependency inventory](dependency-licenses.md) for observed
versions, license evidence and outstanding release packaging review.
