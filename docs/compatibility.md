# Supported scope and remaining work

This is a working 0.1 static crawler, not a completed 1.0 certification.
P0/P1 modules have executable implementations; broader acceptance, portability
and performance verification remain release gates.

| Area | Implemented profile / limit |
| --- | --- |
| Runtime | native, verified Windows; Ubuntu CI configured |
| URL | ASCII HTTP(S), punycode IDNs, IPv4/DNS, 8192 code units; query retained by default |
| Normalization | host/scheme case, default ports, fragments, dot segments, unreserved escapes; preserves query order and reserved escapes |
| Network | public IPv4, ports 80/443; private, metadata, loopback, special-use and ambiguous numeric forms blocked |
| Development | explicit `allow_loopback` permits loopback and nonstandard localhost/127.0.0.1 ports; private LAN stays blocked |
| HTTP | GET/HEAD, safe optional headers, verified TLS, gzip/deflate if curl supports them, bounded output, explicit redirects |
| Encoding | UTF-8/ASCII; declared GBK or unsupported charset fails explicitly; no lossy decoding |
| Robots | product-token groups, merged groups, Allow/Disallow, wildcard/end anchor, UTF-8 octets, Sitemap declarations, origin TTL cache |
| Robots failures | 4xx except 429 allow; network/429/5xx fail closed for five minutes; denied tasks terminal in this run |
| Robots extensions | Crawl-delay ignored; configure host delay. Percent-encoded wildcard matching is conservative |
| HTML | upstream HTML5 DOM; title, text, metadata, canonical/base, images/links; no JS execution or CSS selector API |
| Resource bounds | body default 2 MiB; parser 512K UTF-16 units, 100K nodes after construction, 10K links/images each |
| Frontier | default 1000 discovered tasks total, including terminal states; rejects excess discovery as backpressure |
| Scheduler | worker and host slots, request-start spacing including Robots/redirects; host limits enable multi-site progress |
| Storage | single locked directory; whole-job snapshot <=64 MiB; larger jobs need custom transactional storage |
| Resume | successes retained, interrupted workers retry; host cooldown/Robots cache restart from configuration |
| Cookie/proxy | disabled by default; custom adapters can implement explicit sessions with equivalent safety |
| Monitoring | persisted states, attempts, errors, save time; CLI page/state counters; no metrics server/tracing exporter |

The upstream HTML parser has no preallocation/node budget or cancellation hook.
Input is bounded, but pathological HTML needs further fuzzing and profiling.
Whole-job snapshots favor correctness and a simple 0.1 format, not million-page crawls.

## Deferred release gates

- Multi-OS HTTPS certificate-failure/rebinding fixtures.
- GBK decoder, optional cookie sessions and proxy adapters.
- Metrics/logging exporters, HTML fuzz corpus and 100K-task benchmarks.
- Directory metadata crash durability and incremental storage.
- Mooncakes publication and signed release artifacts.

P2: XML Sitemap crawling (declarations already extracted), conditional/incremental
recrawl, PDF, external browser execution and distributed workers.
