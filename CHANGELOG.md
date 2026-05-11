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
