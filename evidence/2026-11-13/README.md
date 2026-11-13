# Focused test evidence — 2026-11-13

Tested source: `cdeeecbbce92b346721d5f4bd018d840d15c49a2`

Full suite: **not run**. Runner: Windows. Selected project tests use native; orchestration uses MoonBit script mode. Results describe fixtures, not security certification.

| Group | Exit | Elapsed ms | Raw log |
| --- | ---: | ---: | --- |
| contracts | 0 | 211 | [log](contracts.log) |
| resources | 0 | 67024 | [log](resources.log) |
| queue | 0 | 1101 | [log](queue.log) |
| protocol | 0 | 329 | [log](protocol.log) |
| persistence | 0 | 196 | [log](persistence.log) |
| review-protocol | 0 | 1351 | [log](review-protocol.log) |
| review-network | 0 | 152 | [log](review-network.log) |
| review-scale | 0 | 252 | [log](review-scale.log) |

[Machine-readable results](results.json) · [Queue models](model.json) · [CLI log](cli.log) · [Forced process termination](crash.json) · [Parser resource profile](parser-profile.json)

Queue inputs: 99,999 `https://a.example/{i}` tasks plus one `https://b.example/` task; separately 10,000 distinct `h{i}.example` hosts. No public network access. Candidate checks and wall duration are measured, not CPU time. Per-claim host scanning remains linear. The 65 MiB persistence test is an aggregate round-trip, not constant-memory operation.

The parser profile uses a fresh native debug process for each fixture: 2,000 nested divs; 600 malformed formatting groups; a 500,000-unit attribute; 60,000 entities. OS counters include input generation and runtime. Windows records PeakWorkingSet64, Linux VmHWM, macOS only a sampled RSS (not peak). These measurements do not establish a hard DOM allocation bound. A 30-second controller timeout stops stalled fixtures.

Crash fixtures force SIGKILL/TerminateProcess at five publication boundaries; this is not a power-cut or disk-cache-loss test. Network fixtures use an injected resolver with actual loopback curl plus mixed-answer checks; authoritative DNS/TTL rebinding remains a separate release gate.
