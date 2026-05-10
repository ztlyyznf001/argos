## 1. Plugin 基础结构

- [x] 1.1 更新 `pubspec.yaml`：将 `plugin.platforms` 从 stub 改为真实 iOS（Swift）和 Android（Kotlin）声明
- [x] 1.2 创建 `lib/native/argos_native_capture.dart`：`ArgosNativeCapture` 单例，含 `enable()` 方法和 EventChannel 监听逻辑
- [x] 1.3 在 `lib/argos.dart` 中导出 `ArgosNativeCapture`

## 2. iOS 平台代码

- [x] 2.1 创建 `ios/Classes/ArgosPlugin.swift`：Plugin 注册入口，`register(with:)` 方法
- [x] 2.2 创建 `ios/Classes/ArgosURLProtocol.swift`：`NSURLProtocol` 子类，实现 `canInit`（跳过已标记请求）、`startLoading`（用独立 NSURLSession 转发）、`stopLoading`
- [x] 2.3 创建 `ios/Classes/ArgosEventSink.swift`：持有 `FlutterEventSink`，线程安全地将捕获数据序列化为 JSON 并推送
- [x] 2.4 在 `ArgosURLProtocol.startLoading` 的 delegate callback 中收集请求/响应元数据并调用 `ArgosEventSink.send()`

## 3. Android 平台代码

- [x] 3.1 创建 `android/src/main/kotlin/.../ArgosPlugin.kt`：Plugin 注册入口，实现 `FlutterPlugin`，注册 EventChannel
- [x] 3.2 创建 `android/src/main/kotlin/.../ArgosOkHttpInterceptor.kt`：实现 OkHttp `Interceptor`，捕获请求/响应元数据，调用 EventSink 推送
- [x] 3.3 在 `ArgosPlugin` 中持有 `EventChannel.EventSink`，`ArgosOkHttpInterceptor.instance` 持有对 sink 的引用
- [x] 3.4 处理 body 类型判断：文本类型（text/\*、\*/json、\*/xml）记录内容，二进制类型只记录 size

## 4. Dart 胶水层

- [x] 4.1 `ArgosNativeCapture.enable()` 中通过 MethodChannel 调用原生 `enable` 方法触发 NSURLProtocol 注册（iOS），Android 侧注册在 Plugin 初始化时自动完成
- [x] 4.2 EventChannel `listen` 回调中将 JSON 解析为 `ArgosHttpInfo`，调用 `ArgosPacketStorage.instance.append(info)`
- [x] 4.3 `enable()` 实现幂等：用 `_enabled` 标志防止重复 listen

## 5. 数据格式对齐

- [x] 5.1 定义原生侧 JSON 序列化格式，与 `ArgosHttpInfo.toJson()` / `fromJson()` 对齐（字段名一致）
- [x] 5.2 原生侧时间戳使用 Unix 毫秒（与 Dart 侧 `DateTime.now().millisecondsSinceEpoch` 一致）
- [x] 5.3 原生侧 `routeName` 字段默认为空字符串（原生侧无路由信息）

## 6. 集成验证

- [x] 6.1 在 argos host `main.dart` 中调用 `ArgosNativeCapture.enable()`（仅 debug 模式）
- [x] 6.2 更新 `argos` ref 到新 tag，提交 MR
