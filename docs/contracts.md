# 软件许可、协议与运行边界

| 范围 | 项目约定 |
| --- | --- |
| 源码许可 | [Apache-2.0](../LICENSE)，保留 [NOTICE](../NOTICE)、相应版权、第三方归属及适用的修改说明 |
| 依赖和参考 | 依赖适用各自许可证，设计参考与代码复用分别列明。[第三方声明](../THIRD_PARTY_NOTICES.md) |
| 站点访问和数据 | 操作者负责确认访问与再利用权限、遵守网站条款并保护 URL、正文及导出数据。[使用指引](acceptable-use.md) |
| Robots | 遵循已实现的规则匹配与缓存策略。公网站点跳转仍受主机授权、连接目标和降级限制。Robots 规则不授予访问权限。[RFC 9309](https://www.rfc-editor.org/rfc/rfc9309.html) |
| HTTP | 默认路径使用固定 IPv4 目标的 curl 传输，逐跳检查重定向。HTML 提取要求 `text/html` 或 `application/xhtml+xml`，后者也交给 HTML5 提取器。[RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.html) |
| 恢复与资源 | 单进程作业，存储和解析有独立预算。Reader 按需导出，Engine 仍保留页面。进程中断证据对应特定恢复阶段，停电持久性尚待验证。[兼容矩阵](compatibility.md) |
| 扩展与运维 | 自定义 UnsafeFetcher、Parser、Processor、Storage、作业目录和指定的 curl 可执行文件来自可信管理者。项目不提供插件沙箱或 SLA。[安全策略](../SECURITY.md) |
| 数据模型与样本 | `Request`、`Task`、`Page` 为项目数据结构。队列、DNS、TLS、HTML 与存储模型使用合成或本地夹具，项目未分发 AI 模型权重。[来源清单](source-provenance.md) |

使用指引不修改 Apache-2.0。抓取数据不会因流经软件而自动获得软件许可证。
发行包含外部二进制时应核对实际分发内容、上游许可文本和通知义务。
