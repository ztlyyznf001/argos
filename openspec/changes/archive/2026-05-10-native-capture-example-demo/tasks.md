## 1. Dart 层入口

- [x] 1.1 修改 `example/lib/main.dart`：在 `ArgosManager.instance.init` 之后无条件调用 `ArgosNativeCapture.instance.enable()`（实际是否记录由 `ArgosManager.instance.captureEnabled` 控制）
- [x] 1.1.1 在 `lib/native/argos_native_capture.dart` 的 EventChannel 监听回调里，调用 `ArgosPacketStorage.instance.append(info)` 之前检查 `ArgosManager.instance.captureEnabled`，关闭时直接丢弃事件
- [x] 1.2 在 `MaterialApp.routes` 中注册 `'/nativeDemo': (context) => const NativeCaptureDemoPage()`
- [x] 1.3 在 `MyHomePage` 按钮列表底部新增 "原生抓包 demo" 按钮，跳转 `/nativeDemo`

## 2. NativeCaptureDemoPage

- [x] 2.1 新建 `example/lib/native_demo_page.dart`，定义 `NativeCaptureDemoPage` (`StatelessWidget` 或 `StatefulWidget`)
- [x] 2.2 页面声明常量 `MethodChannel _channel = MethodChannel('argos_example/native_demo')`
- [x] 2.3 渲染两个按钮 ("iOS 原生请求"、"Android 原生请求")，使用 `defaultTargetPlatform` 控制 enabled 状态
- [x] 2.4 渲染一个 "查看抓包记录" 按钮，跳转到现有 `/packets` 路由
- [x] 2.5 按钮点击后用 `try/catch` 包裹 `_channel.invokeMethod`，并通过 `ScaffoldMessenger.showSnackBar` 反馈成功或异常文案

## 3. iOS 平台

- [x] 3.1 新建 `example/ios/Runner/NativeDemoChannel.swift`，导出 `func register(with registrar: FlutterPluginRegistrar?)` 用于注册 MethodChannel
- [x] 3.2 在 `NativeDemoChannel` 中处理 `sendIosRequest` 调用：用 `URLSession.shared.dataTask(with: URL(string: "https://httpbin.org/get?platform=ios&source=native"))` 触发请求并 `resume()`
- [x] 3.3 修改 `example/ios/Runner/AppDelegate.swift`：在 `application(_:didFinishLaunchingWithOptions:)` 里调用 `NativeDemoChannel.register(with: registrar(forPlugin:))`
- [x] 3.4 确认 `Info.plist` 不阻塞 `httpbin.org`（HTTPS，按 ATS 默认放行；如有 NSAppTransportSecurity 配置则保持现状）

## 4. Android 平台

- [x] 4.1 在 `example/android/app/build.gradle` 的 `dependencies` 中加入 `implementation "com.squareup.okhttp3:okhttp:4.12.0"`
- [x] 4.2 新建 `example/android/app/src/main/kotlin/com/example/example/NativeDemoChannel.kt`，提供 `register(messenger: BinaryMessenger)` 方法
- [x] 4.3 在 `NativeDemoChannel` 中处理 `sendAndroidRequest` 调用：构造 `OkHttpClient.Builder().addInterceptor(ArgosOkHttpInterceptor.instance).build()`，发起 `Request.Builder().url("https://httpbin.org/get?platform=android&source=native").build()` 请求，使用 `client.newCall(request).enqueue(...)`
- [x] 4.4 修改 `example/android/app/src/main/kotlin/com/example/example/MainActivity.kt`：覆写 `configureFlutterEngine`（或在 `onCreate` 后），调用 `NativeDemoChannel.register(flutterEngine.dartExecutor.binaryMessenger)`
- [x] 4.5 检查 `example/android/app/src/main/AndroidManifest.xml`，若缺少 `<uses-permission android:name="android.permission.INTERNET"/>` 则补上

## 5. 文档与验证

- [x] 5.1 在 `example/README.md` 增加 "原生抓包 demo" 一节，说明：先运行 example，进入主页 → 点击"原生抓包 demo" → 分别点击 iOS / Android 按钮 → 返回主页 → 进入"查看抓包记录"，应能看到两条 `httpbin.org/get` 请求
- [ ] 5.2 `flutter run` 在 iOS 模拟器与 Android 模拟器各自跑一遍，确认抓包列表中出现 `platform=ios` / `platform=android` 的记录
- [ ] 5.3 在抓包列表页点击暂停按钮（将 `ArgosManager.instance.captureEnabled` 切换为 `false`），再次触发原生请求，确认列表不增加新条目；恢复开关后立即能记录新请求
- [x] 5.4 跑 `openspec validate native-capture-example-demo --strict`，并在合入前运行 `flutter analyze example`
