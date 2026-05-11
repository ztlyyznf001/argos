# argos_example

Demonstrates how to use the argos plugin.

## 原生抓包 demo

示例里附带了一个原生抓包 demo，用于演示 iOS `NSURLProtocol` 与 Android `OkHttp Interceptor` 两条原生数据通路。

### 运行步骤

1. `flutter run` 在 iOS 或 Android 设备/模拟器上启动 example
2. 主页点击 **原生抓包 demo** 进入 `/nativeDemo` 页面
3. 在 iOS 设备上点击 **iOS 原生请求**：Swift 侧通过 `URLSession.shared` 请求 `https://httpbin.org/get?platform=ios&source=native`
4. 在 Android 设备上点击 **Android 原生请求**：Kotlin 侧通过加装 `ArgosOkHttpInterceptor` 的 `OkHttpClient` 请求 `https://httpbin.org/get?platform=android&source=native`
5. 返回主页 → **查看抓包记录**，应能看到对应的 `httpbin.org/get` 条目

### 抓包开关

`example/lib/main.dart` 在初始化阶段无条件调用 `ArgosNativeCapture.instance.enable()`。是否落库由 `ArgosManager.instance.captureEnabled` 决定——即抓包列表页右上角的暂停/开始按钮，与 Dart 层 `argos_http_monitor` 共用同一开关。点击暂停后，原生请求依然会发出，但不会出现在列表中；恢复后立即生效。

### 备注

- demo 默认请求 `httpbin.org`（HTTPS），如所在网络无法访问可自行替换为任意公开 GET 地址
- iOS 走 `NSURLProtocol` 拦截，无需额外权限；Android 已在 `AndroidManifest.xml` 声明 `INTERNET` 权限
- 在非 iOS/Android 平台（macOS desktop、web）上对应平台的按钮会被禁用
