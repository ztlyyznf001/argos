# Argos

> 全视角的 Flutter 性能监控 + HTTP 抓包插件。
>
> 名字取自希腊神话百眼巨人 Argus Panoptes ——Argos 看见你 App 的每一次请求。

[English README](README.md) · MIT 协议 · Flutter ≥ 3.0

## 特性

- **原生抓包** — iOS 通过 `NSURLProtocol`、Android 通过 `OkHttp Interceptor` 在原生层捕获流量，覆盖 Dart `HttpClient` 之外的请求路径
- **Dart 抓包** — 基于 `HttpOverrides`，覆盖所有走 `dart:io` HTTP 的代码路径
- **内置查看器** — 提供 `ArgosPacketListPage` / `ArgosPacketDetailPage` Widget，支持按路由分组、Method 过滤、URL 搜索、运行时开关、cURL 复刻
- **可插拔存储** — `ArgosStorageAdapter` 接口允许你用 MMKV / SharedPreferences / 文件 / 自研引擎承载抓包日志
- **动态代理** — `ArgosConfig.proxyProvider` 接入调试代理开关，运行时可替换
- **FPS 监控** — 通过 `ArgosCapability.fps` 启用帧率采样
- **崩溃/错误捕获** — 通过 `ArgosCapability.crash` 启用，捕获 Flutter 框架错误（`FlutterError.onError`）与未处理的 Dart 异步异常（`PlatformDispatcher.onError`），并链式保留宿主已安装的 handler
- **卡顿分析** — 通过 `ArgosCapability.jank` 启用，基于帧预算检测掉帧、拆分 build/raster 耗时，并将连续掉帧聚合为卡顿区间事件
- **资源监控** — 通过 `ArgosCapability.resource` 启用，周期性采样进程内存（`ProcessInfo.currentRss` / `maxRss`）；纯 Dart 无法可靠获取 CPU 时该字段留空

以上三类均为纯 Dart 实现，不引入第三方依赖，与网络抓包共用同一 `ArgosManager.listener` 回调、存储与查看器 UI。

## 安装

```yaml
dependencies:
  argos_inspector: ^0.3.1
```

## 快速上手

```dart
import 'package:argos_inspector/argos_inspector.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  ArgosManager.instance.init(
    config: ArgosConfig(
      apmTypes: [ArgosCapability.network],
      enableStorage: true,
      maxPacketRecords: 200,
    ),
    listener: (ArgosBaseModel? model) {
      debugPrint(model?.getValue());
    },
  );

  // 可选：启用原生抓包（iOS NSURLProtocol + Android OkHttp）
  ArgosNativeCapture.instance.enable();

  runApp(const MyApp());
}
```

打开查看器：

```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const ArgosPacketListPage()),
);
```

## 存储

`ArgosPacketStorage` 通过 `ArgosConfig.storageAdapter` 写入。不传 adapter 时只在内存中保留。`example/` App 提供了一份基于 MMKV 的参考实现。

## 原生抓包

`ArgosNativeCapture.instance.enable()` 会在 iOS 注册 `ArgosURLProtocol`、在 Android 武装 `ArgosOkHttpInterceptor`。原生层抓到的请求通过 `dev.panoptes.argos/native_capture` event channel 推回 Dart，与 Dart 侧抓包合并到同一个存储。

## 配置

```dart
ArgosConfig(
  apmTypes: [
    ArgosCapability.network,
    ArgosCapability.fps,
    ArgosCapability.crash,
    ArgosCapability.jank,
    ArgosCapability.resource,
  ],
  hostWhiteList: ['api.example.com'],
  enableStorage: true,
  maxPacketRecords: 500,   // 每个非资源类型（网络 / 崩溃 / 卡顿）各自的保留上限
  resourceMaxRecords: 50,  // 资源采样的独立上限——高频采样也不会挤掉已捕获的崩溃或请求
  storagePersistInterval: const Duration(seconds: 5), // 合并落盘周期;
                           // Duration.zero 表示每次写入即落盘(无丢数据窗口)
  proxyProvider: () => kDebugMode ? 'http://127.0.0.1:9091' : null,
  storageAdapter: MyMmkvAdapter(),
  // APM 可选调参：
  jankThresholdMultiplier: 1.0, // 帧 span 超过 帧预算 × 该倍数 即判定掉帧
  resourceSampleInterval: const Duration(seconds: 2),
);
```

各能力独立开关——仅当在 `apmTypes` 中显式列出时才安装对应的 handler/定时器。
不包含 `crash`/`jank`/`resource` 时，`FlutterError.onError`、帧回调与采样均不受影响。
崩溃、卡顿、资源事件与 HTTP 包出现在同一查看器列表中，并以不同图标与标签（崩溃 / 卡顿 / 资源）区分。

运行时开关：

```dart
ArgosManager.instance.captureEnabled = false;
```

## 协议

[MIT](LICENSE) · Copyright (c) 2022-2026 Argos Contributors.
