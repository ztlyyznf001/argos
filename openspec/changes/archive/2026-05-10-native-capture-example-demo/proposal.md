## Why

`argos` 已经具备 iOS `NSURLProtocol` 与 Android `OkHttp Interceptor` 的原生抓包能力（见 `native-packet-capture-plugin`），但 `example/` 示例工程目前只演示了 Dart 层 `HttpClient` 的抓包效果，没有任何来自原生代码（Swift / Kotlin）发起的请求，导致使用者无法直观验证「native HTTP capture」是否生效，也无从对照接入步骤。本次新增一个本地原生抓包 demo，把这个能力补齐到示例工程里。

## What Changes

- **新增** `example/lib/main.dart` 在 `ArgosManager.instance.init` 之后调用 `ArgosNativeCapture.instance.enable()`，启用原生抓包数据流；是否真正记录由 `ArgosManager.instance.captureEnabled`（也就是抓包列表里的暂停/开始按钮）决定，与 Dart 层 `argos_http_monitor` 共用同一个开关
- **新增** Dart 侧 `NativeCaptureDemoPage`：提供 "iOS 原生请求"、"Android 原生请求" 两个按钮，通过 `MethodChannel('argos_example/native_demo')` 触发原生侧发起 HTTP 请求
- **新增** iOS 侧 `NativeDemoChannel.swift`：在 `AppDelegate` 注册 `MethodChannel`，使用 `URLSession.shared` 调用一个公开测试地址（如 `https://httpbin.org/get`），让请求经过 `ArgosURLProtocol`
- **新增** Android 侧 `NativeDemoChannel.kt`：在 `MainActivity` 注册 `MethodChannel`，使用一个加装 `ArgosOkHttpInterceptor` 的 `OkHttpClient` 发起请求
- **新增** demo 入口按钮："原生抓包 demo"，挂在 `MyHomePage` 现有按钮列表下方，并在 `MaterialApp.routes` 中注册 `/nativeDemo` 路由
- **新增** `example/README.md` 增加一节《原生抓包 demo》，说明运行步骤与预期看到的抓包效果（包含两条由原生触发的记录）
- **不修改** `argos` 主库的公共 API、`ArgosNativeCapture` 实现以及现有 `pubspec.yaml` 依赖

## Capabilities

### New Capabilities
- `native-capture-example`: 在 `example/` 工程中提供从原生 Swift / Kotlin 主动发起 HTTP 请求并被 Argos 捕获的可运行 demo，作为接入参考样板

### Modified Capabilities
<!-- 无：本次仅扩充示例，不改变库的行为契约 -->

## Impact

- **代码**：仅影响 `example/`：`example/lib/main.dart`、新增 `example/lib/native_demo_page.dart`、新增 `example/ios/Runner/NativeDemoChannel.swift`、新增 `example/android/app/src/main/kotlin/com/example/example/NativeDemoChannel.kt`、调整 `example/ios/Runner/AppDelegate.swift` 与 `example/android/app/src/main/kotlin/.../MainActivity.kt`
- **依赖**：`example/android/app/build.gradle` 新增 OkHttp 依赖（如 `com.squareup.okhttp3:okhttp:4.12.0`）；iOS 端无新增依赖（使用系统 `URLSession`）
- **运行要求**：原生请求访问公网测试地址，需要设备/模拟器具备网络；iOS 模拟器默认允许，Android `AndroidManifest.xml` 已启用 INTERNET 权限（如缺失需补充）
- **不影响**：主库 `lib/`、`ios/Classes/`、`android/src/`、已发布 plugin 行为；`ArgosConfig`、存储与 UI 管线均无变化
