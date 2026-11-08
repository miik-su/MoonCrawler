# Dependencies and design references

All crawler scheduling, URL policy, Robots, pipeline, persistence, CLI and tests are authored in MoonBit.
No third-party source was copied into the implementation.

| Dependency | Version | Role | Upstream license |
| --- | --- | --- | --- |
| moonbitlang/core | bundled toolchain | collections, JSON, UTF-8 | Apache-2.0 |
| moonbitlang/async | 0.22.5 | concurrency, DNS, filesystem, processes | Apache-2.0 |
| moonbit-community/html | 0.2.4 | HTML5 DOM | Apache-2.0 |
| moonbitlang/x | 0.5.7 | HTTP Retry-After date validation | Apache-2.0 |
| curl executable | external, tested 8.21.0 | HTTP/TLS and decompression | curl license |

Dependency license files remain in `.mooncakes/` after installation. curl is not redistributed.
The external curl license is published at https://curl.se/docs/copyright.html .

Architectural references (concepts only):

- [Scrapy scheduler](https://github.com/scrapy/scrapy/blob/master/scrapy/core/scheduler.py): separate scheduler, duplicate filter and persistence responsibilities.
- [Scrapy middleware](https://github.com/scrapy/scrapy/blob/master/docs/topics/downloader-middleware.rst): separate retry, redirect and Robots policies.
- [RFC 9309](https://www.rfc-editor.org/rfc/rfc9309.html): Robots group selection, rules and caching; see our documented profile.
- [MoonBit HTML5 parser](https://github.com/moonbit-community/html5-mbt): reused through an extraction adapter.

See [compatibility](docs/compatibility.md) for verified scope.
