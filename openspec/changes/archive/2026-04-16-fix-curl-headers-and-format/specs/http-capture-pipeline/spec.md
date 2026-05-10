## ADDED Requirements

### Requirement: 无 body 请求的请求头捕获
系统 SHALL 在 `KurilHttpClientRequest.close()` 调用时将当前请求头赋给 `httpInfo.request.header`，确保 GET 等无 body 请求的请求头被完整记录。

#### Scenario: GET 请求头被捕获
- **WHEN** 一个 GET 请求通过 `KurilHttpClient` 发出，请求完成（`close()` 被调用）
- **THEN** `KurilPacketRecord.requestHeaders` 包含该请求的完整请求头（非空 Map）

#### Scenario: POST 请求头被捕获
- **WHEN** 一个 POST 请求通过 `KurilHttpClient` 发出，请求体通过 `add()` 写入
- **THEN** `KurilPacketRecord.requestHeaders` 包含该请求的完整请求头（与 GET 行为一致）
