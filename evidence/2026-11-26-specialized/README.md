# 覆盖引导与断电恢复专项验证

[专项 GitHub Actions](https://github.com/miik-su/MoonCrawler/actions/runs/45757555196)
· [Windows、Ubuntu、macOS 定向回归](https://github.com/miik-su/MoonCrawler/actions/runs/45757555206)

## 覆盖反馈

运行 `moon run tools/coverage_guided.mbtx`。每个输入由单独的 Native 子进程解析，
超时为 5 秒。输入均为项目自建的短合成文本，无网络操作。
13 个初始输入加 240 次变异。统计范围只包括各目标自身包的编译器计数位。

| 目标 | 种子命中 | 变异后命中 | 新语料 | 使用新语料变异次数 |
| --- | ---: | ---: | ---: | ---: |
| URL | 112 | 126 | 8 | 34 |
| Robots | 95 | 99 | 3 | 20 |
| HTTP 响应解码 | 68 | 72 | 4 | 18 |
| HTML | 97 | 102 | 2 | 11 |
| Sitemap | 118 | 140 | 9 | 37 |
| 合计 | 490 | 539 | 26 | 120 |

上表为 Windows 的实际运行，[原始 JSON](fuzz-windows.json)记有命令、工具链和源码 SHA。
修复后 Linux 使用相同的构建选项和种子，得到相同的计数与语料结果。
[Linux 原始 JSON](linux/coverage-guided/result.json)
253 个输入中 134 个被处理、119 个被正常拒绝，子进程崩溃和超时均为零。
Robots 和 HTML 采用容错解析，处理输入不代表其语法有效。计数位数量不等于覆盖率百分比。
测试只涉及有限的 ASCII 文本变异，未衡量网络传输、TLS、第三方 DOM 全分支或生产负载。

## 首次断电检查发现的问题

首次运行在 `e1811a7` 上完成了 `event_staged` 的切断与恢复。
`event_published` 发出切断信号后，重启验证读到 0 页，预期为 1 页。
验收断言未通过，旧运行器继续等待成功信号并超时。
[首次 CI 与串口产物](https://github.com/miik-su/MoonCrawler/actions/runs/45756502474)

修复改用运行时 Linux 平台识别，在同步文件后、确认重命名发布前同步作业目录。
来宾恢复断言失败时现在会发送单独的失败信号。
[修复提交](https://github.com/miik-su/MoonCrawler/commit/fc429440740bb1fb0ae6c5eccf0a7099d444fb72)
· [文件与目录同步语义](https://man7.org/linux/man-pages/man2/fsync.2.html)

修复后的第一次虚拟机启动遇到 Azure 来宾内核早期内存不足，未进入测试。
随后把来宾配置提高到 1 GiB、固定单 CPU。
[启动失败作业](https://github.com/miik-su/MoonCrawler/actions/runs/45757083994)

## 修复后虚拟断电结果

源码 [`eefecac`](https://github.com/miik-su/MoonCrawler/commit/eefecacabaea9c6c98ef20dbd0cc909821d11716)。
Linux `7.0.0-1018-aws`、QEMU 8.2.2、raw virtio 磁盘、ext4，
`cache=none`，来宾单 CPU 与 1 GiB 内存。
每个场景独立创建磁盘镜像并同步初始作业。读取到写入阶段串口信号后，
宿主用 SIGKILL 终止 QEMU，再从同一镜像引导新来宾。

| 切断点 | 重启验证 |
| --- | --- |
| WAL 临时文件已同步、尚未发布 | 通过，未发布任务和页均未出现 |
| WAL 已发布 | 通过，恢复 1 个已完成任务和 1 页，正文一致 |
| 检查点分片已发布 | 通过，从有效状态恢复相同任务和页 |
| 检查点索引已发布 | 通过，恢复相同任务和页 |
| 开始删除旧记录后 | 通过，恢复相同任务和页 |

[机器可读结果](linux/power-cut/result.json) · [切断与重启串口日志](linux/power-cut)。
专项产物 ID 为 `15087783490`。下载后的 ZIP SHA-256 与 GitHub 记录一致，
`c8305db2027f6be88292954e1d1fd418028f0a99eb4508113618d8568b0a2c9e`。

验证覆盖来宾突然停止和 ext4 日志恢复。宿主保持通电，测试范围不包含物理掉电、
控制器或磁盘固件缓存丢失、虚报持久化、其他文件系统或 Windows/macOS 断电。
初始作业目录已存在且已同步，新建祖先目录的持久化不在范围。全量测试和 Mooncakes 发布未执行。
