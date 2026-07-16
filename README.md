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
- **Crash / error capture** — opt-in via `ArgosCapability.crash`. Captures Flutter framework errors (`FlutterError.onError`) and unhandled Dart async exceptions (`PlatformDispatcher.onError`), preserving and chaining any handler the host already installed.
- **Jank analysis** — opt-in via `ArgosCapability.jank`. Detects dropped frames against the display's frame budget, splits build vs. raster time, and aggregates consecutive drops into jank-interval events.
- **Resource monitor** — opt-in via `ArgosCapability.resource`. Periodically samples process memory (`ProcessInfo.currentRss` / `maxRss`). CPU is left empty when not reliably obtainable in pure Dart.

All three are pure-Dart, add no third-party dependencies, and flow through the same `ArgosManager.listener` callback, storage, and Inspector UI as network captures.

## Install

```yaml
dependencies:
  argos_inspector: ^0.3.1
```

## Quick start

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
  apmTypes: [
    ArgosCapability.network,
    ArgosCapability.fps,
    ArgosCapability.crash,
    ArgosCapability.jank,
    ArgosCapability.resource,
  ],
  hostWhiteList: ['api.example.com'],
  enableStorage: true,
  maxPacketRecords: 500,   // retention cap PER non-resource kind (network / crash / jank)
  resourceMaxRecords: 50,  // separate cap for resource samples, so a fast sampler
                           // can never evict a captured crash or request
  storagePersistInterval: const Duration(seconds: 5), // coalesce disk writes;
                           // Duration.zero persists on every write (no loss window)
  proxyProvider: () => kDebugMode ? 'http://127.0.0.1:9091' : null,
  storageAdapter: MyMmkvAdapter(),
  // APM tuning (optional):
  jankThresholdMultiplier: 1.0, // frame is "dropped" when span > budget × this
  resourceSampleInterval: const Duration(seconds: 2),
);
```

Each capability is independently opt-in — only the entries you list in `apmTypes`
install their handlers/timers. Omitting `crash`/`jank`/`resource` leaves
`FlutterError.onError`, frame callbacks, and sampling untouched. Crash, jank, and
resource events appear in the same Inspector list as HTTP packets, tagged with a
distinct icon and label (崩溃 / 卡顿 / 资源).

Toggle capture at runtime:

```dart
ArgosManager.instance.captureEnabled = false;
```

## License

[MIT](LICENSE) · Copyright (c) 2022-2026 Argos Contributors.
