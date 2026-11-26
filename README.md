# MoonCrawler

[![Focused native verification](https://github.com/miik-su/MoonCrawler/actions/workflows/focused.yml/badge.svg)](https://github.com/miik-su/MoonCrawler/actions/workflows/focused.yml)

面向安全访问、可靠恢复与受限资源导出的 MoonBit 静态网页抓取引擎。

工作流程：URL 规范化 → Host 分组队列 → 默认 curl 安全传输 → Robots / 域名调度 → HTML 提取 → Pipeline → 增量持久化与重启恢复。

当前源码为 **0.3.0 开发版**，面向有明确站点授权范围的静态网页采集和离线内容处理。
支持范围见[兼容矩阵](docs/compatibility.md)。各批验证按被测提交索引，包含三平台
定向运行及历史合成负载数据。[验证记录](https://github.com/miik-su/MoonCrawler/blob/main/docs/verification.md)

## 快速开始

要求 MoonBit `0.10.17+d971670cd` / moon `0.1.20261023`、native 工具链和 curl。
需要 Native C 工具链。Windows 使用 MSVC 和系统 curl，Ubuntu 另需 OpenSSL 开发库，
macOS 使用 Xcode Command Line Tools。先运行 `moon version --all` 和 `curl --version`。

无需联网即可运行离线示例（依赖下载完成后），它会向标准输出写出两条 JSONL 页面记录：

```sh
moon update
moon run examples/offline --target native
```

实际抓取需要授权站点。下面使用 `example.com` 作为域名占位，运行前将配置和种子替换为你获准访问的站点。

```sh
moon run cmd/mooncrawler --target native -- init config.json
```

编辑 `config.json`，将 `allowed_hosts` 设置为准备抓取的授权站点域名。
默认开启 Robots、单域名并发 1、请求间隔 1000ms、总任务上限 1000。

```sh
moon run cmd/mooncrawler --target native -- validate config.json
moon run cmd/mooncrawler --target native -- crawl config.json data/job https://example.com/
moon run cmd/mooncrawler --target native -- status data/job
moon run cmd/mooncrawler --target native -- stats data/job
moon run cmd/mooncrawler --target native -- export data/job pages.jsonl
```

运行时可在另一终端执行 `moon run cmd/mooncrawler --target native -- pause data/job`，
等待原进程退出并保存状态后，用 `moon run cmd/mooncrawler --target native -- resume data/job`
按保存的配置继续。`status` 显示保存的错误详情，`stats` 显示任务尝试和重试汇总。
导出持有作业锁并拒绝覆盖已有文件，使用按需读取器逐条输出正文。

在源码仓库可运行真实 HTTP CLI 冒烟检查（使用本机回环服务）：

```sh
moon run tools/cli_smoke.mbtx
```

## 模块

项目与已有爬虫框架共享 URL、Robots、调度和 HTML 提取等基础能力。
本项目的独立成果集中在默认网络边界、增量持久化、故障恢复验证和按需页面导出；
详见[同类项目对照](https://github.com/miik-su/MoonCrawler/blob/main/docs/peer-comparison.md)。
可选择从 Sitemap XML（含索引或 Robots 声明）发现页面，对上一轮作业执行条件重抓，
或通过 MoonBit API 使用单元素选择器提取字段。范围和命令见[使用指南](docs/user-guide.md)。
CLI 文件作业按记录恢复、压缩与导出，运行后可选输出 JSON 指标。

| 包 | 能力 |
| --- | --- |
| `url` / `core` | URL 规范化、相对链接、过滤、模型与配置 |
| `frontier` / `retry` | 优先级堆、延迟堆、去重、租约、状态与退避 |
| `scheduler` / `robots` / `sitemap` | 域名/全局限流、暂停、规则与缓存、有界 XML 发现 |
| `security` / `fetcher` | SSRF 策略、DNS 检查与固定连接 IP、受限 HTTP(S) |
| `parser` / `pipeline` | HTML5 DOM、有限单元素选择器、内容清洗和过滤 |
| `storage` / `engine` | 内存/文件适配器、JSONL、原子检查点、完整生命周期 |

UnsafeFetcher、Parser、Processor、Storage 开放给外部 MoonBit 包实现。
UnsafeFetcher 是可信代码扩展，不是安全沙箱。Engine 使用单进程重启恢复；
Frontier 的独立 fencing API 不表示 Engine 提供运行时抢占、续租或分布式执行。
项目源码、CLI、验证脚本均为 MoonBit；默认传输适配器调用 curl。
`MOONCRAWLER_CURL` 可指定可信的 curl 可执行文件路径。

## 文档

- [架构与扩展接口](docs/architecture.md)
- [配置字段](docs/configuration.md)
- [使用指南与故障排查](docs/user-guide.md)
- [软件许可、协议与数据边界](docs/contracts.md)
- [安全报告渠道](SECURITY.md)
- [兼容性与后续计划](docs/compatibility.md)
- [关键验证记录](https://github.com/miik-su/MoonCrawler/blob/main/docs/verification.md)
- [依赖、Scrapy 与 RFC 参考来源](THIRD_PARTY_NOTICES.md)
- [代码与验证材料来源](docs/source-provenance.md)
- [本期实质贡献索引](https://github.com/miik-su/MoonCrawler/blob/main/docs/monthly-contributions.md)
- [持续维护基线](https://github.com/miik-su/MoonCrawler/blob/main/docs/maintenance-baseline.md)
- [工程与材料准备状态](https://github.com/miik-su/MoonCrawler/blob/main/docs/participation-readiness.md)

测试范围、命令和原始结果见[验证记录](https://github.com/miik-su/MoonCrawler/blob/main/docs/verification.md)。API 精确签名见各包的 `pkg.generated.mbti`。
当前按维护者要求暂不发布 Mooncakes；可以从源码运行。历史证据、验证脚本及探针保存在 GitHub，
本地包清单将它们排除；打包后源码检查和离线示例可用 `moon run tools/package_check.mbtx` 验证。
项目源代码采用 [Apache-2.0](LICENSE)。[NOTICE](NOTICE) 和
[第三方声明](THIRD_PARTY_NOTICES.md) 记录归属和依赖许可证。
