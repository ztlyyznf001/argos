# http-capture-pipeline Specification

## Purpose

定义 HTTP 抓包主链路的行为：如何通过 `HttpOverrides` 拦截全部请求、如何完整记录请求耗时与错误、如何处理非文本响应与重复上报，以及运行时抓包开关的作用范围。

## Requirements

### Requirement: HTTP 事件经统一 dispatch
正常响应与网络错误 SHALL 先转换为 `ArgosPacketRecord`，再通过 `ArgosManager.dispatch` 接受录制门控、会话关联、listener 回调和可选持久化。HTTP monitor MUST NOT 绕过 manager 直接写入 `ArgosPacketStorage`。

#### Scenario: 正常请求绑定活动会话
- **WHEN** recording 会话中一次 HTTP 请求成功完成
- **THEN** 该请求经统一 dispatch 获得 activeSession.id 与下一 sequence，再按配置进入 listener 和存储

#### Scenario: 错误请求绑定活动会话
- **WHEN** recording 会话中一次 HTTP 请求因网络错误结束
- **THEN** 错误记录与正常请求使用同一 dispatch 路径，并带有 activeSession.id、sequence 和非空 error

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
系统 SHALL 在请求发生网络错误（连接失败、超时、DNS 解析失败）时将错误信息写入 `ArgosHttpInfo.error`，并在 recording 会话中通过与正常响应相同的统一 dispatch 触发 listener 和可选持久化。

#### Scenario: 网络错误时写入所属会话
- **WHEN** recording 会话中一次 HTTP 请求抛出异常、enableStorage 为 true，且请求满足既有 host 规则
- **THEN** 记录以 responseCode 为 0、responseBody 为空、error 非空的形式写入诊断存储，并携带 activeSession.id 与 sequence

#### Scenario: 网络错误时触发 listener
- **WHEN** recording 会话中一次 HTTP 请求抛出异常，host 在 hostWhiteList 中且 listener 不为 null
- **THEN** listener 被调用，参数为携带 error 与对应事件元数据的 ArgosHttpInfo

### Requirement: 非文本响应只记录元数据
系统 SHALL 对非文本 Content-Type（图片、二进制、音视频等）不采集响应体内容，仅记录状态码、响应头和响应大小。

#### Scenario: 图片响应不写入响应体
- **WHEN** 响应 Content-Type 为 `image/*`、`application/octet-stream` 等非文本类型
- **THEN** 存储记录中 `responseBody` 为空字符串，`responseCode` 和 `responseSize` 正常记录，不记录乱码或错误提示

#### Scenario: JSON 响应正常采集
- **WHEN** 响应 Content-Type 包含 `json`
- **THEN** 响应体文本被完整采集（上限 100KB 由截断机制保障）

### Requirement: recordResponse 幂等化
系统 SHALL 保证同一次 HTTP 请求的 `recordResponse` 回调只被统一 dispatch 接受一次，防止 `listen()` 与 `transform()` 两条路径造成重复记录、重复 listener 或重复消耗 sequence。

#### Scenario: 重复触发时只记录第一次
- **WHEN** 同一请求的 `ArgosHttpClientResponse.listen()` 与 `transform()` 均触发 recordResponse
- **THEN** 所属会话只存在一条记录、listener 只回调一次、该请求只消耗一个 sequence

### Requirement: 无 body 请求的请求头捕获
系统 SHALL 在 `ArgosHttpClientRequest.close()` 调用时将当前请求头赋给 `httpInfo.request.header`，确保 GET 等无 body 请求的请求头被完整记录。

#### Scenario: GET 请求头被捕获
- **WHEN** 一个 GET 请求通过 `ArgosHttpClient` 发出，请求完成（`close()` 被调用）
- **THEN** `ArgosPacketRecord.requestHeaders` 包含该请求的完整请求头（非空 Map）

#### Scenario: POST 请求头被捕获
- **WHEN** 一个 POST 请求通过 `ArgosHttpClient` 发出，请求体通过 `add()` 写入
- **THEN** `ArgosPacketRecord.requestHeaders` 包含该请求的完整请求头（与 GET 行为一致）

### Requirement: 运行时抓包开关
`ArgosManager` SHALL 保留可写属性 `captureEnabled`，其值 SHALL 等于诊断会话状态是否为 recording。该属性 SHALL 对网络、原生网络、crash、jank 和 resource 事件使用同一录制门控；设为 false 暂停当前会话，设回 true 恢复该会话，idle 时设为 true 则创建新会话。默认 automatic 模式下，首次 init 的初始值仍由 enableStorage 决定；manual 模式初始值为 false。

#### Scenario: 关闭开关后请求不被记录
- **WHEN** recording 会话中将 captureEnabled 设为 false，之后发生 HTTP 请求
- **THEN** 该请求不进入 listener、不写入存储且不消耗 sequence，activeSession 以 paused 状态保留

#### Scenario: 重新开启后请求恢复到同一会话
- **WHEN** paused 会话中将 captureEnabled 设回 true，之后发生 HTTP 请求
- **THEN** 该请求写入原 activeSession，并获得暂停前最后 sequence 的下一个值

#### Scenario: 自动模式初始值与 enableStorage 一致
- **WHEN** 使用默认 automatic 模式和 enableStorage true 初始化 ArgosManager
- **THEN** 系统自动开始会话且 captureEnabled 初始值为 true

#### Scenario: enableStorage 为 false 时保持兼容初始值
- **WHEN** 使用默认 automatic 模式和 enableStorage false 初始化 ArgosManager
- **THEN** captureEnabled 初始值为 false且不自动创建会话

#### Scenario: manual 模式不自动录制
- **WHEN** 使用 sessionMode manual 和 enableStorage true 初始化 ArgosManager
- **THEN** captureEnabled 初始值仍为 false，直到显式开始会话
