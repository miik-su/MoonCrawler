# Three-platform readiness evidence

Source: `aceb4f27b997cb9295666d94946d88cbd2f5afdb`.
[GitHub Actions run 43603862622](https://github.com/miik-su/MoonCrawler/actions/runs/43603862622)
completed successfully on all three platforms on 2026-11-14.

| Platform | Focused fetcher cases | Results | Package manifest |
| --- | ---: | --- | --- |
| Windows Server 2022 | 3 passed | [results](windows-2022/results.json) | [manifest](windows-2022/package.json) |
| macOS 15 | 4 passed | [results](macos-15/results.json) | [manifest](macos-15/package.json) |
| Ubuntu 24.04 | 4 passed | [results](ubuntu-24.04/results.json) | [manifest](ubuntu-24.04/package.json) |

Each directory preserves the unmodified readiness artifact: compiler/format/interface
checks, targeted network tests, local archive checks and offline example. Unix includes
the untrusted-certificate case; Windows does not. The workflow also passed its selected
queue/integration tests and CLI smoke checks; those outputs remain in the linked run.
No full suite, registry installation or Mooncakes publication was performed.

Artifact ZIP SHA-256 values were verified before extraction:

| Artifact ID | Platform | SHA-256 |
| --- | --- | --- |
| 14117327955 | Windows | `4156f46d1e7c32d5d591bf1fcabe7a21cc418a60a12102b170026e006cf7c0bd` |
| 14117109349 | macOS | `8fbe4f68894a3a93da1f157b85386dee6853a572adbfb05a326eae8f144506c2` |
| 14116974648 | Ubuntu | `20dcf17d2ea49aa625134cab534fb9a307e42c4ce3dc423619660c5ff91f4aee` |

The preceding [run 43603214258](https://github.com/miik-su/MoonCrawler/actions/runs/43603214258)
failed Unix warning denial because the old TLS fixture called an upstream internal API.
The fixture now uses `openssl s_server` and requires curl exit 60, rather than counting
an arbitrary connection failure as successful certificate rejection. No warning was
globally suppressed. These are focused regression results, not a complete security
certification or new 65 MiB/100K performance measurements.
