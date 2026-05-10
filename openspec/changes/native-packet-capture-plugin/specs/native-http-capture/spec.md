## ADDED Requirements

### Requirement: iOS NSURLProtocol 拦截原生请求
系统 SHALL 在 `ArgosNativeCapture.enable()` 调用后，通过 `NSURLProtocol` 子类拦截宿主 app 原生层（ObjC/Swift）发出的所有 HTTP/HTTPS 请求，并将请求元数据推送至 Dart 层。

#### Scenario: 原生 GET 请求被捕获
- **WHEN** 宿主 iOS app 原生代码通过 `NSURLSession` 发出 GET 请求，且 `ArgosNativeCapture.enable()` 已调用
- **THEN** 该请求的 URL、Method、请求头、响应码、响应头、耗时出现在 `ArgosPacketStorage` 中

#### Scenario: 已标记的 Dart 层请求不被重复捕获
- **WHEN** Dart 层请求经 `ArgosHttpMonitor` 处理并注入 `X-Argos-Captured: 1` 请求头
- **THEN** iOS `ArgosURLProtocol` 识别到该标记，不处理该请求，避免重复记录

#### Scenario: HTTPS 请求元数据被捕获
- **WHEN** 原生代码发出 HTTPS 请求
- **THEN** URL（含 scheme）、响应码、响应头被记录；响应 body 仅对文本类型（Content-Type 含 text/json/xml）记录，二进制内容不记录

### Requirement: Android OkHttp Interceptor 拦截原生请求
系统 SHALL 提供 `ArgosOkHttpInterceptor`（实现 OkHttp `Interceptor` 接口），宿主 app 将其注入 `OkHttpClient.Builder` 后，该 interceptor SHALL 捕获所有经过该 OkHttpClient 的请求并推送至 Dart 层。

#### Scenario: 原生 POST 请求被捕获
- **WHEN** 宿主 Android app 通过注入了 `ArgosOkHttpInterceptor` 的 OkHttpClient 发出 POST 请求
- **THEN** 该请求的 URL、Method、请求头、请求 body（文本类型）、响应码、响应头、响应 body（文本类型）、耗时出现在 `ArgosPacketStorage` 中

#### Scenario: 非文本 body 不记录内容
- **WHEN** 请求或响应的 Content-Type 为 `image/*`、`application/octet-stream` 等二进制类型
- **THEN** body 字段为空字符串，size 字段记录字节数

#### Scenario: OkHttp 未注入时功能静默禁用
- **WHEN** 宿主 app 未将 `ArgosOkHttpInterceptor` 注入 OkHttpClient
- **THEN** 系统无任何报错，原生抓包功能对该 OkHttpClient 不生效，Dart 层监控不受影响

### Requirement: EventChannel 数据桥接
系统 SHALL 通过命名为 `dev.panoptes.argos/native_capture` 的 `EventChannel` 将原生捕获的请求数据以 JSON 字符串形式推送至 Dart 层，Dart 层反序列化后调用 `ArgosPacketStorage.append()`。

#### Scenario: 原生请求数据到达 Dart 层
- **WHEN** iOS 或 Android 侧完成一次请求捕获
- **THEN** Dart 侧 EventChannel listener 收到 JSON 字符串，解析为 `ArgosHttpInfo`，`ArgosPacketStorage.append()` 被调用

#### Scenario: EventChannel 未 listen 时数据不丢失
- **WHEN** `ArgosNativeCapture.enable()` 尚未调用，EventChannel 未被监听，原生请求发生
- **THEN** 原生侧丢弃该事件（不缓冲），不报错，不影响请求正常执行

### Requirement: ArgosNativeCapture 启用 API
系统 SHALL 提供 `ArgosNativeCapture` 单例，其 `enable()` 方法 SHALL 同时启动 iOS NSURLProtocol 注册和 Android EventChannel 监听。`enable()` 可重复调用（幂等）。

#### Scenario: enable() 幂等调用
- **WHEN** `ArgosNativeCapture.enable()` 被调用两次
- **THEN** 系统不重复注册拦截器，不产生重复记录，不报错

#### Scenario: enable() 后原生请求进入存储
- **WHEN** `ArgosNativeCapture.enable()` 调用后，原生层发出 HTTP 请求，且 `ArgosPacketStorage` 已配置 adapter
- **THEN** 该请求记录出现在 `ArgosPacketStorage.getAllAsync()` 返回列表中
