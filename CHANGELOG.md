# Changelog

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
