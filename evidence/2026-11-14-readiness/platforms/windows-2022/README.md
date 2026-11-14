# Readiness verification — 2026-11-14

Source: `aceb4f27b997cb9295666d94946d88cbd2f5afdb`.
Scope: metadata, source documentation, platform-test warning handling and local package preparation.
Mooncakes publication: **not attempted, explicitly deferred**. Full suite: **not run**.

| Check | Exit | Wall ms | Raw output |
| --- | ---: | ---: | --- |
| check | 0 | 522 | [log](check.log) |
| format | 0 | 16 | [log](format.log) |
| interfaces | 0 | 539 | [log](interfaces.log) |
| interface-diff | 0 | 21 | [log](interface-diff.log) |
| fetcher | 0 | 1423 | [log](fetcher.log) |
| package | 0 | 7967 | [log](package.log) |

[Structured results](results.json) · [Package file manifest and extracted checks](package.json).
The extracted package is checked with deny-warn and its offline example produces two JSONL pages. This is a local archive check, not a registry installation or publication test. Windows excludes the Unix TLS-server case; Unix CI runs it. Compiler warn denial does not suppress unrelated C compiler diagnostics from upstream dependencies.

The 0.2.3 performance and three-platform runtime evidence remain in their original dated directory and source revision. This run does not repeat the 65 MiB/100K models or certify all tests, all security boundaries or power-loss durability.
