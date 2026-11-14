# 2026 年 11 月实质贡献索引

整理日期：2026-11-14。基线为默认分支 `main` 的 `a49abdf`（0.2.3）。
该基线有 44 条提交，最早记录为 2026-11-08；这只是开发历史统计，
不表示每条都被赛事认定为有效工作。这里按成果归并，不以提交条数替代工程价值。

## 已完成能力、提交与验证

| 成果 | 代表性提交 | 对应验证 |
| --- | --- | --- |
| URL、配置、队列、重试、调度基础 | [29b780b](https://github.com/miik-su/MoonCrawler/commit/29b780b)、[4dc768f](https://github.com/miik-su/MoonCrawler/commit/4dc768f)、[6c60268](https://github.com/miik-su/MoonCrawler/commit/6c60268) | url/url、core/config、frontier/frontier、retry/retry、scheduler/scheduler 测试 |
| 默认 curl 安全传输与可运行 Engine/CLI | [4436cc9](https://github.com/miik-su/MoonCrawler/commit/4436cc9)、[d1f5f47](https://github.com/miik-su/MoonCrawler/commit/d1f5f47)、[c234430](https://github.com/miik-su/MoonCrawler/commit/c234430) | fetcher/network、limits；engine/engine；本地真实 HTTP CLI 冒烟 |
| 默认拒绝空范围、逐跳过滤、日志型持久化 | [7573ecd](https://github.com/miik-su/MoonCrawler/commit/7573ecd)、[fe0165c](https://github.com/miik-su/MoonCrawler/commit/fe0165c) | core/scope、engine/policy、storage/journal、identity 测试 |
| 页面身份/预算、Host 分组及协议边界 | [f21e881](https://github.com/miik-su/MoonCrawler/commit/f21e881) | [0.2.1 记录](../evidence/2026-11-10/README.md)及 contracts、资源、队列、协议组 |
| 临时 Robots 故障与 304 语义 | [eef2d01](https://github.com/miik-su/MoonCrawler/commit/eef2d01) | engine/review：有界重试、重启恢复、已有 Page 下拒绝无条件 304 |
| rel Token、Resolver 答案集合与真实连接固定 | [a240653](https://github.com/miik-su/MoonCrawler/commit/a240653)、[7448c78](https://github.com/miik-su/MoonCrawler/commit/7448c78) | parser/rel、security/answers、fetcher/pinning 测试 |
| 页面目录式恢复验证与按需导出 | [7753a58](https://github.com/miik-su/MoonCrawler/commit/7753a58) | storage/reader、catalog；[65 MiB 对照](../evidence/2026-11-13-0.2.3/storage-profile.json) |
| DNS 报文与中断恢复夹具 | [38f8c8e](https://github.com/miik-su/MoonCrawler/commit/38f8c8e)、[42784ab](https://github.com/miik-su/MoonCrawler/commit/42784ab) | 实际 UDP TTL=0、HTTP 重定向；11 阶段 SIGKILL/TerminateProcess 恢复 |
| 可复现的三平台验证与原始产物归档 | [0b3aee1](https://github.com/miik-su/MoonCrawler/commit/0b3aee1)、[76a44fe](https://github.com/miik-su/MoonCrawler/commit/76a44fe)、[a49abdf](https://github.com/miik-su/MoonCrawler/commit/a49abdf) | [Windows / Ubuntu / macOS 结果](../evidence/2026-11-13-0.2.3/platforms/README.md)，原始 ZIP 摘要及日志 |

实际运行过哪些测试，应以各报告的源码 SHA、命令、退出码和日志为准；
仓库里存在测试文件不代表它已在全部环境执行。

## 已有基础与后续工作

0.2.3 的上述能力是已有基础。此次 11 月整理新增同类项目对照、来源清单、
贡献索引、打包检查及警告修正，不把这些文档改动描述成新增抓取引擎。

仍未完成：全量测试认证、Engine 全局正文按需保留、DOM 构建硬预算、
覆盖引导模糊测试、断电/磁盘缓存丢失实验以及更大真实任务的长期验证。
Mooncakes 发布按维护者要求暂停，未用“发布准备”代替“已经发布”。

报名时间、有效工作计算及既往参赛关系由维护者据实填报，并以本期官方规则为准。
这份索引是工程证据导航，不是申报书或审核通过证明。
