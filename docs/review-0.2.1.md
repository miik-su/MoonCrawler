# 0.2.1 review follow-up

## Implemented boundaries

1. `core.validate_page` checks canonical URL/scope/path/suffix, page and metadata
   sizes, and link/metadata counts before Engine insertion or journal publication.
   Batch duplicate identities are rejected; cross-batch upserts remain idempotent.
2. Processors cannot change response identity; one-hop adapters must return the
   requested URL. These contracts prevent accidental adapter errors, not malicious code.
3. Discovered links undergo static network policy before consuming task quota.
4. Robots fail closed above 4096 rules, 2048 code units per value, 256 groups,
   1024 agents, 128 Sitemaps, a 1 Mi-code-unit document or a conservative 2M matching
   work budget. Cache accounting caps retained rule text at 8 MiB; an explicit queue
   establishes FIFO replacement. Accounting is conservative, not a heap profiler.
5. Ready heaps are grouped by host. Only each host's best live candidate is checked;
   global priority is preserved across eligible heads. The `eligible` callback must
   express host-level admission, as Engine does. Delayed tasks retain a separate heap.
6. Default aggregate serialized pages/metadata budgets are 128 MiB/16 MiB, enforced
   by Engine and Storage, including recovery. This bounds retained data, not total
   RSS, DOM allocations, transient encoding buffers or runtime overhead.
7. Page checkpoints pack to a conservative 8 MiB encoded budget, at most 128 pages;
   the 16 MiB final record bound remains. This replaces one-file-per-page storage.
8. HTTP dates accept IMF-fixdate, RFC 850 (including the 50-year interpretation),
   and asctime. One-day clamping remains an application policy, not an RFC limit.
9. Resolver adapters distinguish Temporary, NotFound and Unknown. Unsafe addresses
   remain non-retryable security errors. Async 0.22.5 exposes only a platform-dependent
   string for native DNS failures, so SystemResolver marks them Unknown and Engine
   retries once. It does not pretend to reliably identify native NXDOMAIN vs EAI_AGAIN.
10. Missing resume checkpoints produce a checked CLI error, not an unwrap panic.
11. HTML rejects >4096 structural '<' characters before DOM construction. This is
    a conservative preflight, not a complete HTML complexity proof or CPU timeout.
12. Expired scheduler state is pruned periodically; idle active slots are removed.

## Published evidence

[Recorded run](../evidence/2026-11-10/README.md), [JSON results](../evidence/2026-11-10/results.json)
and [100K model output](../evidence/2026-11-10/model.json) include source identity,
commands, exits, wall duration, fixture model inputs and raw logs. Reproduce with:

```sh
moon run tools/publish_evidence.mbtx
```

The model uses 99,999 blocked high-priority tasks on one host and one eligible task
on another. It measures candidate-check counts and wall duration; CPU time and peak
memory are not measured. The fixed mutation corpus is not coverage-guided fuzzing.

## CI and remaining gates

External Actions are pinned to full commit IDs. Bootstrap downloads are SHA-256
checked against reviewed installer contents before execution. Installer updates fail
closed until the digest is reviewed. Toolchain version remains fixed; this is not
independent signature verification of every downloaded dependency or binary.
Automatic CI uploads raw evidence artifacts. Full suite and three-platform workflows
remain manual and were not invoked for this focused run.

Still not certified: controlled DNS rebinding, forced-power-loss durability, complete
cross-platform release results, coverage-guided fuzzing, peak-RSS limits and constant-
memory streaming recovery/export. Aggregate payload limits do not replace those gates.
