# Focused test evidence — 2026-11-13-0.2.3

Tested source: `76a44fea4e44751b000878a38a8b0b7da54af964`

Full suite: **not run**. Runner: macOS. Selected project tests use native; orchestration uses MoonBit script mode. Results describe fixtures, not security certification.

| Group | Exit | Elapsed ms | Raw log |
| --- | ---: | ---: | --- |
| contracts | 0 | 2658 | [log](contracts.log) |
| resources | 0 | 32201 | [log](resources.log) |
| queue | 0 | 1220 | [log](queue.log) |
| protocol | 0 | 1485 | [log](protocol.log) |
| persistence | 0 | 75 | [log](persistence.log) |
| review-protocol | 0 | 1766 | [log](review-protocol.log) |
| review-network | 0 | 158 | [log](review-network.log) |
| review-scale | 0 | 133 | [log](review-scale.log) |
| archive | 0 | 79 | [log](archive.log) |
| wire-dns | 0 | 85 | [log](wire-dns.log) |

[Machine-readable results](results.json) · [Queue models](model.json) · [CLI log](cli.log) · [Forced process termination](crash.json) · [Parser resource profile](parser-profile.json) · [Storage memory comparison](storage-profile.json)

Queue inputs: 99,999 `https://a.example/{i}` tasks plus one `https://b.example/` task; separately 10,000 distinct `h{i}.example` hosts. No public network access. Candidate checks and wall duration are measured, not CPU time. Per-claim host scanning remains linear. The 65 MiB persistence test is an aggregate round-trip, not constant-memory operation.

The parser profile uses a fresh native debug process for each fixture: 2,000 nested divs; 600 malformed formatting groups; a 500,000-unit attribute; 60,000 entities. Counters include runtime/input generation; Windows records PeakWorkingSet64, Linux VmHWM, macOS only sampled RSS (not peak). A 30-second controller timeout stops stalled fixtures; these are not hard DOM allocation bounds.

The storage profile creates one 65-page checkpoint with exactly 1 MiB text per page, then runs full snapshot restoration/export and catalog streaming export in separate fresh native debug processes. It measures product-process working sets including runtime and buffers, not controller/generation memory. Both outputs are read incrementally and checked as 65 valid JSONL records. Throughput is fixture/filesystem dependent; this is not a production memory guarantee.

Crash fixtures force SIGKILL/TerminateProcess at eleven stages, including partial event/shard/index writes and cleanup midway. This is not a power-cut or disk-cache-loss test. DNS fixtures exchange actual UDP A responses with TTL=0 and use real loopback HTTP/curl: a redirect triggers a new query and a dangerous answer is rejected. Mixed answers, transaction-ID mismatch and NXDOMAIN are checked. The fixture resolver is test-only; OS resolver caches, public authoritative infrastructure, CNAME and DNSSEC are not certified.
