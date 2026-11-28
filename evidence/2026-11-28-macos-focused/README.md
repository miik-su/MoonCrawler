# macOS 15 ARM64 定向 CI 复跑

2026-11-28，GitHub 托管 macOS 15 ARM64 作业在第 2 次运行中通过。
被测提交为 [`79ed099`](https://github.com/miik-su/MoonCrawler/commit/79ed09927e1e50a55dec98141be41eb86229a200)。
与发布记录提交 [`da68aa3`](https://github.com/miik-su/MoonCrawler/commit/da68aa3799f5c6c49e6d3de799728dd9642f8251)
相比，差异仅涉及说明文档和归档，没有 MoonBit 源码、依赖清单或 CI 工作流变化。
Windows 与 Ubuntu 沿用首次运行的成功结果。
[完整运行](https://github.com/miik-su/MoonCrawler/actions/runs/46019109974/attempts/2) ·
[macOS 作业](https://github.com/miik-su/MoonCrawler/actions/runs/46019109974/job/140862426257)

| 检查 | 结果 |
| --- | --- |
| Native 类型检查、格式和生成接口对照 | 通过 |
| 队列与策略 | 6/6 |
| 集成与失败处理 | 6/6 |
| Fetcher | 4/4 |
| HTML 解析 | 3/3 |
| Sitemap、选择器、流式存储等维护回归 | 10/10 |
| 文件状态恢复模型 | 6/6 |
| CLI 回环冒烟 | 抓取、恢复和导出 2 页，校验 JSON 与 Prometheus 指标、条件请求 304 和 Robots Sitemap |
| 本地包验证 | 145 个文件，解包后 Native 检查通过，离线示例输出 2 页 |

[GitHub 测试步骤日志](workflow-steps.log)保留原始时间戳和输出，移除了 ANSI 颜色及行尾空格。
[结构化结果](artifact/results.json)和 [CI 制品原始文件](artifact/)来自
[制品 15248221168](https://github.com/miik-su/MoonCrawler/actions/runs/46019109974/artifacts/15248221168)。
解包前核对的 ZIP SHA-256 为
`944e5130ea5a55f9855e5b9816f981dd52a2f49ab28f45f38481ba617818285e`。

验证范围为 macOS 15 ARM64、锁定的 MoonBit 工具链及工作流中选定的测试。
六项恢复测试使用合成的持久化文件状态。实机掉电、设备写缓存丢失及完整 APFS 崩溃回放仍未实测。
本轮未运行全量测试、未测 macOS 上的系统 DNS/TLS 专项，也未重新发布或从 Mooncakes 安装。
[恢复模型与设备限制](../windows-macos-power-loss-model/README.md)
