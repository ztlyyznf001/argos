## Purpose

Document the example app flow that demonstrates native HTTP capture on iOS and Android, including startup wiring, platform-specific trigger buttons, storage behavior, and README guidance.

## Requirements

### Requirement: Example app SHALL enable native HTTP capture and respect the capture toggle

`example/lib/main.dart` MUST invoke `ArgosNativeCapture.instance.enable()` after `ArgosManager.instance.init`, regardless of build mode, so the iOS `NSURLProtocol` and Android `OkHttp Interceptor` data path is wired on app start. Whether captured native packets are persisted MUST be gated by `ArgosManager.instance.captureEnabled` — the same flag the inspector's pause/resume button toggles and that `ArgosHttpMonitor` already honors for Dart-side traffic.

#### Scenario: App start wires native capture

- **WHEN** the example app starts (debug or release)
- **THEN** `ArgosNativeCapture.instance.enable()` is called exactly once before the first user interaction

#### Scenario: Capture toggle on records native packets

- **GIVEN** `ArgosManager.instance.captureEnabled` is `true`
- **WHEN** a native HTTP request initiated by the demo completes
- **THEN** an entry for the request appears in `ArgosPacketStorage` and `ArgosPacketListPage`

#### Scenario: Capture toggle off suppresses native packets

- **GIVEN** the user has tapped the pause button in `ArgosPacketListPage`, flipping `ArgosManager.instance.captureEnabled` to `false`
- **WHEN** a native HTTP request initiated by the demo completes
- **THEN** no new entry is appended to `ArgosPacketStorage`
- **AND** flipping the toggle back to `true` resumes recording on the next request without restarting the app

### Requirement: Example app SHALL provide a native capture demo page

The example app MUST expose a dedicated page (`NativeCaptureDemoPage`, route `/nativeDemo`) reachable from `MyHomePage` that lets the user trigger HTTP requests originated from native code on the host platform.

#### Scenario: Entry point is visible from home

- **WHEN** the user opens the example app and lands on `MyHomePage`
- **THEN** a button labelled "原生抓包 demo" (or the English equivalent) is visible
- **AND** tapping it pushes the `/nativeDemo` route

#### Scenario: Demo page exposes platform-specific buttons

- **WHEN** the user views `NativeCaptureDemoPage`
- **THEN** the page shows an "iOS 原生请求" action and an "Android 原生请求" action
- **AND** the page shows a shortcut to the existing `/packets` inspector

#### Scenario: Cross-platform fallback

- **WHEN** the example app runs on a platform other than iOS or Android (e.g. macOS desktop, web)
- **THEN** the platform-specific button is rendered as disabled
- **AND** a hint indicates the action is only available on the matching mobile platform

### Requirement: iOS demo SHALL fire a request via NSURLSession from native code

When the user taps the iOS button, the example app MUST invoke a Swift code path that uses `URLSession` (the shared session or a default-configured session) to issue an HTTPS GET request, so the request flows through the registered `ArgosURLProtocol`.

#### Scenario: Tapping the iOS button records a native packet

- **WHEN** the user taps "iOS 原生请求" while running on iOS
- **THEN** Dart invokes `MethodChannel('argos_example/native_demo')`'s `sendIosRequest` method
- **AND** the iOS `MethodChannel` handler issues an `URLSession` GET request whose URL identifies the platform (e.g. contains `platform=ios`)
- **AND** within a few seconds, an entry for that URL appears in `ArgosPacketListPage`

#### Scenario: Disabled when not on iOS

- **WHEN** the user views the demo page on Android, macOS, or web
- **THEN** the "iOS 原生请求" button is disabled

### Requirement: Android demo SHALL fire a request via an interceptor-equipped OkHttpClient

When the user taps the Android button, the example app MUST invoke a Kotlin code path that builds an `OkHttpClient` with `ArgosOkHttpInterceptor.instance` attached and issues an HTTPS GET request through it.

#### Scenario: Tapping the Android button records a native packet

- **WHEN** the user taps "Android 原生请求" while running on Android
- **THEN** Dart invokes `MethodChannel('argos_example/native_demo')`'s `sendAndroidRequest` method
- **AND** the Android handler builds an `OkHttpClient` whose `interceptors` list includes `ArgosOkHttpInterceptor.instance`
- **AND** the handler issues a GET request whose URL identifies the platform (e.g. contains `platform=android`)
- **AND** within a few seconds, an entry for that URL appears in `ArgosPacketListPage`

#### Scenario: Disabled when not on Android

- **WHEN** the user views the demo page on iOS, macOS, or web
- **THEN** the "Android 原生请求" button is disabled

### Requirement: Demo SHALL document setup steps

`example/README.md` MUST include a section describing how to run the native capture demo, including any required network access notes and the expected observation in `ArgosPacketListPage`.

#### Scenario: README explains demo

- **WHEN** a developer reads `example/README.md`
- **THEN** they find a section explicitly named "原生抓包 demo"（or English equivalent）
- **AND** the section lists at least: how to launch the demo, the two buttons to press, and what to look for in the inspector
