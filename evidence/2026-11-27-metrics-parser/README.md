# 作业指标和 HTML 文本提取验证

2026-11-27，在 Windows 本地从干净源码树运行定向测试。被测提交
[`79ed099`](https://github.com/miik-su/MoonCrawler/commit/79ed09927e1e50a55dec98141be41eb86229a200)。

| 检查 | 实际结果 | 原始输出 |
| --- | --- | --- |
| `moon test parser/selector_test.mbt parser/parser_test.mbt parser/extreme_test.mbt --target native --deny-warn` | 5 项通过。覆盖 1,500 层嵌套文本的顺序、原有选择器功能、正常解析和结构输入过大时拒绝。 | [parser.log](parser.log) |
| `moon run tools/cli_smoke.mbtx` | 成功退出。用回环 HTTP 合成作业比较 JSON 统计与 Prometheus 文本中的页面和任务结果，检查零值状态和输出中无站点 URL，并验证原有导出、重抓及站点地图路径。 | [cli.log](cli.log) |

Prometheus 文本是已保存作业的快照。此验证检查 CLI 输出，未运行 Prometheus 采集端。
HTML 深层嵌套场景验证文本提取顺序；DOM 构建仍使用上游解析器和输入预检，
这些结果不能给出构建阶段的硬内存上限。

[被测提交的定向 CI](https://github.com/miik-su/MoonCrawler/actions/runs/46019109974)。
本记录仅列出上表中的本地结果。本轮未执行全量测试。
