# MoonCrawler

面向安全访问、可靠恢复与受限资源导出的 MoonBit 静态网页抓取引擎。

工作流程：URL 规范化 → Host 分组队列 → 默认 curl 安全传输 → Robots / 域名调度 → HTML 提取 → Pipeline → 增量持久化与重启恢复。

当前版本 **0.2.3**。参见[最新完善说明](https://github.com/miik-su/MoonCrawler/blob/main/docs/review-0.2.3.md)及[测试数据和实际结果](https://github.com/miik-su/MoonCrawler/blob/main/evidence/2026-11-13-0.2.3/README.md)。
[Windows / Ubuntu / macOS 定向 CI 结果](https://github.com/miik-su/MoonCrawler/blob/main/evidence/2026-11-13-0.2.3/platforms/README.md)已保存原始日志和内存数据。
[支持范围与发布待办](docs/compatibility.md) 明确列出限制。

## 快速开始

要求 MoonBit `0.10.17+d971670cd` / moon `0.1.20261023`、native 工具链和 curl。
Windows 可使用系统 curl；Linux 需要 C 编译器和 OpenSSL 开发依赖。

```sh
moon update
moon run cmd/mooncrawler --target native -- init config.json
```

编辑 `config.json`，将 `allowed_hosts` 设置为准备抓取的授权站点域名。
默认开启 Robots、单域名并发 1、请求间隔 1000ms、总任务上限 1000。

```sh
moon run cmd/mooncrawler --target native -- validate config.json
moon run cmd/mooncrawler --target native -- crawl config.json data/job https://example.com/
moon run cmd/mooncrawler --target native -- status data/job
moon run cmd/mooncrawler --target native -- export data/job pages.jsonl
moon run cmd/mooncrawler --target native -- resume data/job
```

运行时在另一终端执行 `pause data/job`，停止领取新任务并等待在途请求结束、保存检查点。
恢复使用保存的配置。`stats` 与 `status` 显示最近检查点计数；导出拒绝覆盖已有文件。
导出使用按需页面读取器，不会先恢复全部正文；导出期间持有作业锁，应先暂停或停止爬虫。

离线扩展示例与本地真实 HTTP 验证：

```sh
moon run examples/offline --target native
moon run tools/cli_smoke.mbtx
```

## 模块

项目与已有爬虫框架共享 URL、Robots、调度和 HTML 提取等基础能力。
本项目的独立成果集中在默认网络边界、增量持久化、故障恢复验证和按需页面导出；
详见[同类项目对照](https://github.com/miik-su/MoonCrawler/blob/main/docs/peer-comparison.md)。
当前没有 CSS/XPath、CSV、浏览器渲染或分布式执行能力。

| 包 | 能力 |
| --- | --- |
| `url` / `core` | URL 规范化、相对链接、过滤、模型与配置 |
| `frontier` / `retry` | 优先级堆、延迟堆、去重、租约、状态与退避 |
| `scheduler` / `robots` | 域名/全局限流、暂停、规则与缓存 |
| `security` / `fetcher` | SSRF 策略、DNS 检查与固定连接 IP、受限 HTTP(S) |
| `parser` / `pipeline` | MoonBit HTML5 DOM、内容提取、清洗和过滤 |
| `storage` / `engine` | 内存/文件适配器、JSONL、原子检查点、完整生命周期 |

UnsafeFetcher、Parser、Processor、Storage 开放给外部 MoonBit 包实现。
UnsafeFetcher 是可信代码扩展，不是安全沙箱。Engine 使用单进程重启恢复；
Frontier 的独立 fencing API 不表示 Engine 提供运行时抢占、续租或分布式执行。
项目源码、CLI、验证脚本均为 MoonBit；默认传输适配器调用 curl。
`MOONCRAWLER_CURL` 可指定可信的 curl 可执行文件路径。

## 文档

- [架构与扩展接口](docs/architecture.md)
- [配置字段](docs/configuration.md)
- [兼容性与后续计划](docs/compatibility.md)
- [关键验证记录](https://github.com/miik-su/MoonCrawler/blob/main/docs/verification.md)
- [依赖、Scrapy 与 RFC 参考来源](THIRD_PARTY_NOTICES.md)
- [代码与验证材料来源](docs/source-provenance.md)
- [本期实质贡献索引](https://github.com/miik-su/MoonCrawler/blob/main/docs/monthly-contributions.md)
- [工程与材料准备状态](https://github.com/miik-su/MoonCrawler/blob/main/docs/participation-readiness.md)

测试范围、命令和原始结果见[验证记录](https://github.com/miik-su/MoonCrawler/blob/main/docs/verification.md)。API 精确签名见各包的 `pkg.generated.mbti`。
当前按维护者要求暂不发布 Mooncakes；可以从源码运行。历史证据、验证脚本及探针保存在 GitHub，
本地包清单将它们排除；打包后源码检查和离线示例可用 `moon run tools/package_check.mbtx` 验证。
Apache-2.0；依赖按各自许可证使用。
