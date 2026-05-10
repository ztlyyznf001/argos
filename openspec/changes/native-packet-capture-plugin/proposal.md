## Why

`argos` 目前只能在 Dart 层拦截 HTTP 请求（通过 `HttpOverrides`），无法捕获原生层（ObjC/Swift、Java/Kotlin）发出的网络请求。通过 Flutter Plugin 将 iOS 的 `NSURLProtocol` 和 Android 的 `OkHttp Interceptor` 桥接进来，可以实现对全量网络流量的监控。

## What Changes

- **新增** iOS 平台代码：注册 `ArgosURLProtocol`（`NSURLProtocol` 子类）拦截原生 HTTP/HTTPS 请求
- **新增** Android 平台代码：注入 `ArgosOkHttpInterceptor`（`OkHttp Interceptor`）拦截原生请求
- **新增** Dart/Flutter Plugin 胶水层：通过 `EventChannel` 将原生捕获的数据推送至 Dart，复用现有 `ArgosHttpInfo` / `ArgosPacketStorage` 管线
- **新增** Plugin 注册 API：宿主 app 调用一行代码启用原生抓包，支持与现有 Dart 层监控共存
- 现有 `ArgosHttpMonitor`（Dart 层）**保持不变**，两条数据流合并进同一个存储/UI 管线

## Capabilities

### New Capabilities
- `native-http-capture`: iOS NSURLProtocol + Android OkHttp Interceptor → EventChannel → Dart，捕获原生层 HTTP/HTTPS 请求并入库

### Modified Capabilities
- `http-capture-pipeline`: 数据入口由单一 Dart HttpOverrides 扩展为「Dart + 原生双通道」，`ArgosPacketStorage.append` 成为统一写入点

## Impact

- **flutter-monitor**：新增 `ios/`、`android/` 平台目录及 Plugin 注册类；`pubspec.yaml` plugin platforms 声明从 stub 改为真实平台
- **argos host**：宿主 app 在初始化时额外调用 `ArgosNativeCapture.enable()` 即可；无需修改现有 `ArgosConfig`
- **依赖**：Android 侧需宿主 app 的 OkHttpClient 实例（通过 MethodChannel 触发注入）或使用全局 `EventBus` 方案；iOS 侧无额外依赖
