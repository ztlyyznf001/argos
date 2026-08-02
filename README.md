# Argos

> All-seeing Flutter APM and HTTP packet capture plugin.
>
> Named after Argus Panoptes, the hundred-eyed giant of Greek myth — Argos watches every request your app makes.

[中文文档](README_zh.md) · MIT License · Flutter ≥ 3.0

## Features

- **Native HTTP capture** — `NSURLProtocol` on iOS and `OkHttp Interceptor` on Android, so traffic from native SDKs (not just Dart's `HttpClient`) is recorded.
- **Dart HTTP capture** — `HttpOverrides`-based interception for any code paths that flow through `dart:io` HTTP.
- **Record inspector UI** — built-in pages (`ArgosPacketListPage` / `ArgosPacketDetailPage`) with route grouping, method filter, URL search, runtime capture toggle, and curl reproduction.
- **On-device Widget Inspector** — long-press the UI on iOS or Android to inspect the corresponding Flutter widget's key, diagnostics, and layout bounds, or use the floating launcher to browse the complete hierarchy.
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

## On-device Widget Inspector

For a floating debug entry point, compose `ArgosWidgetInspector` inside
`MaterialApp.builder`. It discovers the app Navigator automatically, so no
navigator key or named route is required:

```dart
import 'package:flutter/foundation.dart';
import 'package:argos_inspector/argos_inspector.dart';

MaterialApp(
  builder: (context, child) => ArgosWidgetInspector(
    enabled: kDebugMode,
    child: child!,
  ),
  home: const MyHomePage(),
);
```

If the app already has a builder, wrap its existing result with
`ArgosWidgetInspector` instead of replacing the other wrappers.

Once enabled, Argos shows a **Long-press inspection** switch beside the full-tree
launcher. The switch defaults off so normal host long presses are unaffected.
Turn it on, then **long-press a widget on the page** to capture the deepest laid-out
node at that position, highlight its bounds, and immediately show its key,
widget ancestry, size, and diagnostics. There is no need to open or search the
tree first. The floating Widget icon remains an entry point to the complete
hierarchy for inspecting ancestors, expanding/collapsing nodes, searching by
type/key/diagnostics, and refreshing the snapshot. Capture work only occurs on
a long press, when opening the full tree, or when refreshing it.

Internal debug builds can opt into an initially enabled mode explicitly:

```dart
ArgosWidgetInspector(
  enabled: kDebugMode,
  longPressInitiallyEnabled: true,
  child: child!,
)
```

The detail surface presents readable widget ancestry such as
`… › Column › TextButton › RichText`. Snapshots still use numeric paths like
`0/0/0/6/0` internally to identify nodes. Flutter commonly inserts many
single-child wrappers, so their child index is repeatedly zero; the raw path is
therefore no longer presented as the primary hierarchy information.

Argos participates in Flutter's normal gesture arena. If a host widget owns and
wins its own long-press gesture, the host behavior is preserved; use the
floating full-tree entry point for that widget instead.

### Runtime tuning

Flutter widgets are immutable, so Argos does not use reflection to mutate
arbitrary constructor arguments. Wrap a region that should be adjustable in an
`ArgosTunable` with a stable ID, bounded property descriptors, and a builder:

```dart
ArgosTunable(
  id: 'home.title',
  label: 'Home title',
  properties: const <ArgosTuningProperty>[
    ArgosDoubleTuningProperty(
      id: 'fontSize',
      label: 'Font size',
      initialValue: 20,
      min: 12,
      max: 36,
      divisions: 12,
      decimalPlaces: 0,
    ),
    ArgosColorTuningProperty(
      id: 'textColor',
      label: 'Text color',
      initialValue: Colors.deepPurple,
    ),
  ],
  builder: (context, values) => Text(
    'Tunable title',
    style: TextStyle(
      fontSize: values.doubleValue('fontSize'),
      color: values.colorValue('textColor'),
    ),
  ),
)
```

With long-press inspection enabled, long-press any descendant of that region.
The detail sheet adds a **Runtime tuning** section with bounded numeric sliders,
an arbitrary-color editor with hexadecimal and HSVA controls, a compact row of
built-in quick colors, live rebuilding, and a per-target reset action. Width,
height, uniform padding, opacity, font size, and border radius can all be
represented by bounded numeric properties. Separate color properties can tune
text and background colors independently; when a target declares multiple
color properties, the inspector groups them into tabs and expands only the
selected color editor. Optional `ArgosTuningColorOption` entries can add
host-specific shortcuts without restricting custom values.

Overrides normally live for the `ArgosWidgetInspector` State lifetime and
survive ordinary parent rebuilds. To own that lifetime or call `resetTarget` /
`resetAll` programmatically, supply and dispose a controller from host State:

```dart
final tuningController = ArgosTuningController();

ArgosWidgetInspector(
  enabled: kDebugMode,
  tuningController: tuningController,
  child: child!,
)

// State.dispose:
tuningController.dispose();
```

Overrides are memory-only: they are not written to application storage and do
not generate source edits. When the inspector is disabled, `ArgosTunable` uses
its declared defaults and does not register a live target. The first version
supports registered bounded numbers and arbitrary colors, not callbacks,
application data, or arbitrary object graphs.

To use your own entry point, capture before pushing the page so the snapshot
does not include the inspector route itself:

```dart
final snapshot = ArgosWidgetSnapshot.captureBindingRoot();
if (snapshot != null) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ArgosWidgetInspectorPage(
        initialSnapshot: snapshot,
      ),
    ),
  );
}
```

The snapshot is bounded to 5,000 nodes and 200 levels by default and is only
rebuilt on an enabled-mode long press, when the inspector opens, or when refresh is tapped. Widget diagnostics can
contain application text and configuration values, so gate this feature with
`kDebugMode` (or an internal-build flag) and do not expose it in production.

## Diagnostic sessions

Argos groups network, native-network, crash, jank, and resource records into a
single ordered diagnostic session. The default `ArgosSessionMode.automatic`
starts recording on the first `init()` when `enableStorage` is true. Use manual
mode when the host should define the exact reproduction window:

```dart
ArgosManager.instance.init(
  config: ArgosConfig(
    sessionMode: ArgosSessionMode.manual,
    enableStorage: true,
    storageAdapter: MyAdapter(),
  ),
  listener: (event) {
    final metadata = event?.eventMetadata;
    debugPrint('${metadata?.sessionId}:${metadata?.sequence}');
  },
);

final session = ArgosManager.instance.startSession(
  label: 'checkout repro',
  attributes: {'build': 'debug'},
);
ArgosManager.instance.pauseSession();
ArgosManager.instance.resumeSession();
await ArgosManager.instance.stopSession();

final sessions = await ArgosManager.instance.getSessions();
final records = await ArgosManager.instance.getSessionRecords(session.id);
```

`captureEnabled` remains source-compatible: `false` pauses the active session;
`true` resumes it, or starts a new one from idle. The gate now applies to every
persistable event kind, not only HTTP. An explicitly started session also works
with `enableStorage: false` or no adapter: events still carry metadata and reach
the listener, while storage queries remain empty.

`maxSessions` defaults to 5. Completed sessions are evicted oldest-first as
whole units; per-kind `maxPacketRecords` / `resourceMaxRecords` limits apply
inside each active session.

Automatic mode keeps the backward-compatible process strategy by default: one
initialized process keeps one session until it is explicitly stopped or the
process is interrupted. Opt into adaptive boundaries when a long-running app
should separate unrelated diagnostic windows:

```dart
var cachedContext = ArgosSessionContext(
  fingerprint: 'account-42|tenant-a',
  attributes: {'tenant': 'tenant-a'},
);

ArgosManager.instance.init(
  config: ArgosConfig(
    enableStorage: true,
    storageAdapter: MyAdapter(),
    automaticSessionPolicy: ArgosAutomaticSessionPolicy.adaptive(
      backgroundTimeout: const Duration(minutes: 2),
      maxDuration: const Duration(minutes: 30),
      // Keep this callback synchronous and cheap; return cached host state.
      contextProvider: () => cachedContext,
    ),
  ),
);
```

Adaptive mode creates a new session ID after the app returns from a background
period at least as long as `backgroundTimeout`, before the first event accepted
at or after `maxDuration`, or before the first event whose context fingerprint
changed. A shorter background period, route change, repeated lifecycle event,
or explicit pause/resume keeps the existing ID. Manual sessions and sessions
created by an explicit `startSession()` are never taken over by this policy.

The fingerprint is compared in memory and is not persisted. Only `attributes`
are stored, so put only redacted diagnostic labels there; do not perform I/O or
return raw credentials from `contextProvider`. Set either duration to `null` to
disable that boundary. Automatic rollover end reasons are available as
`backgroundTimeout`, `maxDuration`, and `contextChanged`.

## Storage

`ArgosPacketStorage` writes through the adapter supplied via
`ArgosConfig.storageAdapter`. It stores a versioned session/record envelope and
can migrate the previous flat record list. Without an adapter, persistence is a
safe no-op and the listener-only session flow remains available. A reference
MMKV-backed adapter lives in the `example/` app.

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
  sessionMode: ArgosSessionMode.automatic,
  automaticSessionPolicy: const ArgosAutomaticSessionPolicy.process(),
  // Or opt in with ArgosAutomaticSessionPolicy.adaptive(...)
  maxSessions: 5,
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
