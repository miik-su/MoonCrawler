# MoonCrawler 使用指南

从源码运行见 [README](../README.md)。依赖下载完成后，离线示例不访问外部站点。
真实抓取前先向站点所有者确认允许的范围、请求频率和数据保留要求。

1. 用 `init` 创建新配置，将 `allowed_hosts` 填成授权的精确主机名。
   子域名需单独加入。保留 `robots: true`，按站点要求调低并发、增加请求间隔。
2. 用 `validate` 检查配置，给 `crawl` 指定新作业目录和一个或多个种子。
   `max_pages` 限制发现的任务总数，包含失败、跳过和被 Robots 禁止的任务。
3. `status` 读取最近保存的任务状态和错误，`stats` 汇总尝试及重试。
   一次任务尝试可能包含 Robots 或多跳请求，计数不能当作实际 HTTP 请求数。
4. `pause` 是协作请求。在途请求可能继续，等待原进程退出后再运行
   `resume` 或 `export`。续跑会读取同一作业的持久化配置和状态。
5. 将 JSONL 导出到新的输出路径。导出过程中出错可能留下部分输出，
   应检查进程结果并使用新路径重试。作业目录和导出文件可能含 URL、查询
   参数、正文及错误信息，只向获准访问的人开放。

## 从站点地图开始

对已授权站点选择其中一个入口：

```sh
moon run cmd/mooncrawler --target native -- crawl-sitemap config.json data/map https://example.com/sitemap.xml
moon run cmd/mooncrawler --target native -- crawl-robots config.json data/robots https://example.com/
```

两者使用独立的新作业目录。站点地图、索引与重定向限定在同源范围内，
URL set 的页面还需位于地图所在路径目录之下。发现的页面按深度 0 入队，
实际访问时仍检查 Robots。默认抓取命令不会自动下载站点地图。
单次发现上限为 16 个地图、2 层索引边、合计 10,000 个位置和 60 秒，
单份解码响应最多 1 MiB，同时受配置中更小的正文上限约束。
XML 处理支持标准默认命名空间、`urlset`、`sitemapindex` 和五种预定义实体。
外部实体、DTD、CDATA、文本地图、独立 gzip 文件和跨源发现不在当前范围。
[Sitemap 规范](https://www.sitemaps.org/protocol.html)

## 条件重抓

```sh
moon run cmd/mooncrawler --target native -- recrawl config.json data/round2 data/job https://example.com/
moon run cmd/mooncrawler --target native -- resume-recrawl data/round2 data/job
```

上一轮与本轮需要相同的保存配置。重抓期间以前一作业为只读、持锁的来源，
并把结果写入新作业。仅对同一规范 URL 发送可用的 ETag 或 Last-Modified；
有效 304 复用上一轮处理后的页面，普通 200 重新解析，未发送条件的 304 拒绝。
含 `Vary` 或 `Cache-Control: no-store` 的页面不登记可重用验证器。
抓取文件仍按作业的存储与数据保留规则保存。指纹仅供诊断，
复用决策以收到的条件响应为准。用库自定义解析器或处理流程时，
跨轮复用必须使用同一套规则。[HTTP 条件请求](https://www.rfc-editor.org/rfc/rfc9110.html#section-13)

## 选择器与指标

库调用方可以将 `SelectorParser::new` 的实例传给 `Engine::new(parser=...)`，
最多配置 32 个字段。表达式为标签名、`.class`、`#id` 或 `[attribute]`，
每个字段只取第一个匹配元素的文本或指定属性，单值最多 4,096 个代码单位，
结果写入 `extract.<name>`。CLI 使用内建提取器。

设置 `MOONCRAWLER_JSON_METRICS=1` 后，抓取命令在结果末尾追加一个 JSON 对象。
网络计数包括 Robots 与 Sitemap，按引擎进程累计；`task_retries_started`
来自作业任务尝试次数。传输平均时长使用单调计时，`stored_page_bytes`
为最新页面的序列化大小。它们都不是进程内存或唯一访问次数。

| 现象 | 处理 |
| --- | --- |
| 默认配置校验失败 | 填入精确授权域名，不必开启任意公共主机访问 |
| curl 无法运行 | 检查 `curl --version`；`MOONCRAWLER_CURL` 只引用可信可执行文件 |
| 重定向中止 | 检查目标的主机、路径、文件限制和 Robots；保持访问范围约束 |
| 暂时出现 Robots 错误 | 查看保存的错误与重试状态，保留服务器要求的等待时间 |
| 证书校验失败 | 检查站点证书链、主机名和本机信任根 |
| 作业占用锁 | 等待原进程退出，再恢复或导出 |
| 内容类型或编码不支持 | 查看响应的 Content-Type；HTML 默认仅进入指定媒体类型的提取流程 |

见 [配置](configuration.md)、[兼容矩阵](compatibility.md) 及[契约](contracts.md)。
