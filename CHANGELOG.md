## 0.1.0

First public release.

### Features

- Native HTTP capture: `NSURLProtocol` on iOS, `OkHttp Interceptor` on Android.
- Dart-layer HTTP capture via `HttpOverrides` (covers any `dart:io` HTTP path).
- Inspector UI: `ArgosPacketListPage` / `ArgosPacketDetailPage` with route grouping, method filter, URL search, runtime capture toggle, curl reproduction.
- Pluggable storage via `ArgosStorageAdapter` — bring your own MMKV / SharedPreferences / file backend.
- Dynamic proxy provider through `ArgosConfig.proxyProvider`.
- FPS monitor, opt-in via `ArgosCapability.fps`.
