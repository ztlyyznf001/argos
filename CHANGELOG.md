## 0.3.1

First version published to pub.dev, under the package name **`argos_inspector`** (the name `argos` was rejected by pub.dev as too similar to the existing `argo` package). `0.3.0` was tagged on GitHub under the old `argos` name but never published; `0.3.1` is functionally identical plus the package rename and lint fix below.

### Changed

- **Package renamed `argos` → `argos_inspector`** for pub.dev. Imports are now `package:argos_inspector/argos_inspector.dart`; the dependency is `argos_inspector: ^0.3.1`. All public class/API names (`ArgosManager`, `ArgosConfig`, `ArgosCapability`, etc.) are unchanged — only the package/import name changed. The GitHub repository remains `ztlyyznf001/argos`.

### Fixed

- Add braces to a single-statement `if` in `ArgosPacketDetailPage._parseFormBody` that `dart format` had wrapped across two lines, which tripped the `curly_braces_in_flow_control_structures` lint and made `flutter analyze` exit non-zero. No behavioural change.

## 0.3.0

This release bundles four changes landed since `0.2.0`, expanding Argos from "network + basic FPS" into a four-signal APM tool (network, crash, jank, resource) with an event-type-aware Inspector and a hardened storage layer.

### Added

- **Crash / error capture monitor** — `ArgosCapability.crash` captures Flutter framework errors (`FlutterError.onError`) and unhandled Dart exceptions (`runZonedGuarded` / `PlatformDispatcher.onError`), recording error type, message, stack trace, originating route, and timestamp into the shared APM data flow. New `ArgosCrashMonitor` (`lib/apm/argos_crash_monitor.dart`) and `ArgosCrashInfo` model.
- **Jank / dropped-frame analysis monitor** — `ArgosCapability.jank` extends `FrameTiming` sampling to detect frames exceeding the frame budget, splits build vs raster time, aggregates contiguous jank intervals, and emits structured jank events. New `ArgosJankMonitor` (`lib/apm/argos_jank_monitor.dart`) and `ArgosJankInfo` model.
- **Resource (memory) monitor** — `ArgosCapability.resource` periodically samples process memory (RSS / maxRss) and emits resource-sample events. New `ArgosResourceMonitor` (`lib/apm/argos_resource_monitor.dart`) and `ArgosResourceInfo` model.
- New `ArgosConfig` fields (all backward-compatible defaults): `resourceMaxRecords` (default `50`), `jankThresholdMultiplier` (default `1.0`), `resourceSampleInterval` (default `2s`), and `storagePersistInterval` (default `5s`).
- New public exports in `lib/argos.dart`: the crash / jank / resource models and monitors, plus the shared `argos_ui_kit` (`lib/ui/argos_ui_kit.dart`).

### Changed

- **Event-type-aware Inspector UI** — the packet list filter is now two-level: first by event type (all / network / crash / jank / resource), with the HTTP method filter shown only when "network" is selected; each type chip shows its current record count. Contiguous resource samples collapse into a single expandable aggregate (sample count, current / peak RSS, trend). The detail page now dispatches by record kind: network keeps the request / response tabs, while crash, jank, and resource records get purpose-built views (crash: message + copyable stack + route; jank: dropped-frame count, interval span, max frame, build/raster split; resource: RSS values + sample time). Network rows gained response-body size and relative + absolute timestamps, and all colors now derive from `Theme.of(context).colorScheme` for correct light/dark contrast.
- **Hardened storage concurrency** — `ArgosPacketStorage.clear()` and `getAllAsync()` now serialize through the write chain instead of bypassing it, closing a clear-vs-write race and preventing reads of in-flight write state. Writes are coalesced (`storagePersistInterval`) so the synchronous `jsonEncode` no longer runs on every append.
- **Per-kind storage retention** — retention is now a per-`kind` FIFO rather than a single shared `maxPacketRecords` total. Resource records are bounded independently by `resourceMaxRecords`, so routine memory samples can never evict a captured crash or network request. `maxPacketRecords` keeps its meaning for non-resource kinds.

## 0.2.0

### Added

- Native capture example demo wired through `MethodChannel`: `NativeDemoChannel` on iOS (`example/ios/Runner/NativeDemoChannel.swift`) and Android (`example/android/app/src/main/kotlin/com/example/example/NativeDemoChannel.kt`), plus `example/lib/native_demo_page.dart` exercising native HTTP from the example app.
- MMKV-backed `ArgosStorageAdapter` sample (`example/lib/mmkv_storage_adapter.dart`) showing how to plug a persistent backend into Argos.
- `native-capture-example` capability spec under `openspec/specs/` documenting the demo wiring.

### Changed

- Native capture pipeline now honours runtime configuration: events are dropped when `ArgosManager.captureEnabled` is `false`, and stored records are capped at `ArgosConfig.maxPacketRecords` (defaulting to 200) instead of an unconditional 200.
- Android `OkHttpInterceptor` reads response bodies using the response's declared content-type charset instead of forcing UTF-8, matching the iOS path's behavior.
- Silenced analyzer noise on `ArgosFpsInfo.type` and `ArgosHttpInfo.type` overridden field initialisers with targeted `// ignore: overridden_fields` annotations.
- Test bootstrap order in `test/argos_test.dart` now calls `TestWidgetsFlutterBinding.ensureInitialized()` before binding accessors, fixing flake on newer Flutter test harnesses.

### Breaking

- Android plugin build toolchain bumped: Kotlin `1.9.0` → `2.0.21`, Android Gradle Plugin `7.4.0` → `8.7.3`, `compileSdk` `33` → `36`, source/target compatibility moved to Java 17, and the plugin now declares `namespace 'dev.panoptes.argos'`. Downstream Android apps consuming Argos must be on AGP 8.x with JDK 17 toolchains; AGP 7 / JDK 11 hosts will fail to configure.
- Removed the unused `compileOnly 'io.flutter:flutter_embedding_debug:1.0.0-3316dd8728419ad3534e3f6112aa6291f587078a'` dependency from the plugin `build.gradle`; downstream builds that pinned to that artifact's presence should drop the reference.

## 0.1.0

First public release.

### Features

- Native HTTP capture: `NSURLProtocol` on iOS, `OkHttp Interceptor` on Android.
- Dart-layer HTTP capture via `HttpOverrides` (covers any `dart:io` HTTP path).
- Inspector UI: `ArgosPacketListPage` / `ArgosPacketDetailPage` with route grouping, method filter, URL search, runtime capture toggle, curl reproduction.
- Pluggable storage via `ArgosStorageAdapter` — bring your own MMKV / SharedPreferences / file backend.
- Dynamic proxy provider through `ArgosConfig.proxyProvider`.
- FPS monitor, opt-in via `ArgosCapability.fps`.
