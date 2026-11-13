# Supported scope and remaining work

This is a working 0.2.3 static crawler, not a completed 1.0 certification.
P0/P1 modules have executable implementations; broader acceptance, portability
and performance verification remain release gates.

| Area | Implemented profile / limit |
| --- | --- |
| Runtime | native; Windows 2022, Ubuntu 24.04 and macOS 15 focused checks passed with archived evidence; full certification remains pending |
| URL | ASCII HTTP(S), punycode IDNs, IPv4/DNS, 8192 code units; query retained by default |
| Normalization | host/scheme case, default ports, fragments, dot segments, unreserved escapes; preserves query order and reserved escapes |
| Network | public IPv4, ports 80/443; private, metadata, loopback, special-use and ambiguous numeric forms blocked |
| Development | explicit `allow_loopback` permits loopback and nonstandard localhost/127.0.0.1 ports; private LAN stays blocked |
| HTTP | GET/HEAD, safe optional headers, TLS verification enabled, gzip/deflate if curl supports them, bounded output, explicit redirects; Engine rejects unsolicited 304 |
| Encoding | UTF-8/ASCII; declared GBK or unsupported charset fails explicitly; no lossy decoding |
| Robots | product-token groups, merged groups, Allow/Disallow, wildcard/end anchor, UTF-8 octets, Sitemap declarations, origin TTL cache |
| Robots failures | 4xx except 429 allow; network/429/5xx fail closed with bounded task retries; cooldown >=5 minutes and honors Retry-After up to 24h; valid rule denies are terminal |
| Robots extensions | Crawl-delay ignored; configure host delay. Percent-encoded wildcard matching is conservative |
| HTML | upstream HTML5 DOM; title, text, metadata, canonical/base, images/links; rel tokens use ASCII whitespace and case folding; no JS execution or CSS selector API |
| Resource bounds | body default 2 MiB; parser 512K UTF-16 units, 4096 '<' preflight, 100K nodes after construction, 10K links/images each; retained page/metadata serialized defaults 128/16 MiB, not RSS limits |
| Frontier | default 1000 discovered tasks total, including terminal states; rejects excess discovery as backpressure |
| Scheduler | worker and host slots, request-start spacing including Robots/redirects; host limits enable multi-site progress |
| Storage | locked trusted directory; incremental batches and segmented checkpoints; 16 MiB per record; aggregate above 64 MiB tested |
| Export | CLI scans bounded records into a latest-page catalog, then writes bodies one record at a time under a job lock; Engine resume still retains pages; failed output may be partial |
| Resume | successes retained, interrupted workers retry; host cooldown/Robots cache restart from configuration |
| Cookie/proxy | disabled by default; custom adapters can implement explicit sessions with equivalent safety |
| Monitoring | persisted states, attempts, errors, save time; CLI page/state counters; no metrics server/tracing exporter |

The upstream HTML parser has no preallocation/node budget or cancellation hook.
Input is bounded, but pathological HTML needs further fuzzing and profiling.
Jobs remain in memory during execution/recovery. The 100K task ceiling is a bound,
not a measured throughput or memory guarantee. See [audit status](audit-upgrade.md).
The 10K distinct-host model confirms O(nonempty hosts) candidate scanning per claim;
it does not establish 100K real-page throughput. Resolver adapters can return complete
address sets; SystemResolver still exposes only the native selected IPv4 address.

## Deferred release gates

- Complete platform/TLS certification, system-resolver/public-DNS cache coverage.
- GBK decoder, optional cookie sessions and proxy adapters.
- Metrics/logging exporters, coverage-guided HTML fuzzing and real-page throughput.
- Directory metadata power-loss durability and additional platform crash fixtures.
- Mooncakes publication and signed release artifacts.

See [0.2.3 evidence](../evidence/2026-11-13-0.2.3/README.md) for selected tests,
eleven forced-termination stages, UDP DNS fixtures and per-process memory comparisons.

P2: XML Sitemap crawling (declarations already extracted), conditional/incremental
recrawl, PDF, external browser execution and distributed workers.
