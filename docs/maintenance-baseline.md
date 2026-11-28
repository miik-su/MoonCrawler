# 持续维护基线

初审状态按维护者提供的对话登记为通过。正式时间和通知文件未在仓库公开。
维护起点为 Native 源码版本 0.2.3，提交
[`65bcafa2`](https://github.com/miik-su/MoonCrawler/commit/65bcafa2de6fef521d558b859a93a4308f631eaf)。
维护范围包括 URL、调度、Robots、静态 HTML、文件作业和 CLI。

| 事项 | 基线与验证方法 |
| --- | --- |
| 三平台 | 基线运行中 Ubuntu/Windows 成功，macOS 作业在执行任何步骤前即取消，取消原因未公开；此前的成功运行只对应其自身源码。[基线运行](https://github.com/miik-su/MoonCrawler/actions/runs/43604248613) |
| 快速开始 | 离线示例验证两条页面输出；回环 CLI 验证 Robots、去重、恢复和导出 |
| 许可与范围 | Apache-2.0，依赖分开声明，访问与数据权限另行确认。[契约](contracts.md) |
| 测试模型 | 以版本和场景定位合成负载、测试夹具、退出结果及其限制。[验证索引](verification.md) |
| 0.3.0 维护增量 | 有界 Sitemap 发现、选择器、条件重抓、运行指标及流式作业；见 [使用指南](user-guide.md) 与 [验证索引](verification.md) |

0.3.0 的定向编译、格式、接口、CLI 和包校验已经在三平台通过。
新增指标和解析改动的 macOS 15 ARM64 定向作业已在第二次运行通过。
[复跑结果及原始日志](../evidence/2026-11-28-macos-focused/README.md)
Sitemap、选择器、重抓、流式作业和诊断的边界见 [兼容矩阵](compatibility.md)。
独立进程测量、11 个强制终止阶段及历史报告见 [证据归档](../evidence/2026-11-26-0.3.0/README.md)。

专项覆盖引导与 Linux/ext4 五个虚拟断电场景已通过。[专项验证](../evidence/2026-11-26-specialized/README.md)
Windows 和 macOS ARM 均已完成六个持久化文件状态恢复场景。它们补充的是恢复逻辑证据，
物理掉电、NTFS/APFS 崩溃回放和设备缓存丢失仍未验证。[跨平台恢复模型](../evidence/windows-macos-power-loss-model/README.md)
Linux 受信证书的主机名匹配和不匹配专项已通过。[TLS 实测](../evidence/linux-tls-hostname/README.md)
Linux 系统 DNS 已检查 CNAME 最终 IPv4，CLI 已验证写满失败后能从同一作业完整导出。
[结果及原始日志](../evidence/linux-system-boundaries/README.md)
当前发布验收仍区分定向检查与全量测试。独立安全审计、机房真实负载及物理断电恢复
没有本轮认证结果。`miik-su/mooncrawler@0.3.0` 已于 2026-11-28 发布到 Mooncakes，
并在独立项目中验证安装和离线解析。[发布验证](../evidence/2026-11-28-mooncakes/README.md)
新增实现应同步维护 README、兼容矩阵和对应配置，用能区分故障与成功的关键测试验证。
