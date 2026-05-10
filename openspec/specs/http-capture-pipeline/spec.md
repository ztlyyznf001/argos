## ADDED Requirements

### Requirement: HttpOverrides 正确包装为 ArgosHttpClient
系统 SHALL 在 `ArgosHttpOverrides.createHttpClient()` 中将底层 `HttpClient` 包装为 `ArgosHttpClient`，使所有 HTTP 请求都经过监控拦截链路。

#### Scenario: 所有 HTTP 请求被拦截
- **WHEN** 应用发起任意 HTTP/HTTPS 请求（GET、POST、PUT、DELETE 等）
- **THEN** 请求经过 `ArgosHttpClient` → `ArgosHttpClientRequest` → `ArgosHttpClientResponse` 完整链路，请求头、请求体、响应码、响应头、响应体均被捕获

#### Scenario: 代理配置在包装后仍生效
- **WHEN** `ArgosHttpMonitor.instance.customProxy` 设置了代理地址
- **THEN** 包装后的 `ArgosHttpClient` 内部 `origin` 上的 `findProxy` 使用该代理，请求流量路由到指定代理

### Requirement: 请求耗时完整记录
系统 SHALL 在响应接收完成时写入 `endTimestamp`，使 `ArgosPacketRecord.durationMs` 返回真实耗时。

#### Scenario: 正常响应记录耗时
- **WHEN** 一次 HTTP 请求成功收到响应
- **THEN** `ArgosHttpInfo.response.endTimestamp` 为响应接收时的 Unix 毫秒时间戳，`durationMs = endTimestamp - startTimestamp > 0`

#### Scenario: 请求失败时耗时有效
- **WHEN** 一次 HTTP 请求因网络错误或超时失败
- **THEN** `endTimestamp` 记录为错误发生时的时间戳，`durationMs > 0`

### Requirement: 错误请求被捕获并上报
系统 SHALL 在请求发生网络错误（连接失败、超时、DNS 解析失败）时将错误信息写入 `ArgosHttpInfo.error` 并触发与正常响应相同的存储和 listener 回调。

#### Scenario: 网络错误时写入存储
- **WHEN** 一次 HTTP 请求抛出异常（如 `SocketException`、`TimeoutException`）且 `enableStorage` 为 `true`，且 host 在白名单中
- **THEN** 该记录以 `responseCode = 0`、`responseBody = ''`、`error` 字段非空的形式存入 MMKV

#### Scenario: 网络错误时触发 listener
- **WHEN** 一次 HTTP 请求抛出异常，且 host 在 `hostWhiteList` 中，且 `listener` 不为 null
- **THEN** `ArgosManager.instance.listener` 被调用，参数为携带 `error` 字段的 `ArgosHttpInfo` 实例

### Requirement: 非文本响应只记录元数据
系统 SHALL 对非文本 Content-Type（图片、二进制、音视频等）不采集响应体内容，仅记录状态码、响应头和响应大小。

#### Scenario: 图片响应不写入响应体
- **WHEN** 响应 Content-Type 为 `image/*`、`application/octet-stream` 等非文本类型
- **THEN** 存储记录中 `responseBody` 为空字符串，`responseCode` 和 `responseSize` 正常记录，不记录乱码或错误提示

#### Scenario: JSON 响应正常采集
- **WHEN** 响应 Content-Type 包含 `json`
- **THEN** 响应体文本被完整采集（上限 100KB 由截断机制保障）

### Requirement: recordResponse 幂等化
系统 SHALL 保证同一次 HTTP 请求的 `recordResponse` 回调只被触发一次，防止 `listen()` 与 `transform()` 两条路径造成重复记录。

#### Scenario: 重复触发时只记录第一次
- **WHEN** `ArgosHttpClientResponse` 的 `listen()` 与 `transform()` 均被调用（如某些 HTTP 库同时使用两个接口）
- **THEN** MMKV 中该请求只存在一条记录，listener 只被回调一次

### Requirement: 无 body 请求的请求头捕获
系统 SHALL 在 `ArgosHttpClientRequest.close()` 调用时将当前请求头赋给 `httpInfo.request.header`，确保 GET 等无 body 请求的请求头被完整记录。

#### Scenario: GET 请求头被捕获
- **WHEN** 一个 GET 请求通过 `ArgosHttpClient` 发出，请求完成（`close()` 被调用）
- **THEN** `ArgosPacketRecord.requestHeaders` 包含该请求的完整请求头（非空 Map）

#### Scenario: POST 请求头被捕获
- **WHEN** 一个 POST 请求通过 `ArgosHttpClient` 发出，请求体通过 `add()` 写入
- **THEN** `ArgosPacketRecord.requestHeaders` 包含该请求的完整请求头（与 GET 行为一致）

### Requirement: 运行时抓包开关
`ArgosManager` SHALL 提供可写属性 `captureEnabled`（`bool`），初始值由 `ArgosConfig.enableStorage` 决定。`_dispatchHttpInfo` SHALL 在 `captureEnabled` 为 `false` 时跳过存储写入和 listener 回调。

#### Scenario: 关闭开关后请求不被记录
- **WHEN** `ArgosManager.instance.captureEnabled` 被设为 `false`，之后发生 HTTP 请求
- **THEN** 该请求不写入 MMKV，listener 不被回调

#### Scenario: 重新开启后请求恢复记录
- **WHEN** `ArgosManager.instance.captureEnabled` 被设回 `true`，之后发生 HTTP 请求
- **THEN** 该请求正常写入 MMKV（如 enableStorage 为 true），listener 正常回调

#### Scenario: 初始值与 enableStorage 一致
- **WHEN** `ArgosManager.instance.init(config: ArgosConfig(enableStorage: true))` 被调用
- **THEN** `ArgosManager.instance.captureEnabled` 初始值为 `true`

#### Scenario: enableStorage 为 false 时初始值也为 false
- **WHEN** `ArgosManager.instance.init(config: ArgosConfig(enableStorage: false))` 被调用
- **THEN** `ArgosManager.instance.captureEnabled` 初始值为 `false`
