## Context

Argos currently exposes full-screen record pages that a host opens through its own `Navigator`, but it has no UI inspection capability. Flutter's mounted UI is represented by mutable `Element` and `RenderObject` trees whose objects become invalid as frames rebuild. An on-device inspector therefore has to avoid retaining live framework objects, remain usable in a narrow phone viewport, and add no work when the feature is not enabled.

The package supports Flutter 3.0 and Dart 2.17, so the implementation cannot depend on newer inspector APIs or add DevTools/service-protocol dependencies. The feature is intended for development and internal builds.

## Goals / Non-Goals

**Goals:**

- Capture the mounted subtree on demand into immutable, serializable-in-spirit Dart value objects.
- Make widget type, key, diagnostic properties, depth, child count, and global render bounds readable on a phone.
- Present hierarchy context as concise widget-type breadcrumbs rather than raw structural index strings.
- Support hierarchy navigation, search, selection details, and an explicit refresh.
- Support direct long-press selection for the common case without requiring hierarchy navigation.
- Offer an opt-in floating launcher that can cover the host app with the inspector without requiring a route or navigator key.
- Keep disabled integration effectively free and remain compatible with Flutter 3.0.

**Non-Goals:**

- Reimplement DevTools features such as source navigation, property editing, repaint-rainbow, performance timelines, or service-protocol connectivity.
- Continuously observe every rebuild or retain live `Element`, `Widget`, or `RenderObject` references.
- Enable inspection automatically in production builds.

## Decisions

### Capture immutable snapshots instead of exposing live elements

`ArgosWidgetSnapshot` will contain an immutable `ArgosWidgetNode` tree. Each node gets a structural path ID, widget type, key text, short description, depth, child count through its child list, a bounded list of single-line diagnostic properties, and an optional global `Rect` for laid-out `RenderBox` objects. Capture recursively visits mounted elements and catches diagnostics/layout failures per node so one unusual widget cannot abort the full snapshot.

The snapshot holds strings, numbers, rectangles, and child nodes only. This prevents stale-element access and memory retention after the host UI changes. The alternative—keeping `Element` references and reading them lazily—would provide fresher data but is unsafe across rebuilds and would couple the UI to framework lifecycle timing.

### Make traversal explicit and bounded

Snapshots are created only when the inspector opens or the user taps refresh. Capture accepts configurable `maxDepth` and `maxNodes` safety limits with conservative defaults, and exposes whether it was truncated. This avoids a pathological or generated tree freezing the UI thread. Continuous frame-by-frame tracking is rejected because it would distort the app being diagnosed.

### Use one self-contained inspector page for both route and overlay usage

`ArgosWidgetInspectorPage` renders the hierarchy, search field, refresh action, truncation notice, and an in-page modal detail panel. The detail panel is implemented inside the page rather than through `showModalBottomSheet`, so the page works even when displayed by the wrapper without a `Navigator` ancestor. With no supplied snapshot, the page can capture the binding root after its first frame; callers can also supply an initial snapshot and refresh callback.

When search is empty, expansion state controls visible descendants. When search is active, matching nodes and their ancestor paths are shown automatically. This keeps results understandable without flattening away hierarchy.

Node structural paths such as `0/0/0/6/0` remain internal snapshot identifiers. They naturally contain many zeroes because Flutter inserts many single-child wrapper elements. Detail surfaces derive a bounded breadcrumb from the immutable snapshot lineage and show widget types such as `… › Column › TextButton › RichText` instead of exposing the numeric identifier as the main hierarchy field.

### Provide an opt-in overlay wrapper

`ArgosWidgetInspector` is designed for `MaterialApp.builder`. When `enabled` is false it returns the child directly. When enabled, it wraps the child in a keyed content boundary plus a safe-area floating button. Opening first captures that content subtree, then discovers the root-most mounted `NavigatorState` below the content boundary and pushes an ephemeral inspector route. The route is created directly, so the host supplies neither a route registration nor a navigator key; standard system-back behavior closes it before any host route. If a host intentionally has no Navigator, the wrapper falls back to an in-place `Stack` layer with an explicit close action. In both cases the mounted host child is preserved.

The wrapper defaults to disabled. Documentation uses `enabled: kDebugMode` so production exposure is an explicit host decision. A route-based page remains public for teams that prefer their own entry point.

### Select the deepest bounded snapshot node on long press

When enabled, the wrapper shows a compact long-press mode switch next to the hierarchy launcher. The mode defaults off so merely enabling the debug tooling does not reserve host long presses; hosts may opt into an initially enabled state through configuration. The wrapper keeps a stable gesture wrapper around the mounted host but only installs its long-press callback while the runtime mode is on, preserving the host element subtree as the switch changes.

A completed enabled-mode long press captures a fresh immutable snapshot, compares the global press position with captured node bounds, and chooses the deepest matching node. This gives a direct path to the existing detail surface while keeping the hierarchy launcher available for ambiguous or advanced inspection. The selected bounds are converted into the wrapper's local coordinate space and outlined above a dimmed host surface.

The wrapper uses Flutter's gesture arena rather than a global raw-pointer listener. This means a host widget with its own winning long-press recognizer can keep ownership of that gesture; it also prevents ordinary child taps from firing after Argos accepts a long press. When `enabled` is false, the wrapper still returns the child directly and installs no recognizer.

### Use framework-only UI and diagnostics

The implementation uses Flutter material/widgets/rendering/foundation libraries already provided by the SDK. Diagnostic output is converted to bounded single-line name/value strings during capture. No VM service or platform channel is introduced, keeping iOS and Android behavior identical and avoiding new package dependencies.

## Risks / Trade-offs

- [Snapshot can already be stale after the next frame] → Display capture time and provide an explicit refresh action; label the model as a snapshot.
- [Very large trees can stall the UI isolate] → Enforce node/depth limits, stop traversal once reached, and show a truncation warning.
- [Widget diagnostics may contain application data] → Keep the launcher disabled by default and prominently document debug/internal-build use.
- [Some render objects are not boxes or are not laid out] → Treat bounds as optional and show “不可用” rather than failing capture.
- [A refreshed navigator subtree can include the inspector route itself] → The wrapper captures before opening and excludes its keyed inspector-page subtree on refresh; direct page use documents that supplying a snapshot gives the cleanest result.
- [MaterialApp.builder integration may conflict with another builder] → The API is a normal composable widget, so hosts can place it inside their existing builder output without replacing other wrappers.
- [A coordinate can belong to many nested widgets] → Select the deepest bounded node by default, show its readable ancestry, and retain the full hierarchy page for inspecting ancestors or overlapping widgets.

## Migration Plan

This is additive. Existing users require no changes. Interested hosts add the wrapper in `MaterialApp.builder` or navigate to the public page. Rollback consists of removing that integration; no stored data or native registration is involved.

## Open Questions

None for the first iteration. Coordinate-based selection and source-location integration can be proposed separately after the hierarchy workflow is validated.
