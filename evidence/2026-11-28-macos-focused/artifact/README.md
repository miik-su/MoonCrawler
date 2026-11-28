# Focused maintenance verification

Source: `79ed09927e1e50a55dec98141be41eb86229a200`.
Scope: build, interfaces, transport, parser, Sitemap, storage, loopback CLI, and local package.
Mooncakes publication: **not attempted**. Full suite: **not run**.

| Check | Exit | Elapsed ms | Raw output |
| --- | ---: | ---: | --- |
| check | 0 | 480 | [log](check.log) |
| format | 0 | 9 | [log](format.log) |
| interfaces | 0 | 497 | [log](interfaces.log) |
| interface-diff | 0 | 16 | [log](interface-diff.log) |
| fetcher | 0 | 1565 | [log](fetcher.log) |
| parser | 0 | 766 | [log](parser.log) |
| maintenance | 0 | 2831 | [log](maintenance.log) |
| cli | 0 | 5440 | [log](cli.log) |
| package | 0 | 6566 | [log](package.log) |
| power-loss-model | 0 | 64 | [log](power-loss-model.log) |

[Structured results](results.json) · [Package file manifest and extracted checks](package.json).
The extracted package is checked with deny-warn and its offline example produces two JSONL pages. This is a local archive check, not a registry installation or publication test. Windows excludes the Unix TLS-server case; Unix CI runs it. Compiler warn denial does not suppress unrelated C compiler diagnostics from upstream dependencies.

The 0.2.3 performance and three-platform runtime evidence remain in their original dated directory and source revision. This run does not repeat the 65 MiB/100K models or certify all tests, all security boundaries or power-loss durability.
