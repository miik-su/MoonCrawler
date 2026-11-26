# Supported scope and remaining work

This describes the 0.3.0 development source profile.
P0/P1 modules have executable implementations; broader acceptance, portability
and performance verification remain release gates.

| Area | Implemented profile / limit |
| --- | --- |
| Runtime | native; Windows 2022, Ubuntu 24.04 and macOS 15 focused checks passed with archived evidence; full certification remains pending |
| URL | ASCII HTTP(S), punycode IDNs, IPv4/DNS, 8192 code units; query retained by default |
| Normalization | host/scheme case, default ports, fragments, dot segments, unreserved escapes; preserves query order and reserved escapes |
| Network | public IPv4, ports 80/443; private, metadata, loopback, special-use and ambiguous numeric forms blocked |
| Development | explicit `allow_loopback` permits loopback and nonstandard localhost/127.0.0.1 ports; private LAN stays blocked |
| HTTP | GET/HEAD, safe optional headers, TLS verification, bounded curl decompression and explicit redirects; conditional recrawl accepts 304 only after sending validators for the exact cached URL |
| Encoding | UTF-8/ASCII; declared GBK or unsupported charset fails explicitly; no lossy decoding |
| Robots | product-token groups, merged groups, Allow/Disallow, wildcard/end anchor, UTF-8 octets, Sitemap declarations, origin TTL cache |
| Sitemap | opt-in URL set and index; unprefixed XML with standard namespace and predefined entities; same-origin URLs, directory-scoped page locations, standard crawl policy and record/document budgets |
| Robots failures | 4xx except 429 allow; network/429/5xx fail closed with bounded task retries; cooldown >=5 minutes and honors Retry-After up to 24h; valid rule denies are terminal |
| Robots extensions | Crawl-delay ignored; configure host delay. Percent-encoded wildcard matching is conservative |
| HTML | Exact `text/html` or `application/xhtml+xml` (case-insensitive, parameters excluded); both use HTML5 DOM. Optional tag/class/ID/attribute-presence extraction by API |
| Resource bounds | body default 2 MiB; parser 512K UTF-16 units, 4096 '<' preflight, 100K nodes after construction, 10K links/images each; retained page/metadata serialized defaults 128/16 MiB, not RSS limits |
| Frontier | default 1000 discovered tasks total, including terminal states; rejects excess discovery as backpressure |
| Scheduler | worker and host slots, request-start spacing including Robots/redirects; host limits enable multi-site progress |
| Storage | locked trusted directory; incremental batches and segmented checkpoints; 16 MiB per record; aggregate above 64 MiB tested |
| Export | CLI scans bounded records into a latest-page catalog, then writes one record at a time under a job lock; failed output may be partial |
| Streaming jobs | CLI uses `Engine::new_streaming`; checkpoint validation, restore and compaction retain records/bounded shard batches rather than every page. Older monolithic jobs migrate through the existing bounded load |
| Resume | successes retained, interrupted workers retry; host cooldown/Robots cache restart from configuration |
| Cookie/proxy | disabled by default; custom adapters can implement explicit sessions with equivalent safety |
| Monitoring | persisted states, attempts, errors, save time; in-process request/outcome/duration and page budget metrics via API and optional CLI JSON |

The upstream HTML parser has no preallocation/node budget or cancellation hook.
Input is bounded, but pathological HTML needs further fuzzing and profiling.
Task metadata remains in memory during execution and recovery; the default
library constructor also retains pages. The 100K task ceiling is a bound,
not a measured throughput or memory guarantee. See [audit status](https://github.com/miik-su/MoonCrawler/blob/main/docs/audit-upgrade.md).
The 10K distinct-host model confirms O(nonempty hosts) candidate scanning per claim;
it does not establish 100K real-page throughput. Resolver adapters can return complete
address sets; SystemResolver still exposes only the native selected IPv4 address.

## Deferred release gates

- Complete platform/TLS certification, system-resolver/public-DNS cache coverage.
- GBK decoder, optional cookie sessions and proxy adapters.
- Metrics/logging exporters, coverage-guided HTML fuzzing and real-page throughput.
- Directory metadata power-loss durability and additional platform crash fixtures.
- Mooncakes publication and signed release artifacts.

See [0.2.3 evidence](https://github.com/miik-su/MoonCrawler/blob/main/evidence/2026-11-13-0.2.3/README.md) for selected tests,
eleven forced-termination stages, UDP DNS fixtures and per-process memory comparisons.

Future scope includes PDF, external browser execution and distributed workers.
The current profile excludes JS execution, CSS combinators and XPath, full
XML schema validation, shared HTTP caching, CSV, and binary release attestation.
