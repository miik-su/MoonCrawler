# Security policy

0.2.x is a development series; 0.1.x users should upgrade. No version is described
as having completed an external security audit or production certification.

Use GitHub's private vulnerability reporting for this repository when enabled:
[report a vulnerability](https://github.com/miik-su/MoonCrawler/security/advisories/new).
If private reporting is unavailable, open an issue asking the maintainer for a
private reporting channel, without exploit details, secrets or sensitive datasets.

Include affected commit/toolchain/curl/OS versions, minimal reproduction, expected
and observed behavior, and impact. Test only against infrastructure you control.
The maintainer will triage, reproduce, prepare a fix and coordinate disclosure;
there is no guaranteed response SLA or bug bounty. Confirmed issues may receive
GitHub security advisories after coordinated disclosure.

Triage prioritizes violations of connection policy, unauthorized data access and
unbounded resource use. Maintenance records should include the scope, a targeted
regression and the fixed revision. Discuss unpatched findings in the private channel.

The default transport checks host scope and the resolved IPv4 target before
connecting. System DNS coverage is limited to the addresses returned by its
resolver, and curl must be trusted. Keep the job directory and exports private.
Custom UnsafeFetcher, Parser, Processor and Storage are trusted code.
See [operational boundaries](docs/contracts.md) and [compatibility](docs/compatibility.md).
