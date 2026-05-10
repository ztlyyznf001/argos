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

## 安装

```yaml
dependencies:
  argos: ^0.1.0
```

## 快速上手

```dart
import 'package:argos/argos.dart';

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
  apmTypes: [ArgosCapability.network, ArgosCapability.fps],
  hostWhiteList: ['api.example.com'],
  enableStorage: true,
  maxPacketRecords: 500,
  proxyProvider: () => kDebugMode ? 'http://127.0.0.1:9091' : null,
  storageAdapter: MyMmkvAdapter(),
);
```

运行时开关：

```dart
ArgosManager.instance.captureEnabled = false;
```

## 协议

[MIT](LICENSE) · Copyright (c) 2022-2026 Argos Contributors.
