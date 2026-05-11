## 0.2.0

### 新增

- 原生抓包演示 Demo:通过 `MethodChannel` 串联 iOS (`example/ios/Runner/NativeDemoChannel.swift`) 与 Android (`example/android/app/src/main/kotlin/com/example/example/NativeDemoChannel.kt`) 端,并新增 `example/lib/native_demo_page.dart` 在 example app 中演示原生 HTTP 流量。
- MMKV 存储适配器示例 (`example/lib/mmkv_storage_adapter.dart`),展示如何把持久化后端接入 Argos。
- 在 `openspec/specs/` 下新增 `native-capture-example` 能力规约,沉淀 Demo 接线方式。

### 变更

- 原生抓包链路接入运行时配置:`ArgosManager.captureEnabled` 为 `false` 时丢弃事件;存储条数改为遵循 `ArgosConfig.maxPacketRecords`(默认 200),不再硬编码 200 上限。
- Android `OkHttpInterceptor` 读取响应体时使用响应自带的 content-type 编码,不再强制 UTF-8,行为对齐 iOS 端。
- 对 `ArgosFpsInfo.type` / `ArgosHttpInfo.type` 的覆盖字段加上 `// ignore: overridden_fields`,消除 analyzer 噪音。
- `test/argos_test.dart` 中 `TestWidgetsFlutterBinding.ensureInitialized()` 调用顺序前置,修复新版 Flutter 测试框架下的偶发失败。

### 破坏性变更

- Android 插件构建工具链整体升级:Kotlin `1.9.0` → `2.0.21`、AGP `7.4.0` → `8.7.3`、`compileSdk` `33` → `36`、source/target 升到 Java 17,插件 `build.gradle` 显式声明 `namespace 'dev.panoptes.argos'`。下游 Android 宿主 app 必须使用 AGP 8.x + JDK 17,否则 Gradle 配置阶段会失败。
- 移除插件 `build.gradle` 中不再需要的 `compileOnly 'io.flutter:flutter_embedding_debug:1.0.0-3316dd8728419ad3534e3f6112aa6291f587078a'` 依赖;下游若依赖该 artifact 存在,请去掉对应引用。

## 0.1.0

首次公开发布。

### 特性

- 原生 HTTP 抓包:iOS 使用 `NSURLProtocol`,Android 使用 `OkHttp Interceptor`。
- Dart 层 HTTP 抓包:通过 `HttpOverrides` 覆盖所有走 `dart:io` 的请求路径。
- 内置查看器:`ArgosPacketListPage` / `ArgosPacketDetailPage`,支持路由分组、Method 过滤、URL 搜索、运行时开关、cURL 复刻。
- 可插拔存储:通过 `ArgosStorageAdapter` 接入 MMKV / SharedPreferences / 文件等任意后端。
- 动态代理:`ArgosConfig.proxyProvider` 运行时切换调试代理。
- FPS 监控:通过 `ArgosCapability.fps` 开启帧率采样。
