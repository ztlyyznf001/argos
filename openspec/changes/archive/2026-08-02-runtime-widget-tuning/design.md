## Context

The existing inspector captures immutable diagnostic snapshots and can select the deepest bounded widget under a long press. Flutter widgets are immutable, Dart mirrors are unavailable in Flutter release builds, and a parent rebuild would overwrite direct `Element` or `RenderObject` mutations. The package also supports Dart 2.17 and Flutter 3.0, so the API and controls must avoid newer language and framework-only features.

Runtime tuning therefore needs an explicit bridge between a developer-owned widget builder and the inspector rather than attempting to reconstruct arbitrary widget constructors.

## Goals / Non-Goals

**Goals:**

- Provide an opt-in, typed API for numeric and color values.
- Rebuild a registered widget immediately when a value changes.
- Discover the smallest registered target containing a long-press point.
- Show editing and reset controls alongside the existing diagnostic details.
- Preserve overrides across ordinary parent rebuilds for the controller lifetime.
- Preserve disabled-inspector passthrough and Flutter 3.0 compatibility.

**Non-Goals:**

- Mutating arbitrary unregistered widget constructor arguments.
- Persisting overrides across application restarts or generating source patches.
- Editing callbacks, application data, enum values, complex object graphs, or native views in the first version.
- Enabling tuning in production without an explicit host opt-in.

## Decisions

### Use typed descriptors and a builder instead of reflection

`ArgosTunable` will accept a stable target ID, display label, typed property descriptors, and a builder that receives `ArgosTuningValues`. Numeric descriptors define a finite min/max range and optional divisions; color descriptors accept any Flutter `Color` and may define optional shortcut colors. This makes every edited value valid and lets the host decide how a value maps to width, padding, font size, opacity, border radius, or another visual argument.

Direct `Element.update`, `RenderObject` mutation, mirrors, and constructor reconstruction were rejected because they are incomplete, unstable across rebuilds, or unavailable on supported Flutter targets.

### Keep values and live registrations in an inspector-scoped controller

`ArgosTuningController` will own current values by target ID and maintain private live registrations for mounted `ArgosTunable` instances. `ArgosWidgetInspector` creates a controller when the host does not supply one and exposes it to descendants through an inherited scope. A caller-provided controller enables programmatic reset and a longer lifetime while preserving explicit ownership.

Values remain in the controller when a tunable widget rebuilds, so normal parent `setState` calls do not erase edits. They are in-memory only and disappear when the owning controller is disposed.

### Discover targets by mounted global bounds

Each registered target exposes bounds from a keyed subtree. On long press, the controller filters mounted targets whose global bounds contain the point and chooses the smallest area. This associates a deeply selected diagnostic node with its nearest practical tuning wrapper without storing mutable `Element` references inside immutable widget snapshots.

### Extend direct long-press details only

The direct detail overlay receives the discovered target ID and controller. It listens to controller updates, renders numeric sliders plus a hexadecimal/HSVA arbitrary-color editor, shows a compact horizontally scrollable built-in palette, optionally shows host-declared color shortcuts, and provides a target-level reset action. When a target declares multiple color properties, their labels become tabs above one shared editor and only the selected property's controls are built. This avoids repeating the tall palette and HSVA controls while preserving independent typed values. A single color property keeps the simpler untabbed presentation. The built-in palette is a convenience layer only and never restricts accepted colors. Full-tree snapshots remain read-only because they may describe stale nodes and do not retain a safe live association.

When a tuning target is present, the direct sheet uses the larger detail height so controls remain usable on a phone. Unregistered selections retain the current read-only UI.

Color properties remain purpose-agnostic at the API level. A host can register separate descriptors for background and foreground text colors, and map each typed value in its builder; the example demonstrates both so developers can discover the pattern without introducing a separate text-color property type.

### Keep disabled behavior inert

When `ArgosWidgetInspector.enabled` is false it returns its child directly and does not install the tuning scope. `ArgosTunable` then builds with descriptor defaults and registers nothing. This keeps the existing zero-inspection disabled path and avoids hidden production mutation state.

## Risks / Trade-offs

- **Target IDs collide** → Treat IDs as stable host-owned identifiers, keep only the latest mounted registration, and document uniqueness within one inspector scope.
- **A target has no laid-out render box** → Ignore it during point discovery and continue normal read-only inspection.
- **Large numbers of tunable widgets rebuild on controller notification** → Scope the feature to debug tooling and let each `ArgosTunable` skip rebuilding when its own values did not change.
- **A property schema changes during hot reload** → Reconcile values by property ID and compatible type, initialize new properties from defaults, and drop removed properties.
- **Slider-only numeric editing lacks arbitrary precision** → Descriptors expose host-chosen ranges and divisions; exact source editing remains outside this runtime tool.

## Migration Plan

The feature is additive. Existing hosts require no change. Hosts opt in by wrapping selected widgets with `ArgosTunable`; removing the wrapper restores the original source-controlled behavior. No stored data or native migration is required.

## Open Questions

None for the first version. Additional property types and source-patch export can be evaluated separately.
