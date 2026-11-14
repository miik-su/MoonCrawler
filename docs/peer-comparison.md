# 同类项目与独立价值对照

核对日期：2026-11-14。MoonCrawler 基线：0.2.3、提交 `a49abdf`。
本页用于解释选题和独立贡献，不是第三方代码审计或赛事资格认定。

## 对照来源及方法

通过 `moon search crawler --limit 6` 检索到 `guangting0905/mooncrawl@0.1.4`。
对照其公开 README，固定源码为
[`15d71cca8e00c711cf00b54e520989a7d9ecf9e3`](https://github.com/guangting0905/mooncrawl/blob/15d71cca8e00c711cf00b54e520989a7d9ecf9e3/README.md)。
对方仓库声明 Apache-2.0。这里记录其自述能力和限制，未独立运行其测试，
也未对它做安全审计；“未见文档承诺”不等于已证明功能不存在或存在漏洞。

## 能力与取舍

| 方向 | MoonCrawl 0.1.4 的公开说明 | MoonCrawler 0.2.3 的实现与证据 |
| --- | --- | --- |
| 共同功能 | URL、Robots、并发调度、HTML 提取、导出、可替换传输 | 同样覆盖这些能力，单凭这些功能不足以说明独立价值 |
| 提取与导出 | CSS 选择器子集、字段/容器提取、JSONL/CSV | 标题、文本、元数据、图片、链接、canonical，JSONL；没有 CSS/XPath 或 CSV |
| 后端 | README 声明 JS 与 Native 双后端及全量测试 | 当前只支持 Native；三操作系统定向测试，未宣称全量测试通过 |
| 抓取范围 | 已知限制写明站外链接仍会入队 | 默认要求明确域名范围，发现链接及重定向按策略过滤；见 core/scope、engine/policy 测试 |
| 连接安全 | 本次 README 对照未见 DNS 固定连接 IP 的承诺；不据此推断其安全性 | 默认 curl 逐跳解析/检查并固定 IP，核对连接对端；有实际 UDP DNS/HTTP 夹具，仍有明确验证边界 |
| 去重 | 布隆过滤器，文档说明误报与容量取舍 | 在配置上限内使用精确任务键及优先级/延迟队列；保留全部任务元数据，内存代价不同 |
| 重试与恢复 | 已知限制写明无自动请求重试、单机内存队列 | 有界重试、持久化延迟与重定向继续状态、任务状态恢复 |
| 持久化 | 本次对照未见 WAL/分片检查点承诺 | 任务/Page 批量日志、序列与作业身份、分片检查点、11 个强制中断场景 |
| 资源与读取 | 文档提示 Robots 解析限制不保护下载阶段内存 | 响应、Robots 和页面预算；PageReader 按记录读取与导出，Engine 本身仍保留完整 Page |

双方的实现目标和取舍不同。MoonCrawler 的定位是**面向安全访问、可靠恢复与受限资源导出的静态抓取引擎**。
不宣称“生态首个”“唯一爬虫”，也不把其他框架的功能列表作为本项目的新贡献。

## 可复核的独立成果

| 成果 | 实现入口 | 测试与原始证据 |
| --- | --- | --- |
| 默认范围与逐跳网络边界 | core/models、security/policy、fetcher/fetcher、engine/engine | [安全与协议组](../evidence/2026-11-13-0.2.3/wire-dns.log)，另有 core/scope、engine/policy、fetcher/pinning 测试 |
| 增量持久化与异常恢复 | storage/journal、storage/catalog | [11 阶段中断结果](../evidence/2026-11-13-0.2.3/crash.json)及 storage/journal、identity 测试 |
| 页面目录与按需导出 | storage/reader、storage/catalog | [65 MiB 内存对照](../evidence/2026-11-13-0.2.3/storage-profile.json)及 reader/catalog 回归 |
| Host 分组调度及明确复杂度 | frontier/frontier | [100K 任务与 10K Host 模型](../evidence/2026-11-13-0.2.3/model.json) |

65 MiB 对照比较的是 **MoonCrawler 自身完整恢复与目录导出两条路径**，
不是与 MoonCrawl 的横向性能比较。候选检查数不等于真实网页吞吐量；
固定夹具的内存值不构成通用资源保证。

## 来源与更新边界

MoonCrawl 是本次选题查重的外部基线，不是 MoonCrawler 的源码移植来源。
Scrapy 仅作为架构概念参考，具体范围与 BSD-3-Clause 标注见
[第三方声明](../THIRD_PARTY_NOTICES.md)。若之后复用任何第三方实现，应重新记录
具体文件、版本、许可证和修改范围，不能沿用“未复制代码”的旧声明。

是否满足本期的生态增量要求，由赛事方结合实际材料判断；本页不代替其审核。
