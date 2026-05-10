## ADDED Requirements

### Requirement: cURL 命令基本结构
系统 SHALL 按照以下顺序生成 cURL 命令：URL（首位）→ HTTP 方法（可选）→ 请求头 → `--compressed`（可选）→ 请求体（可选）→ `--proxy`（可选，末位）。

#### Scenario: 标准命令结构
- **WHEN** 调用 `ArgosCurlBuilder.build(record)` 且请求方法为 POST
- **THEN** 生成命令以 `curl 'URL'` 开头，依次包含 `-X POST`、各 `-H` 参数，URL 紧跟 `curl` 之后

#### Scenario: URL 位于命令开头
- **WHEN** 调用 `ArgosCurlBuilder.build(record)`
- **THEN** URL 出现在 `curl` 关键字之后的第一个参数位置，格式为 `curl 'URL'`

### Requirement: GET 请求省略 -X 参数
系统 SHALL 对 HTTP GET 请求不输出 `-X GET`，因为 curl 默认方法即为 GET。

#### Scenario: GET 请求无 -X 标志
- **WHEN** `record.method` 为 `GET`（大小写不敏感）
- **THEN** 生成的命令中不包含 `-X GET` 或任何 `-X` 参数

#### Scenario: 非 GET 请求包含 -X 标志
- **WHEN** `record.method` 为 `POST`、`PUT`、`DELETE`、`PATCH`、`OPTIONS` 等
- **THEN** 生成的命令中包含 `-X <METHOD>`

### Requirement: 请求头格式
系统 SHALL 将每个请求头以 `-H 'Key: Value'` 形式单独一行输出，value 中的单引号需转义。

#### Scenario: 多个请求头各自独占续行
- **WHEN** `record.requestHeaders` 包含多个 key-value 对
- **THEN** 每个 header 前有 ` \\\n` 续行符，格式为 `-H 'Key: Value'`

#### Scenario: Value 中含单引号时转义
- **WHEN** 某请求头的 value 包含单引号字符 `'`
- **THEN** 该单引号被替换为 `'\''`（shell 单引号转义序列）

### Requirement: --compressed 标志
系统 SHALL 当请求头 `Accept-Encoding` 包含 `gzip` 时自动追加 `--compressed` 标志。

#### Scenario: Accept-Encoding 含 gzip 时追加 --compressed
- **WHEN** `record.requestHeaders` 中存在 `accept-encoding`（大小写不敏感）且其值包含 `gzip`
- **THEN** 生成命令中包含 `--compressed` 参数

#### Scenario: 无 gzip 时不追加
- **WHEN** 请求头中无 `Accept-Encoding` 或其值不包含 `gzip`
- **THEN** 生成命令中不包含 `--compressed`

### Requirement: JSON 请求体格式化
系统 SHALL 对 `Content-Type` 为 `application/json` 的请求体尝试 pretty-print 格式化（2 空格缩进）；若解析失败则回退为原始字符串。

#### Scenario: 有效 JSON body 被格式化
- **WHEN** `record.requestBody` 是合法的 JSON 字符串且请求头 `Content-Type` 包含 `application/json`
- **THEN** `--data-raw` 参数中的 body 为 2 空格缩进的 pretty-print JSON

#### Scenario: 非 JSON body 原样输出
- **WHEN** `record.requestBody` 不是合法 JSON 或 Content-Type 不包含 `json`
- **THEN** `--data-raw` 参数中的 body 与 `record.requestBody` 内容一致（转义单引号后）

#### Scenario: 空 body 不输出 --data-raw
- **WHEN** `record.requestBody` 为空字符串
- **THEN** 生成命令中不包含 `--data-raw` 参数

### Requirement: --proxy 可选参数
系统 SHALL 在 `ArgosCurlBuilder.build()` 中支持可选的 `proxy` 命名参数；若传入非空值，则在命令末尾追加 `--proxy <proxy>`。

#### Scenario: 传入 proxy 时追加 --proxy
- **WHEN** 调用 `ArgosCurlBuilder.build(record, proxy: 'http://localhost:9091')`
- **THEN** 生成命令末尾包含 `--proxy http://localhost:9091`

#### Scenario: 不传 proxy 时无 --proxy
- **WHEN** 调用 `ArgosCurlBuilder.build(record)`（不传 proxy 参数）
- **THEN** 生成命令中不包含 `--proxy`
