# MoonCrawler 定向维护验证 · 2026-11-20

被测源码为 [`075f20f`](https://github.com/miik-su/MoonCrawler/commit/075f20fdbadc5b9a7e78b2e4ec2a875867aaa058)。
本地为 Windows / Native，curl 为 8.22.0（Schannel）。工具链、命令、耗时和退出状态见 [results.json](results.json)。

| 本地检查 | 结果 |
| --- | --- |
| Native 严格检查、格式、接口生成及接口差异 | 全部通过，生成接口无差异 |
| HTML 类型与结构限制 | [3 项通过](parser.log) |
| 网络传输、响应头及解压限制 | [3 项通过](fetcher.log)；Unix 证书夹具由 Unix CI 检查 |
| 本地回环 CLI | init、validate、crawl、Robots、去重、resume、status、export 通过，共 2 页 |
| 本地包 | [130 个文件](package.json)，解压后严格检查通过，离线示例输出 2 页 |
| README 与本轮说明 | 检查 34 个仓库相对链接；随包文档的相对链接也存在于包内 |
| 许可文件 | 本地 async、HTML 的 LICENSE 和 x 的 licenserc.toml SHA-256 与既有清单一致；同时检查根 LICENSE、NOTICE 及分发清单 |

三平台检查、各作业日志和测试产物见[本次 CI](https://github.com/miik-su/MoonCrawler/actions/runs/44728761876)。

| CI 平台 | Parser | Fetcher | 原始结果 |
| --- | ---: | ---: | --- |
| Windows Server 2022 | 3 通过 | 3 通过 | [报告与日志](platforms/windows-2022/README.md) |
| Ubuntu 24.04 | 3 通过 | 4 通过 | [报告与日志](platforms/ubuntu-24.04/README.md) |
| macOS 15 | — | — | [归档时仍等待运行器](https://github.com/miik-su/MoonCrawler/actions/runs/44728761876/job/136262808046) |

已归档平台的 ZIP 摘要已和 GitHub 记录核对：

- Windows，`2763928f8e2d3c33494bf434cb4c83fd9f70bead4241e73946baa41e2e361d18`。
- Ubuntu，`65bcca08e5016187d01f73a5686ac4c4dff1d617c53c981b30cddb4770ba5648`。

历史 [65 MiB 与 100K 任务场景](../2026-11-13-0.2.3/README.md)保留当时的源码、合成数据和运行条件。
本次只运行定向检查。全量测试、新负载测量、断电认证和 Mooncakes 发布均未执行。
上游 async 有 MSVC 的 EINVAL 重定义警告，保留在日志中；MoonBit 的严格检查通过。
