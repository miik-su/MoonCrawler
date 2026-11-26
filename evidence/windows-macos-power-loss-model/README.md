# Windows／macOS 持久化状态恢复模型

被测源码为 [`effdc2a`](https://github.com/miik-su/MoonCrawler/commit/effdc2a00185fb9bfdaeb46e2e783948e8f58d90)。
[GitHub Actions](https://github.com/miik-su/MoonCrawler/actions/runs/45789911336)

| 平台 | 归档时状态 |
| --- | --- |
| Windows Server 2022 | 6/6 通过。[执行日志](windows-2022/power-loss-model.log) · [源码与命令](windows-2022/results.json) |
| macOS 15 ARM | 未分配运行器，三个作业均在执行前取消，0 项测试执行。[首个作业](https://github.com/miik-su/MoonCrawler/actions/runs/45789911336/job/139806031667) |
| macOS 26 ARM | 三次尝试均在分配运行器前取消，0 项测试执行。[第三次作业](https://github.com/miik-su/MoonCrawler/actions/runs/45790818641/job/139901622406) |

Windows 原始结果来自产物 `15101823484`，下载 ZIP 的 SHA-256 已校验，
`a3b59de6744100f6bb713f95dd3ddc56eac7d7f223c596177777f61256e83e85`。
macOS Intel 候补在安装固定 MoonBit 工具链时返回 `Unsupported platform: Darwin x86_64`，
没有运行测试。候补工作流已改为 ARM。
[Intel 候补日志](https://github.com/miik-su/MoonCrawler/actions/runs/45790563046)

[macOS ARM 作业元数据](macos-arm-job-status.json)保留各作业链接、源码、时间戳、
取消状态、空执行步骤和日志接口结果。六个 ARM 作业均在等待约 15 分钟后取消，
日志接口均返回 `NOT_FOUND`。因此没有 macOS 恢复测试的原始输出，亦无通过或失败判定。
第二、三次尝试均只重跑 macOS 候补作业。当前工作站为 x64 Windows，未发现已配置的
macOS ARM 主机或可直接使用的账户环境。

执行命令：

```sh
moon test storage/power_loss_model_test.mbt --target native --deny-warn
```

每个场景在临时目录中由真实 FileStore 写出检查点和 WAL，关闭写入器后，
只改动该夹具中的文件，再用 FileStore 打开并断言任务和页面结果。

| 注入的持久化状态 | Windows 实测行为 |
| --- | --- |
| 日志只留在未发布的临时文件 | 忽略该文件，保留旧快照 |
| 最后一条已发布 WAL 消失，无更晚记录 | 恢复旧快照；没有序列缺口信号，不能察觉尾条丢失 |
| 中间 WAL 消失，更晚记录仍在 | 明确拒绝有序列缺口的作业 |
| 已发布 WAL 截断 | 拒绝读取 |
| 索引丢失最新版本，旧 WAL 仍在 | 通过重放恢复已完成任务与正文 |
| 索引回退为初始空快照，旧 WAL 已清理 | 会读取旧快照，已提交数据不再可见；此组合可无告警回退 |

## 验证边界

这是在对应操作系统上验证 MoonCrawler 如何处理指定的文件状态，不能据此推断
这些状态在断电时会不会出现。模型未切断两端的虚拟机或物理设备，未验证 NTFS/APFS
崩溃回放、设备写缓存、驱动、控制器及固件行为。Windows 和 macOS 当前复用文件同步路径，
Linux 作业目录同步与 ext4 的验证范围单独记录。
[Linux/ext4 虚拟断电报告](../2026-11-26-specialized/README.md)

当前没有可用的专用 Windows 或 macOS 断电测试 VM。GitHub 托管 arm64 macOS
运行器不支持嵌套虚拟化。实机测试需要专用可丢弃环境，不能通过关闭共享运行器完成。
[GitHub 托管运行器限制](https://docs.github.com/en/actions/reference/runners/github-hosted-runners#limitations-for-arm64-macos-runners)

未运行全量测试，Mooncakes 继续暂缓。
