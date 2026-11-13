# Dependency inventory — observed 2026-11-13

This records the installed source inputs for native 0.2.2 development. It is not
a certification of future binary distributions or every transitive system library.
No AI models, pretrained weights or training datasets are distributed. Synthetic
queue/HTML fixtures in evidence/ are authored tests.

| Component | Exact observed version | Source / local evidence | License evidence |
| --- | --- | --- | --- |
| moonbitlang/core | 0.10.17+d971670cd | toolchain lib/core/moon.mod, [upstream](https://github.com/moonbitlang/core) | toolchain lib/core/LICENSE, Apache-2.0 |
| moonbitlang/async | 0.22.5 | moon.mod and .mooncakes/moonbitlang/async/moon.mod, [upstream](https://github.com/moonbitlang/async) | installed LICENSE, Apache-2.0 |
| moonbit-community/html | 0.2.4 | moon.mod and installed moon.mod, [upstream](https://github.com/moonbit-community/html5-mbt) | installed LICENSE, Apache-2.0 |
| moonbitlang/x | 0.5.7 | direct and HTML dependency agree in installed moon.mod, [upstream](https://github.com/moonbitlang/x) | metadata and source/licenserc.toml Apache-2.0 notices; package lacks root LICENSE in this installation |
| curl | 8.21.0 Windows (runtime, not pinned dependency) | curl --version: Schannel, zlib/1.3.2 | [curl license](https://curl.se/docs/copyright.html); executable not redistributed |

SHA-256 of locally installed license evidence (bytes as installed):

| File | SHA-256 |
| --- | --- |
| core/LICENSE | 86460C45017FFACB9AA9E18850FA9FDB036339DC8851125465F4A3F3442FC894 |
| async/LICENSE | CFC7749B96F63BD31C3C42B5C471BF756814053E847C10F3EB003417BC523D30 |
| html/LICENSE | CFC7749B96F63BD31C3C42B5C471BF756814053E847C10F3EB003417BC523D30 |
| x/licenserc.toml (notice/config, not full license text) | 35B85EEB8C4B565C04EC540DFD166B257EFE22D6E37132C77C28258A2AF831F4 |

Before distributing binaries, review the actual artifact's linked/runtime libraries,
retain applicable license texts/notices and modification notices, and resolve the
missing x package license-text packaging evidence. A future bundled curl or OpenSSL
distribution requires its own inventory; today's external executable arrangement
does not cover that future artifact. Preserve project LICENSE, NOTICE and contribution
terms. No new copyright holder is inferred from a GitHub account name.

The x package is experimental; versions remain fixed and upgrades require focused
API/protocol regression checks. Installer and Action pins are documented separately
in the setup workflow; they do not certify all transitive supply-chain inputs.
