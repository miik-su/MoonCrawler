# Focused test evidence — 2026-11-10

Tested source: `f21e8818a38ed5b7a232dea37ddb674f79be1e52`

Full suite: **not run**. Runner: Windows. Selected project tests use native; orchestration uses MoonBit script mode. Results describe fixtures, not security certification.

| Group | Exit | Elapsed ms | Raw log |
| --- | ---: | ---: | --- |
| contracts | 0 | 1567 | [log](contracts.log) |
| resources | 0 | 43953 | [log](resources.log) |
| queue | 0 | 1252 | [log](queue.log) |
| protocol | 0 | 1324 | [log](protocol.log) |
| persistence | 0 | 182 | [log](persistence.log) |

[Machine-readable results](results.json) · [100K queue model](model.json) · [CLI log](cli.log)

Model inputs: 99,999 `https://a.example/{i}` tasks and one `https://b.example/` task. No public network access; this measures candidate checks and wall duration, not CPU time or peak memory. The 65 MiB persistence test measures an aggregate round-trip, not constant-memory operation.
