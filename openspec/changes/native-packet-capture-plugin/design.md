## Context

`argos` 目前通过 Dart 的 `HttpOverrides` 机制拦截 Dart 层发出的 HTTP 请求。但宿主 app 中由原生代码（ObjC/Swift、Java/Kotlin）发出的请求无法被捕获。为统一监控全量网络流量，需要在 iOS 和 Android 两个平台分别注入原生拦截器，并通过 EventChannel 将数据桥接到 Dart 层。

## Goals / Non-Goals

**Goals:**
- iOS：通过 `NSURLProtocol` 子类拦截原生 HTTP/HTTPS 请求
- Android：通过 OkHttp `EventListener` + `Interceptor` 拦截原生请求
- 原生捕获数据复用 `ArgosHttpInfo` / `ArgosPacketStorage` / UI 管线
- 与现有 Dart 层 `ArgosHttpMonitor` 共存，两路数据合并入同一存储
- 宿主 app 仅需一行代码启用：`ArgosNativeCapture.enable()`

**Non-Goals:**
- 不支持非 OkHttp 的 Android 网络库（如 Retrofit 直接用 HttpURLConnection）
- 不做 HTTPS 解密（只记录元数据，body 视实现难度可选）
- 不支持 WebSocket 帧级别抓包
- 不修改现有 `ArgosConfig` 接口

## Decisions

### 1. iOS：NSURLProtocol 注册
**选择**：在 Plugin `register()` 时调用 `[NSURLProtocol registerClass:[ArgosURLProtocol class]]`，使用 `NSURLSession` 转发请求（避免递归）。

**为什么不用 Network.framework / PacketTunnel**：`NSURLProtocol` 无需系统权限，零配置，覆盖所有基于 `NSURLSession`/`NSURLConnection` 的请求，包括 Flutter Engine 自身的 HTTP 请求（Dart 层已有 HttpOverrides，需去重）。

**去重**：Dart 层请求经过 `ArgosHttpMonitor` 已有记录；iOS NSURLProtocol 也会拦截到 Flutter Engine 发出的请求。解决方案：在请求头中注入标记 `X-Argos-Captured: 1`，NSURLProtocol 收到带此标记的请求时直接 `DIRECT` 不处理。

### 2. Android：OkHttp EventListener + ApplicationInterceptor
**选择**：暴露 `ArgosOkHttpInterceptor`（`Interceptor` 接口）和 `ArgosOkHttpEventListener`（`EventListener` 接口），由宿主 app 的 OkHttpClient.Builder 注入。

**为什么不用全局 Proxy 或 VPN**：OkHttp Interceptor 是侵入最小、最可靠的方式；VPN 方案需要系统权限且会影响所有流量；全局 Java Proxy 不支持 HTTPS MITM。

**注入方式**：通过 `MethodChannel` 触发宿主 app 注入，或宿主 app 在构建 OkHttpClient 时主动引用 `ArgosOkHttpInterceptor.instance`。推荐后者（更明确）。

### 3. 数据桥接：EventChannel（流）
**选择**：每次原生拦截到请求完成后，通过 `EventChannel` 将 JSON 推送到 Dart，Dart 侧反序列化为 `ArgosHttpInfo` 并调用 `ArgosPacketStorage.append()`。

**为什么不用 MethodChannel**：MethodChannel 是单次调用，EventChannel 天然支持多个异步事件的推送，与网络请求的异步特性匹配。

### 4. Plugin 注册
`flutter-monitor` 的 `pubspec.yaml` 中 `plugin.platforms` 从 stub 改为真实的 iOS/Android 声明。Plugin 入口类：
- iOS：`ArgosPlugin`（Swift）
- Android：`ArgosPlugin`（Kotlin）

Dart 侧入口：`ArgosNativeCapture` 单例，`enable()` 方法启动 EventChannel 监听并调用原生注册。

## Risks / Trade-offs

- **NSURLProtocol 递归风险** → 使用请求头标记去重，转发层使用独立 `NSURLSession`（非共享 session）
- **Android OkHttp 版本兼容** → 要求宿主 app OkHttp ≥ 3.11（EventListener 从 3.11 引入）；Interceptor 从 OkHttp 1.x 就支持
- **Dart 层与原生层重复记录** → iOS 通过请求头标记过滤；Android 侧 Dart HttpOverrides 不经过 OkHttp，天然不重复
- **EventChannel 序列化开销** → 请求体大时 JSON 序列化耗时；非文本 body 只记录 Content-Type + size，不传 body 内容
- **原生线程安全** → iOS delegate callback 在 `URLSession` 的 delegateQueue（串行队列）；Android Interceptor 在 OkHttp 的线程池，需在主线程或独立 Handler 发送 EventChannel 事件

## Migration Plan

1. `pubspec.yaml` plugin platforms 声明更新（不影响现有 API）
2. 宿主 app 按需调用 `ArgosNativeCapture.enable()`（可选，向后兼容）
3. Android 宿主手动在 OkHttpClient.Builder 中添加 interceptor（一次性改动）

## Open Questions

- iOS NSURLProtocol 能否拦截 Flutter Engine 内部的 HTTP 请求？（待验证；若能，去重标记方案必须实施）
- Android 侧是否需要 `EventListenerFactory` 来支持并发请求的精确计时？（初版用 Interceptor 足够，EventListener 可后续加）
