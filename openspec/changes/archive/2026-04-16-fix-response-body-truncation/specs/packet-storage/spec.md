## MODIFIED Requirements

### Requirement: 大 Body 截断
系统 SHALL 对超过 100KB 的请求体进行截断，只存储前 100KB 并在截断处附加截断标注；对于文本响应体，系统 SHALL 完整存储捕获到的响应内容，不因 100KB 阈值截断；对于非文本响应体，系统 SHALL 不存储 body 内容，仅保留元数据。

#### Scenario: 请求体超过 100KB
- **WHEN** 请求体字节数超过 100 * 1024 字节
- **THEN** 系统只存储前 100KB 内容，并在末尾追加字符串 `"[TRUNCATED]"`

#### Scenario: 文本响应体超过 100KB
- **WHEN** 响应 Content-Type 为文本类型，且响应体字节数超过 100 * 1024 字节
- **THEN** 系统完整存储响应体内容，不附加 `"[TRUNCATED]"`

#### Scenario: 非文本响应体
- **WHEN** 响应 Content-Type 为 `image/*`、`application/octet-stream` 或其他非文本类型
- **THEN** 系统不存储响应体文本内容，`responseBody` 为空字符串，`responseCode`、`responseHeaders` 和 `responseSize` 正常记录
