# Focused maintenance verification

Source: `18f0a4fe3c41a7158eafacce538f6a714686f8b7`.
Scope: build, interfaces, transport, parser, Sitemap, storage, loopback CLI, and local package.
Mooncakes publication: **not attempted**. Full suite: **not run**.

| Check | Exit | Elapsed ms | Raw output |
| --- | ---: | ---: | --- |
| check | 0 | 660 | [log](check.log) |
| format | 0 | 20 | [log](format.log) |
| interfaces | 0 | 650 | [log](interfaces.log) |
| interface-diff | 0 | 24 | [log](interface-diff.log) |
| fetcher | 0 | 1847 | [log](fetcher.log) |
| parser | 0 | 875 | [log](parser.log) |
| maintenance | 0 | 3124 | [log](maintenance.log) |
| cli | 0 | 8012 | [log](cli.log) |
| package | 0 | 11566 | [log](package.log) |

[Structured results](results.json) · [Package file manifest and extracted checks](package.json).
The extracted package is checked with deny-warn and its offline example produces two JSONL pages. This is a local archive check, not a registry installation or publication test. Windows excludes the Unix TLS-server case; Unix CI runs it. Compiler warn denial does not suppress unrelated C compiler diagnostics from upstream dependencies.

The 0.2.3 performance and three-platform runtime evidence remain in their original dated directory and source revision. This run does not repeat the 65 MiB/100K models or certify all tests, all security boundaries or power-loss durability.
