## Why

The widget inspector can identify and explain a widget, but developers still need to edit source and hot reload to test visual values. An opt-in runtime tuning surface would shorten that feedback loop while keeping Flutter's immutable widget model and production behavior intact.

## What Changes

- Add an opt-in tunable widget API that registers named, typed runtime values and rebuilds its widget from those values.
- Let long-press inspection discover the nearest registered tuning target and edit supported values directly from the node detail surface.
- Support bounded numeric controls and color controls suitable for width, height, uniform padding, opacity, font size, font color, background color, and border radius.
- Keep arbitrary color editing while also offering a compact built-in palette and optional host-declared shortcuts for common selections.
- Group multiple color properties into tabs so only one full color editor is expanded at a time on phone-sized detail sheets.
- Provide per-target reset behavior and preserve tuned values across ordinary parent rebuilds for the lifetime of the inspector controller.
- Keep runtime tuning disabled when the widget inspector is disabled and document that arbitrary unregistered widget constructor arguments cannot be mutated.

## Capabilities

### New Capabilities

- `runtime-widget-tuning`: Opt-in registration, discovery, editing, rebuilding, persistence, and reset semantics for runtime widget parameters.

### Modified Capabilities

<!-- None. Runtime tuning is an additive capability layered on the existing inspector. -->

## Impact

- Adds public Dart APIs for tuning controllers, typed properties, value access, and tunable widget builders.
- Extends the widget inspector wrapper and node detail overlay with optional tuning integration.
- Updates the example app, English and Chinese documentation, and widget tests.
- Introduces no native dependency, persistence store, reflection, or production-only behavior.
