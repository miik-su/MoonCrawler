# MoonCrawler 0.3.0 · 定向维护验证

被测源码为 [`18f0a4f`](https://github.com/miik-su/MoonCrawler/commit/18f0a4fe3c41a7158eafacce538f6a714686f8b7)。
该版本的 [GitHub Actions](https://github.com/miik-su/MoonCrawler/actions/runs/45753747891)
在 Windows、Ubuntu、macOS 全部通过。每份平台结果包含源码 SHA、编译器、命令及退出码。

| 平台 | Parser | Fetcher | 新功能及 DNS | CLI 与打包 | 报告 |
| --- | ---: | ---: | ---: | --- | --- |
| Windows Server 2022 | 3/3 | 3/3 | 9/9 | 通过 | [日志与清单](platforms/windows-2022/README.md) |
| Ubuntu 24.04 | 3/3 | 4/4 | 9/9 | 通过 | [日志与清单](platforms/ubuntu-24.04/README.md) |
| macOS 15 | 3/3 | 4/4 | 9/9 | 通过 | [日志与清单](platforms/macos-15/README.md) |

CLI 验证首次抓取、恢复、导出、带 ETag 和 Last-Modified 的条件请求、
304 复用后输出相等，以及从 Robots 到 Sitemap 索引再到授权页面的路径。
Unix 比 Windows 多执行一项自签证书拒绝测试。
三平台本地归档各含 142 个文件，版本一致，解压后严格编译及离线示例通过。
选定队列、策略及文件恢复组的日志也可在相应 CI 作业查看。
另见 [本地 Windows 记录](local/README.md)。

## 合成模型

| 模型 | 输入与验证 | 记录 |
| --- | --- | --- |
| HTML 资源 | 深嵌套、畸形标记、长属性、预定义实体四个合成夹具 | [parser-profile.json](models/parser-profile.json) |
| 流式恢复内存 | 65 个各 1 MiB 正文页面，同一检查点用两个独立进程分别做全量恢复与元数据恢复 | [restore-profile.json](models/restore-profile.json) |
| WAL 与流式压缩 | 11 个发布前后、清理前后的进程强制终止点都验证任务与页面一致性 | [crash.json](models/crash.json) |

[模型命令、平台与源码元数据](models/models.json)。
同一份检查点上，全量恢复峰值工作集为 155.0 MiB（41.643 秒），
元数据恢复为 33.2 MiB（25.327 秒）。两者识别出同样的 65 个页面，
元数据恢复返回的快照不保留正文。
Windows PeakWorkingSet64 包括运行时与解码缓冲。遍历目录和解码批次仍需内存，
`retained_page_bodies` 只表示恢复完成后返回的正文数量。数据不代表硬内存上限、
真实网站吞吐量、断电持久性或独立安全认证。

## CI 产物校验

| 平台标签 | Artifact ID | ZIP SHA-256 |
| --- | ---: | --- |
+| macos-15 | 15087111047 | `1afbd3fa07a7eb6f3876f0aa33afa23c114525c8a012ed467f93d3775d8826e5` |
| ubuntu-24.04 | 15086956390 | `c6b990ba121f1d7a3622899f1702ed4b5113a359c4e862dda5daf3efe2b675eb` |
| windows-2022 | 15086539197 | `9e4998a20ac21ab70b9dbd55129e11ef113f76a4109cfb87c4f7eb6f59e1392f` |

本次只执行关键测试，Mooncakes 发布继续暂缓。归档提交只补验证材料和索引，
被测实现使用上面的源码提交。
