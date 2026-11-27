# Linux TLS 主机名专项验证

2026-11-27，被测源码 [`0fca8e0`](https://github.com/miik-su/MoonCrawler/commit/0fca8e0e20bd9313ba06ff28191b0bd5167b09fb)。
Ubuntu 24.04 的定向 CI 通过，测试使用真实 MoonCrawler CLI、curl 与本地 OpenSSL 服务。
[Ubuntu 作业](https://github.com/miik-su/MoonCrawler/actions/runs/45973991613/job/140421059406)

| 请求 | 结果 |
| --- | --- |
| 信任临时证书，按证书 SAN 中的 `localhost` 访问 | CLI 保存 1 页 |
| 同一临时证书和服务，按 SAN 未列出的 `127.0.0.1` 访问 | CLI 报协议错误，保存 0 页，独立 curl 探针返回 60 |

[原始测试输出](tls-hostname.log) · [命令、源码与产物摘要](results.json)。
测试只覆盖 Linux 回环和这个 curl/OpenSSL 环境。证书只在子进程内信任，
未导入系统信任库。本轮没有验证 Windows/macOS TLS 后端、公共 CA 互操作或完整 TLS 矩阵。

Windows CI 此轮首次出现官方安装脚本内容变更，被原摘要检查拦截。
审查确认脚本保留固定版本下载路径，并加入暂存、排他锁与回滚后，更新了 Windows 摘要，
Unix 摘要及工具链版本保留。[摘要修复](https://github.com/miik-su/MoonCrawler/commit/17b0bf8e0e8efaad9d867a114c2056b705288794) ·
[修复后定向 CI](https://github.com/miik-su/MoonCrawler/actions/runs/45974204300)。
新摘要下的 Windows 和 Ubuntu 定向作业均通过，归档时 macOS 15 作业仍在排队。
