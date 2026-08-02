## Why

Argos can already show captured network and APM records on a phone, but diagnosing a UI problem still requires connecting the app to Flutter DevTools. Developers need an opt-in, on-device way to inspect the live Flutter widget hierarchy and basic layout information while reproducing the problem.

## What Changes

- Add a public on-device widget inspector that captures the mounted `Element` tree into a safe, immutable snapshot.
- Add a mobile-friendly hierarchy UI with expand/collapse, type search, refresh, and a detail view with readable widget ancestry, identity, key, depth, diagnostics, and render bounds.
- Add an optional app wrapper with a runtime long-press inspection switch and a floating launcher for the complete hierarchy, without adding a route or wiring a navigator key.
- Keep the launcher disabled unless explicitly enabled, and document debug-only integration to avoid exposing application structure in production.
- Add widget tests and an example-app entry point demonstrating the feature.

## Capabilities

### New Capabilities
- `mobile-widget-inspection`: On-device capture, direct long-press selection, navigation, search, refresh, detail display, and optional floating access for the mounted Flutter widget tree.

### Modified Capabilities

None.

## Impact

- Adds public Dart APIs under `lib/ui/` and exports them from `argos_inspector.dart`.
- Updates the example app and English/Chinese README integration guidance.
- Adds no third-party or platform-native dependency; the feature uses Flutter framework element, diagnostics, and render-object APIs.
- Snapshotting traverses the live element tree only on user request, so no continuous inspection work is added to normal app rendering.
