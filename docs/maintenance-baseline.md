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

新增实现应同步维护 README、兼容矩阵和对应配置，用能区分故障与成功的关键测试验证。
