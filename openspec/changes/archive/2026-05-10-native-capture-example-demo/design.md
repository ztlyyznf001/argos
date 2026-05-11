## Context

`argos` 主库已经实现 iOS `NSURLProtocol` + Android `OkHttp Interceptor` 两侧的原生抓包，并通过 `EventChannel` 把数据回灌至 `ArgosPacketStorage`。但当前 `example/` 工程：

- `main.dart` 没有调用 `ArgosNativeCapture.instance.enable()`
- 没有任何由原生 Swift / Kotlin 主动发起的 HTTP 请求
- `MyHomePage` 只暴露 "滚动列表" 与 "查看抓包记录" 两个入口

因此原生抓包的代码路径在示例里完全没有被触发，使用者无法通过运行 example 来验证或学习接入步骤。

## Goals / Non-Goals

**Goals:**
- 在 example 工程里跑一遍真实的原生 → Argos 数据流（Swift `URLSession` 与 Kotlin `OkHttpClient` 各一条用例）
- 用户启动 example、点击两个按钮就能在 `ArgosPacketListPage` 看到原生发起的请求
- 接入代码尽量贴合真实业务场景，可被使用者直接复制
- 保持现有 example 行为不破坏（Dart 层抓包按钮、滚动列表演示继续工作）

**Non-Goals:**
- 不修改 `argos` 主库源码（`lib/`、`ios/Classes/`、`android/src/`）
- 不引入图形化的"对比 Dart vs 原生"视图，仅依赖现有 `ArgosPacketListPage`
- 不演示 HTTPS MITM、抓包导出、转发等高级功能
- 不演示非 OkHttp 的 Android 网络栈（如 `HttpURLConnection`、Retrofit 直连）
- 不引入 release-mode 上的原生抓包（保持 debug-only 语义，与现有约定一致）

## Decisions

### 1. 原生请求触发机制：MethodChannel 单向调用

**选择**：Dart 侧定义 `MethodChannel('argos_example/native_demo')`，方法名 `sendIosRequest` / `sendAndroidRequest`；原生侧收到调用后 fire-and-forget 发起 HTTP 请求，结果通过 Argos 的 `EventChannel` 自然回流，不通过 MethodChannel 返回 body。

**为什么不用 PlatformView 或 Pigeon**：单次触发请求完全够用，PlatformView 太重；Pigeon 需要额外构建步骤，对一个 demo 不划算。
**为什么不让 Dart 直接发请求**：那样测的是 Dart `HttpClient` 路径，无法验证 `NSURLProtocol` / `OkHttp Interceptor` 是否生效——这正是本次 demo 要演示的核心。

### 2. 原生侧请求库选择

**iOS**：`URLSession.shared.dataTask`，因为 `ArgosURLProtocol` 本身就是注册到 `URLSession` 的协议栈，使用 shared session 能验证默认链路；目标 URL 用 `https://httpbin.org/get?platform=ios&source=native`，方便在抓包列表中肉眼区分。

**Android**：在 demo 内显式构造一个 `OkHttpClient.Builder().addInterceptor(ArgosOkHttpInterceptor.instance).build()`，因为现有 plugin 设计要求宿主主动注入 interceptor（详见 `native-packet-capture-plugin/design.md` §2 注入方式）。这正好向使用者演示"如何把 interceptor 加到自己的 OkHttpClient"。目标 URL 用 `https://httpbin.org/get?platform=android&source=native`。

**为什么不用 `HttpURLConnection`**：plugin 不拦截它，演示效果就是空的，反而误导。

### 3. 启用时机与开关语义

`ArgosNativeCapture.instance.enable()` 在 `ArgosManager.instance.init` 之后立即调用，**不**用 `kDebugMode` 包裹。原因：是否记录抓包数据已经统一由 `ArgosManager.instance.captureEnabled` 控制——它由 `ArgosConfig.enableStorage` 初始化，并被 `ArgosPacketListPage` 的暂停/开始按钮在运行时切换；Dart 层 `argos_http_monitor` 也是依据这同一个开关决定是否落库。

为了让"原生抓包"和"Dart 抓包"行为对齐，原生 EventChannel 数据流到达 Dart 后，写入 `ArgosPacketStorage` 之前 MUST 检查 `ArgosManager.instance.captureEnabled`：开关关闭时丢弃记录，开关重新打开后立即恢复，不需要重启 app 或重注册 `NSURLProtocol`。这也意味着 release 构建里如果使用者把 `enableStorage: false` 传给 `ArgosConfig`，原生抓包同样不会落库——这是配置驱动而非编译期常量驱动。

### 4. UI 入口

新增独立页面 `NativeCaptureDemoPage`，路由 `/nativeDemo`，挂在 `MyHomePage` 既有按钮列表底部。页面内提供：
- "iOS 原生请求" 按钮（仅在 iOS 平台启用，其它平台 disabled 并显示提示）
- "Android 原生请求" 按钮（仅在 Android 平台启用）
- "查看抓包记录" 链接，复用 `/packets` 路由

理由：和现有 `MyHomePage` 风格保持一致；用 `defaultTargetPlatform` 做平台判断，避免用户在 macOS desktop 跑示例时误点。

### 5. 错误反馈

按钮点击后用 `ScaffoldMessenger.showSnackBar` 显示 "已发起 iOS 原生请求"。原生侧的 HTTP 错误不上报到 UI（用户能直接在抓包列表中看到失败状态码 / 异常）。

## Risks / Trade-offs

- **httpbin.org 稳定性** → demo 依赖外网公共服务，如果该域名不可达 demo 就失败。Mitigation：在 README 里注明可替换为任何 GET 地址；demo 失败不影响主库。
- **Android 引入 OkHttp 依赖** → `example/android/app/build.gradle` 增加 `com.squareup.okhttp3:okhttp:4.12.0` 一行，会让 example apk 略变大。Mitigation：仅 example 工程引入，不影响主库使用者；版本与 plugin EventListener 兼容（≥ 3.11）。
- **iOS App Transport Security** → 部分公司测试网络可能屏蔽 httpbin。Mitigation：使用 HTTPS 域名规避 ATS；如真不可用，文档里给出替代方案。
- **跨平台 desktop 运行 example** → 在 macOS / Web 上点击按钮会触发 `MissingPluginException`。Mitigation：按钮按平台 disable，且 catch 异常后给出 SnackBar 提示。
- **Android 缺少 INTERNET 权限** → 默认 Flutter template 已声明，确认 `example/android/app/src/main/AndroidManifest.xml` 后再决定是否补；若已声明则无操作。

## Migration Plan

无 runtime 迁移：

1. 合入 PR
2. 使用者拉取 example 后 `flutter run`，按 README 步骤验证两个按钮
3. 如要回滚，直接 revert 该 PR；不影响主库版本号

## Open Questions

- 是否要在 demo 中再加一个"用 Argos 抓 Flutter Engine 自身请求"的展示？当前判断不需要，使用者通过运行已有的 Dart 抓包按钮就能观察到——若收到反馈再考虑。
