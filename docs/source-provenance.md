# 代码、依赖与验证材料来源

核对日期：2026-11-14。本页记录来源和使用边界，不是全部依赖或未来二进制发行物的法律认证。
项目本身使用根目录 [Apache-2.0](../LICENSE)，版权仍属于相应贡献者，
不从仓库账号推定单一法律版权主体。

| 材料 | 来源及许可 | 本仓库的使用范围 |
| --- | --- | --- |
| 调度、策略、Engine、Storage、CLI | 本仓库 MoonBit 实现及提交历史，Apache-2.0 | 独立实现；依赖复用和设计参考另行列明 |
| Scrapy | [官方源码](https://github.com/scrapy/scrapy)，[BSD-3-Clause](https://github.com/scrapy/scrapy/blob/master/LICENSE) | 参考调度/去重/持久化职责和 retry/redirect/Robots 中间件分层概念；未移植其 Python 实现 |
| HTML DOM | moonbit-community/html 0.2.4，Apache-2.0 | 通过声明依赖调用上游 HTML5 解析器，本项目实现提取与预算适配层 |
| 异步与系统能力 | moonbitlang/async 0.22.5，Apache-2.0 | 使用上游 IO、DNS、进程和运行时；依赖内部 C/平台实现不计为本仓库原创 MoonBit 代码 |
| 日期辅助 | moonbitlang/x 0.5.7，元数据与文件头声明 Apache-2.0 | 使用 time 包；本机安装包缺根 LICENSE 文本，具体证据见依赖清单，不将包装缺口定性为已证实许可冲突 |
| 基础库 | moonbitlang/core 0.10.17+d971670cd，Apache-2.0 | 工具链附带标准库，按固定工具链验证 |
| 默认 HTTP/TLS 传输 | 外部 curl；[curl license](https://curl.se/docs/copyright.html) | 调用系统可执行文件，不在本仓库分发 curl、OpenSSL 或操作系统 TLS 库二进制 |
| MoonCrawl | [guangting0905/mooncrawl](https://github.com/guangting0905/mooncrawl)，仓库声明 Apache-2.0 | 本次选题查重的外部对照，不是移植来源；对照版本固定在 peer-comparison 文档 |
| pkg.generated.mbti | `moon info --target native` 生成 | API 摘要，不手工维护；CI 检查重新生成的差异 |
| 测试 HTML、URL、DNS 报文及任务模型 | 本仓库静态/合成夹具 | 使用 example 域名和本地服务；不包含从第三方网站采集的真实用户数据集或 AI 权重 |
| TLS 失败夹具 | openssl 在临时目录生成证书/密钥并启动 s_server | 避免调用上游标记 internal 的 TLS 服务器 API；校验 curl 的证书验证错误码 60；不提交静态私钥，结束后清理临时目录 |
| CI 结果 | 对应 Actions 作业的原始产物 | 保存源码 SHA、命令、退出码和 ZIP 摘要；不是全面安全认证 |

## AI 辅助与维护责任

本项目开发使用了 AI 辅助进行实现、测试、问题排查和文档整理。
维护者需要理解安全连接、任务状态、重试和持久化边界，检查输出来源，
并以可运行示例、工具链和回归结果验证行为。AI 生成不代表自动获得第三方授权，
也不能替代代码审查或将未运行的测试标为通过。

## 变更与发行检查

新增第三方代码时，应记录具体文件、版本/提交、许可证、修改范围和所需归属说明；
概念参考与源码复用分别描述。现有“未复制第三方源码”声明不自动涵盖未来变更。

若未来分发依赖源码或静态/动态链接二进制，应针对实际发行物重新核查许可文本、
NOTICE、链接库和修改说明。尤其应补全 x 安装包缺失的完整许可文本证据。
当前未发布 Mooncakes 包，不将本地打包或源码检查等同于发行合规认证。
