# 0.2.3 continuation — 2026-11-13

## Implemented

PageReader opens an exclusively locked job, validates its index, checkpoint shards
and contiguous journal, then keeps canonical page identities and record positions.
It loads bodies only when requested or visited. CLI export uses this path and emits
only the latest upsert of each page. It skips task-only/superseded records on the
second pass. Traversal is linear in records plus pages; metadata is still proportional
to tasks/pages/records. Each decoded record is bounded by the existing 16 MiB limit.

The ordinary full-snapshot recovery path uses the same scan/validation function,
retaining pages during its single pass. It does not reread all records twice. Engine
resume and execution still materialize Page maps. Legacy monolithic snapshots migrate
once through the existing <=64 MiB compatibility path. Reader export refuses overwrite
and reserved job filenames, synchronizes output, and may leave a partial output after
a write failure. Pause or stop a writer before exporting: reader consistency uses the
existing exclusive job lock. Job directories remain trusted local directories.

The controlled DNS fixture now exchanges real UDP question/answer packets, with A
records and TTL=0, before invoking curl on a local HTTP service. The first answer
allows the local development connection; a redirect causes a fresh DNS query whose
metadata-service address is rejected before connection. Additional wire tests reject
mixed public/private answers, mismatched transaction IDs and NXDOMAIN. The minimal
fixture resolver is test-only. It does not replace SystemResolver or certify OS caches,
public DNS infrastructure, CNAME, IPv6, DNSSEC or a malicious transport adapter.

Atomic record writes use an exclusive randomized staging file, split byte writes,
file sync, close and same-directory rename. Diagnostic hooks allow an external
controller to forcibly kill the process after partial/staged/published event, shard
or index writes, and before/during old-record cleanup: eleven stages in total.
Each fixture reopens the job and verifies task/Page consistency. Published records
may survive an unacknowledged call; this remains at-least-once behavior. No parent
directory power-loss guarantee is added; SIGKILL/TerminateProcess is not a power cut.

## Reproducible evidence

[Test report and raw logs](../evidence/2026-11-13-0.2.3/README.md),
[storage memory comparison](../evidence/2026-11-13-0.2.3/storage-profile.json),
[crash stages](../evidence/2026-11-13-0.2.3/crash.json).

```sh
moon run tools/publish_evidence.mbtx 2026-11-13-0.2.3
```

The storage probe generates a checkpoint containing 65 pages, each with 1 MiB text.
Fresh native debug child processes separately perform full restore plus record-wise
export, and catalog-based export. The controller records OS working-set counters
after each export and checks both outputs incrementally as 65 JSONL records.
Memory counters include runtime/decoding buffers, exclude the generation/controller
process, and depend on OS/allocator/filesystem. Windows records PeakWorkingSet64,
Linux VmHWM, macOS sampled RSS only. No universal memory or throughput claim follows.

Automatic focused CI now has independent Windows, Ubuntu and macOS jobs and uploads
separate platform artifacts, including failure logs. Configuration alone is not a
passing result: consult the actual Actions run. Full tests remain manual and disabled
unless explicitly selected. This continuation did not request a full suite.

## Remaining boundaries

- Engine-wide lazy body retention/streaming resume is still future work.
- Full test, complete cross-platform security and release certification remain open.
- Upstream DOM construction still lacks an allocation budget/cancellation API.
- Power-cut/disk-controller fault simulation and coverage-guided fuzzing remain open.
- IPv6, non-UTF-8 decoding, distributed workers and browser rendering remain extensions.

Existing 0.2.2 evidence remains unchanged; 0.2.3 uses a distinct evidence directory.
