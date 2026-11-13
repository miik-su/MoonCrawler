# Changelog

## 0.2.2

- Retry temporary Robots outages with persisted bounded cooldowns, separately from rule denies.
- Match HTML rel tokens using ASCII whitespace and reject unsolicited 304 even with saved pages.
- Stream JSONL records to exclusive output files; retain current in-memory recovery scope.
- Validate complete injected resolver answer sets and exercise actual curl IP pinning locally.
- Record 10K-host scan counts, four parser working-set profiles and five forced-kill recovery stages.
- Publish dated evidence and cross-platform artifacts; update version and dependency inventory.

## 0.2.1

- Validate page identity and aggregate budgets before journal writes; enforce adapter contracts.
- Group Frontier heaps by host and publish a reproducible 100K blocked-host model.
- Bound Robots rule/matching/cache resources and explicitly maintain FIFO order.
- Pack page checkpoint shards by byte budget and support obsolete HTTP date formats.
- Add typed resolver errors, safe missing-job CLI behavior and HTML structural preflight.
- Publish machine-readable test results/raw logs and pin CI Actions/bootstrap digests.

## 0.2.0

- Default-deny crawl scope, explicit UnsafeFetcher trust boundary and actual peer checks.
- Per-hop policy enforcement, persistent Retry-After continuations and uncached 304 rejection.
- Bounded Robots cache, per-origin flights, independent limits and host admission.
- Epoch persistence, versioned config migration and separate skipped/blocked states.
- Incremental checksummed journal, segmented compaction and bounded filesystem reads.
- Security/contribution/use policies and focused adversarial regression fixtures.
- See docs/audit-upgrade.md for evidence and remaining release-certification gates.

## 0.1.0 — 2026-11-08

Initial staged implementation from the MoonCrawler design conversation:

- Modular MoonBit core, URL normalization and bounded configuration.
- Deduplicated priority/delay heaps, fenced leases, attempts and crash recovery.
- Domain/global concurrency, cooldown, Retry-After and Robots caching/rules.
- DNS-pinned curl transport with SSRF, redirect, timeout and resource policy.
- MoonBit HTML5 extraction, pluggable processors and adapters.
- Atomic locked file snapshots, in-memory storage and JSONL export.
- crawl/resume/pause/status/stats/init/validate/export CLI and offline example.
- Focused unit, real HTTP, storage failure and 10K-task verification; selected CI.

See [compatibility](docs/compatibility.md) for remaining 1.0 release gates.
