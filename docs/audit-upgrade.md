# 0.2 audit remediation

This record tracks the 0.2 security review and four-round remediation plan.
It separates code changes and observed tests from release certification.

## P0 changes

| Finding | Remediation | Evidence |
| --- | --- | --- |
| Empty scope silently open | Default validation fails; exact allowed_hosts or explicit allow_any_public_host required | core/scope_test.mbt |
| Redirect policy bypass | Every page hop reapplies path, suffix, depth, hostname and security policy | engine/policy_test.mbt |
| Third-party Fetcher mistaken for safe | Public extension renamed UnsafeFetcher; bundled curl pins checked IPv4 and verifies reported remote_ip | fetcher/network_test.mbt; documented trust boundary |
| Full snapshot per task | Frontier tracks dirty tasks; Engine commits changed claims and atomic completion/page/discovery batches | storage/journal_test.mbt; engine/failure_test.mbt |
| 64 MiB aggregate failure | Segmented checkpoints, bounded records; 130 pages totaling 65 MiB round-trip | storage/capacity_test.mbt |
| Ambiguous time basis | Persisted ready_at/saved_at and HTTP dates explicitly use clock.epoch_ms; process waits/Robots use opaque timer | frontier/redirect_test.mbt; retry/retry_test.mbt |
| Reboot loses redirect delay | Target, hop count and epoch due time persist as a continuation, without consuming another retry | frontier/redirect_test.mbt |

The locked async 0.22.5 native implementation currently returns epoch time from
async.now. The review's portability warning is valid; it was not reproduced as a
native 0.22.5 clock-reset failure. Explicit clock roles avoid treating that detail
as a stable cross-version contract. Runtime timeouts remain owned by async.

## P1 changes

- Named IPv4 CIDR exclusion table and IPv6/alternate-literal boundary tests.
- Header token/control validation, sensitive duplicates and conflicting framing
  rejection, explicit 101 rejection; non-sensitive list values joined, cookies discarded.
- 304 requires an existing representation. 204 remains an empty success.
- Page redirect Retry-After becomes a durable delayed continuation; enormous
  delta-seconds saturate to one day. Robots redirect/429 cooldown is also enforced.
- Independent Robots budget >=500 KiB and redirect count >=5; bounded TTL/FIFO
  origin cache, per-origin single-flight with counted waiters.
- Per-host admission is reserved in the non-suspending claim path, before persistence
  and Robots. Redirect continuations release initial-host admission before rescheduling.
- Scheduling waits check cooperative stop; paused tasks requeue without consuming
  a completed attempt. Policy skips and Robots blocks have separate terminal states.
- Single-process restart recovery chosen as the review's scheme A. Engine does not
  run lease stealing, heartbeat or expiry scanners. Frontier's standalone fencing API
  remains available to library consumers.
- Private job directories, rejection of nonregular lock paths, random exclusive
  temporary files, bounded handle reads, checksummed immutable journal records.

## Persistence protocol and limits

Each event file is one transactional batch with sequence, job ID, changed tasks,
page upserts and epoch timestamp. FNV-1a detects accidental corruption; it is not
authentication against a malicious local user. A record is file-synced and atomically
published before success is reported. Partial staging files never replay; truncated,
misidentified or sequence-gapped published records fail closed.

Every 100 nonempty engine commits (roughly 50 ordinary page attempts), checkpoint
shards are created and synced before the index is replaced. Only then are superseded
events/shards reclaimed. Concurrent status readers retry once from the new index.
Old events already covered by the index are not applied twice. Recovery builds maps
in one pass, rather than rebuilding Frontier for every validation or record.

16 MiB per-record/index read limits remain. The configuration ceiling is 100K tasks,
and all job data still resides in memory: this is not a constant-memory crawler.
Whole-job rewrites still happen at compaction, not per task. Custom Storage defaults
to snapshot merging unless it overrides commit_batch.

Directories must belong to and be writable only by the trusted OS account. The
portable async API does not expose atomic no-follow opens/ownership verification
or parent-directory fsync. Symbol-link races against an attacker who can modify the
directory and power-loss durability of directory metadata are therefore **not certified**.
Use an isolated private directory; do not share one with untrusted local writers.

## API and migration

Configuration schema is 2. CLI uses decode_config to fill only known newly added
keys. Legacy checkpoints with explicit allowed_hosts are upgraded under the writer
lock. Empty legacy scopes require an operator to supply an authorized scope first;
migration never silently grants open crawling. New task continuation fields default
to empty for legacy snapshots. Normal resume loads the job once under its lock.

UnsafeFetcher is intentionally a breaking API rename. Network adapters are trusted
code and can make arbitrary OS calls; an interface or token cannot sandbox malicious
MoonBit code. The default CLI always uses the checked curl implementation. A future
validated-target interface can further reduce accidental adapter mistakes, but is
not being represented as OS-level isolation here.

## Verification and remaining release gates

Focused Windows tests passed for scope, redirects, Header rejection, CIDR edges,
Robots five-hop/budget/cache/concurrency, WAL replay/compaction/corruption,
storage failure, aggregate >64 MiB, real HTTP/gzip expansion, and CLI resume/export.
The Unix-only untrusted-TLS fixture is configured for CI; async 0.22.5's Schannel
backend does not expose TLS server construction on Windows. It has not been claimed
as a local Windows TLS result.

Still separate from this code delivery: coverage-guided fuzz campaigns, 100K measured
benchmarks, controlled DNS rebinding infrastructure, forced-power-loss experiments,
verified Windows/Linux/macOS results, full-suite certification, decoder/metrics
exporter adapters, and a 1.0 release. No full test run was
performed. Manual release CI is provided but not automatically invoked.
