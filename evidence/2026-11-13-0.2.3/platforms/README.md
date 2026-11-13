# 三平台定向 CI 结果

源码：`76a44fea4e44751b000878a38a8b0b7da54af964`。
[GitHub Actions 运行记录](https://github.com/miik-su/MoonCrawler/actions/runs/43421224981)。
三平台均成功完成本轮定向验证；**没有运行全量测试**。
原始产物已按目录永久保存，ZIP 下载摘要与 GitHub 上传摘要一致。

| 平台 | 定向组数 | 结果 | 完整恢复内存 MiB | 目录导出内存 MiB | 测量方式 | 原始数据 |
| --- | ---: | --- | ---: | ---: | --- | --- |
| windows-2022 | 10 | 通过 | 152.44 | 30.66 | Windows PeakWorkingSet64 | [报告](windows-2022/README.md) · [内存 JSON](windows-2022/storage-profile.json) |
| ubuntu-24.04 | 10 | 通过 | 165.91 | 37.14 | Linux VmHWM | [报告](ubuntu-24.04/README.md) · [内存 JSON](ubuntu-24.04/storage-profile.json) |
| macos-15 | 10 | 通过 | 198.29 | 37.81 | macOS sampled RSS (not peak) | [报告](macos-15/README.md) · [内存 JSON](macos-15/storage-profile.json) |

Windows 使用 PeakWorkingSet64，Linux 使用 VmHWM；**macOS 仅为导出完成后的抽样 RSS，不能作为峰值比较**。
固定 65 MiB 合成夹具、Native debug，各路径使用新进程；这些数值不是通用内存上限。
详细输入、计时和测量说明见各平台 README 及 JSON。

本机根目录报告的源码为 `0b3aee1`；`76a44fe` 仅调整 macOS CI 环境和对应文档，产品源码相同。
首次 macos-14 作业在获得运行器前取消；迁移到 macos-15 后才取得此处的成功结果。
