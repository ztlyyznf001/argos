## MODIFIED Requirements

### Requirement: cURL 命令基本结构
系统 SHALL 按照以下顺序生成 cURL 命令：URL（首位）→ HTTP 方法（可选）→ 请求头 → `--compressed`（可选）→ 请求体（可选）→ `--proxy`（可选，末位）。

#### Scenario: 标准命令结构
- **WHEN** 调用 `ArgosCurlBuilder.build(record)` 且请求方法为 POST
- **THEN** 生成命令以 `curl 'URL'` 开头，依次包含 `-X POST`、各 `-H` 参数，URL 紧跟 `curl` 之后

#### Scenario: URL 位于命令开头
- **WHEN** 调用 `ArgosCurlBuilder.build(record)`
- **THEN** URL 出现在 `curl` 关键字之后的第一个参数位置，格式为 `curl 'URL'`

### Requirement: --proxy 可选参数
系统 SHALL 在 `ArgosCurlBuilder.build()` 中支持可选的 `proxy` 命名参数；若传入非空值，则在命令末尾追加 `--proxy <proxy>`。

#### Scenario: 传入 proxy 时追加 --proxy
- **WHEN** 调用 `ArgosCurlBuilder.build(record, proxy: 'http://localhost:9091')`
- **THEN** 生成命令末尾包含 `--proxy http://localhost:9091`

#### Scenario: 不传 proxy 时无 --proxy
- **WHEN** 调用 `ArgosCurlBuilder.build(record)`（不传 proxy 参数）
- **THEN** 生成命令中不包含 `--proxy`
