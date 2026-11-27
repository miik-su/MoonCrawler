# Mooncakes 0.3.0 发布验证

2026-11-28，公开发布 `miik-su/mooncrawler@0.3.0`。
[Mooncakes 包页面](https://mooncakes.io/docs/miik-su/mooncrawler)

| 步骤 | 实测结果 |
| --- | --- |
| 本地发布包检查 | 145 个归档条目。许可证、README 和核心源码存在，测试证书、探针及历史证据未打包。解包后 Native 检查通过，离线示例输出两页。 |
| `moon publish` | `miik-su` 账号正式发布。命令退出码 0，服务器返回 `200 OK`。 |
| 独立项目安装 | `moon update` 后用 `moon add miik-su/mooncrawler@0.3.0` 从注册表下载，依赖固定为 0.3.0。 |
| 独立项目调用 | Windows 上通过 `moon check --target native --deny-warn`，随后运行程序。公开 Parser API 从合成 HTML 提取的标题和正文均匹配断言。 |

关键命令输出：

```text
Server status: 200 OK
Downloading miik-su/mooncrawler@0.3.0
Mooncakes miik-su/mooncrawler@0.3.0: native consumer passed
```

本次验证覆盖注册表下载、Native 编译和离线解析，未执行全量测试。
