# Focused maintenance verification

Source: `075f20fdbadc5b9a7e78b2e4ec2a875867aaa058`.
Scope: build, interfaces, selected transport and parser cases, and local package checks.
Mooncakes publication: **not attempted**. Full suite: **not run**.

| Check | Exit | Elapsed ms | Raw output |
| --- | ---: | ---: | --- |
| check | 0 | 343 | [log](check.log) |
| format | 0 | 4 | [log](format.log) |
| interfaces | 0 | 325 | [log](interfaces.log) |
| interface-diff | 0 | 3 | [log](interface-diff.log) |
| fetcher | 0 | 1684 | [log](fetcher.log) |
| parser | 0 | 738 | [log](parser.log) |
| package | 0 | 3576 | [log](package.log) |

[Structured results](results.json) · [Package file manifest and extracted checks](package.json).
The extracted package is checked with deny-warn and its offline example produces two JSONL pages. This is a local archive check, not a registry installation or publication test. Windows excludes the Unix TLS-server case; Unix CI runs it. Compiler warn denial does not suppress unrelated C compiler diagnostics from upstream dependencies.

The 0.2.3 performance and three-platform runtime evidence remain in their original dated directory and source revision. This run does not repeat the 65 MiB/100K models or certify all tests, all security boundaries or power-loss durability.
