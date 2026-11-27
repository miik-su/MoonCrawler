# Linux 系统 DNS 与导出写满验证

2026-11-27，GitHub Ubuntu 24.04 的两项专项均通过。被测源码为
[`71e30bc`](https://github.com/miik-su/MoonCrawler/commit/71e30bc612d8ace8ab7721fa5c9c213620cd1e82)。
[GitHub Actions 运行](https://github.com/miik-su/MoonCrawler/actions/runs/45976052977)

| 专项 | 合成输入与实测结果 | 原始记录 |
| --- | --- | --- |
| 系统 DNS CNAME | 两个保留示例域名分别通过一个 CNAME 得到一个 IPv4。原生 `SystemResolver` 返回的公网类地址 `8.8.8.8` 通过检查；私网地址 `10.0.0.1` 解析成功后被安全策略拒绝。 | [测试步骤输出](cname.log) · [完整作业](https://github.com/miik-su/MoonCrawler/actions/runs/45976052977/job/140427927635) |
| CLI 写满导出 | 两条各含 98,304 字节正文的合成页面。向 64 KiB tmpfs 导出时，内核写入返回 `ENOSPC`，CLI 退出码为 1，留下 65,536 字节的不完整 JSONL。同一作业向正常文件系统重导成功，两条记录的 URL 和正文逐一匹配。 | [测试步骤输出](export-enospc.log) · [完整作业](https://github.com/miik-su/MoonCrawler/actions/runs/45976052977/job/140427927951) |

DNS 使用隔离的挂载和网络命名空间，测试 DNS 只在回环上回答。两个终点地址均为
夹具数据，未建立 HTTP 连接。范围限于 Linux 系统解析器选中的单个 IPv4，未覆盖
公共递归 DNS 缓存、多记录返回、IPv6 或 Windows/macOS 系统解析器。

写满用例触发的是 Linux tmpfs 上的真实写入错误。它覆盖导出目标写满，
未覆盖作业盘写满、同步阶段报错、配额、NTFS/APFS、块设备物理掉电和控制器缓存丢失。
导出失败后应把残留文件视为部分输出。断电恢复证据及实机验收条件另见
[Windows 与 macOS 恢复模型](../windows-macos-power-loss-model/README.md)。

前两次执行暴露了夹具问题：先是 Linux 构建产物文件名有 `.exe` 后缀，随后是
DNS 响应协程在断言通过后未退出。归档以两项均正常退出的最终复跑为准。
[初次运行](https://github.com/miik-su/MoonCrawler/actions/runs/45975630919) ·
[修正路径后的运行](https://github.com/miik-su/MoonCrawler/actions/runs/45975835813)

本轮专项未运行全量测试，未发布 Mooncakes。
