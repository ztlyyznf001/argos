## 1. Typed Tuning Foundation

- [x] 1.1 Add public numeric/color property descriptors and typed tuning value access with validation
- [x] 1.2 Implement the controller's retained values, schema reconciliation, mounted target registration, point discovery, update, and reset behavior
- [x] 1.3 Add `ArgosTunable` and the inspector-scoped registration bridge with default-only behavior outside an enabled scope
- [x] 1.4 Add focused tests for defaults, updates, clamping, schema reconciliation, parent rebuild persistence, reset, disabled scope, and nested target discovery

## 2. Inspector Editing Experience

- [x] 2.1 Add optional controller ownership to `ArgosWidgetInspector` without changing disabled passthrough behavior
- [x] 2.2 Associate direct long-press selections with live tuning targets and preserve the existing unregistered fallback
- [x] 2.3 Add phone-friendly numeric sliders, arbitrary-color hexadecimal/HSVA controls, optional color shortcuts, current values, and target reset controls to direct node details
- [x] 2.4 Add widget tests for registered/unregistered details, live numeric/arbitrary-color updates, reset, and controller lifecycle behavior

## 3. Integration and Documentation

- [x] 3.1 Export the tuning APIs and add an example target covering font size, padding, opacity, color, and border radius
- [x] 3.2 Document setup, supported property patterns, controller lifetime, reset behavior, and limitations in English and Chinese READMEs

## 4. Validation

- [x] 4.1 Format changed Dart sources and run static analysis plus the complete Flutter test suite
- [x] 4.2 Run the example widget test and strict OpenSpec validation for `runtime-widget-tuning`

## 5. Color Editing Follow-up

- [x] 5.1 Add a compact built-in quick palette to every arbitrary-color editor while preserving custom and host-declared colors
- [x] 5.2 Extend the example and English/Chinese documentation with independently tunable font and background colors
- [x] 5.3 Add focused quick-palette/font-color coverage and rerun formatting, analysis, tests, strict OpenSpec validation, and simulator verification

## 6. Compact Multiple-Color Editing

- [x] 6.1 Group multiple color properties into labeled tabs with only the selected arbitrary-color editor expanded
- [x] 6.2 Cover tab switching and independent values, then rerun formatting, analysis, tests, strict OpenSpec validation, and simulator verification
