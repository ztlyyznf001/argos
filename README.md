# Argos

> All-seeing Flutter APM and HTTP packet capture plugin.
>
> Named after Argus Panoptes, the hundred-eyed giant of Greek myth — Argos watches every request your app makes.

[中文文档](README_zh.md) · MIT License · Flutter ≥ 3.0

## Features

- **Native HTTP capture** — `NSURLProtocol` on iOS and `OkHttp Interceptor` on Android, so traffic from native SDKs (not just Dart's `HttpClient`) is recorded.
- **Dart HTTP capture** — `HttpOverrides`-based interception for any code paths that flow through `dart:io` HTTP.
- **Inspector UI** — built-in widget tree (`ArgosPacketListPage` / `ArgosPacketDetailPage`) with route grouping, method filter, URL search, runtime capture toggle, and curl reproduction.
- **Pluggable storage** — `ArgosStorageAdapter` interface lets you back the capture log with MMKV, SharedPreferences, a file, or your own engine.
- **Dynamic proxy** — wire `ArgosConfig.proxyProvider` to your debug-only proxy gate; replace at runtime.
- **FPS monitor** — opt-in frame-rate sampling via `ArgosCapability.fps`.

## Install

```yaml
dependencies:
  argos: ^0.1.0
```

## Quick start

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

  // Optional: enable native interception (iOS NSURLProtocol + Android OkHttp)
  ArgosNativeCapture.instance.enable();

  runApp(const MyApp());
}
```

To open the inspector:

```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const ArgosPacketListPage()),
);
```

## Storage

`ArgosPacketStorage` writes through the adapter you supply via `ArgosConfig.storageAdapter`. Without an adapter, captures are kept in memory only. A reference MMKV-backed adapter lives in the `example/` app.

## Native interception

`ArgosNativeCapture.instance.enable()` registers `ArgosURLProtocol` on iOS and arms the `ArgosOkHttpInterceptor` on Android. Captures from native HTTP layers stream back through the `dev.panoptes.argos/native_capture` event channel and merge into the same packet store as Dart-side captures.

## Configuration

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

Toggle capture at runtime:

```dart
ArgosManager.instance.captureEnabled = false;
```

## License

[MIT](LICENSE) · Copyright (c) 2022-2026 Argos Contributors.
