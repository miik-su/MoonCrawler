# Architecture and extension contracts

`core` owns public models. Other public packages own their own types. URL,
Frontier, Scheduler, Robots, Parser and Storage can be imported independently.

```text
CLI / API -> Engine -> Frontier (URL index + priority heap + delayed heap)
                  -> Robots cache -> Scheduler -> Fetcher (one hop)
                  -> Parser -> Processor[] -> page upsert
                  -> Storage.commit_batch(changed tasks + pages) -> journal
                  -> periodic segmented checkpoint
```

The native runtime uses one async event loop. Frontier mutations do not suspend;
claim and state changes are atomic relative to async workers in that process.
These objects are not an OS-thread-safe or distributed queue.

## Reliability

`Pending -> Running -> Succeeded`, with bounded `RetryPending`,
`PermanentlyFailed`, and pending/retry cancellation. A generation token fences
late library completions. Engine uses single-process restart recovery, not runtime
lease preemption or renewal. Priority is highest-first; ties are
stable after activation. Separate priority/delayed heaps avoid full task scans
for ordinary dequeue. Ineligible hosts are skipped so other hosts can progress.

Retries preserve attempt counts. Network timeouts and selected curl transport
errors retry; security, malformed data, unsupported content and persistent HTTP
errors do not. 408/429/500/502/503/504 retry with capped exponential jitter.
Retry-After accepts delta seconds and IMF-fixdate, applies to the whole final
host, and is capped at one day.

Before network activity, changed claims are journaled. Page upsert, discovery and
completion happen without suspension and enter the same following journal batch.
FileStore publishes checksummed immutable batches with full file sync, exclusive
temporary creation and same-directory rename. Every 100 nonempty commits, a segmented
checkpoint is published before old records are reclaimed. Aggregate page data can
exceed 64 MiB; individual records are bounded to 16 MiB. Storage errors stop the crawl;
resume a new Engine after failure. Checksums detect accidental corruption, not malicious
edits. Job directories must be trusted and private to the operating-system user.

Interrupted running tasks resume as retry-pending, or terminal when attempts are
exhausted. Successful tasks remain completed. Requests are at-least-once; pages
are keyed by canonical final URL. A request may execute twice after a crash.
There is no claim of exactly-once networking or power-loss durability of directory metadata.

## Network boundaries

Before each page hop, the engine applies host policy, checks Robots for its
origin and acquires capacity. HTTPS downgrade, loops and excess redirects fail.
Robots redirects also apply network policy and scheduling without recursive Robots checks.

DNS resolution and IP classification occur in MoonBit. curl pins the selected
IPv4 using `--resolve`, retaining the original TLS/SNI hostname. Automatic
redirects, glob expansion, ambient proxies, credentials and curlrc are disabled.
Timeouts and output/decompressed-body limits bound each call. A custom Fetcher
must implement the same DNS/connect safety contract.

## Extension points

These `pub(open)` traits can be implemented in external MoonBit packages:

| Trait | Contract |
| --- | --- |
| `fetcher.UnsafeFetcher` | trusted adapter: URL + Config -> Response; caller owns its network security |
| `parser.Parser` | Response -> Page or checked error |
| `pipeline.Processor` | Page -> optional transformed Page; None rejects page and discovery |
| `storage.Storage` | save/load and commit_batch; generic fallback merges snapshots, FileStore writes incremental records |

`Engine::new` accepts UnsafeFetcher, Storage and optional Parser/Processor adapters.
See [offline example](../examples/offline/main.mbt) and generated `.mbti` signatures.
SQLite can implement Storage using an existing database transaction; GBK and other
formats can use decoding/Parser adapters. External browsers can later implement
Fetcher. No custom database or browser runtime is included.
