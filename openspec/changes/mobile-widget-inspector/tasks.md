## 1. Snapshot Model and Capture

- [x] 1.1 Add immutable public widget node/snapshot models with structural paths, captured metadata, timestamps, and truncation state
- [x] 1.2 Implement resilient bounded traversal for element diagnostics and global render bounds
- [x] 1.3 Add unit/widget tests for hierarchy metadata, immutability behavior, unavailable bounds, and node/depth truncation

## 2. Mobile Inspector UI

- [x] 2.1 Build the phone-friendly hierarchy page with expansion, indentation, capture status, and truncation feedback
- [x] 2.2 Implement case-insensitive type/key/description/diagnostic search with matching ancestor paths and no-results state
- [x] 2.3 Implement the self-contained node detail surface and explicit refresh behavior
- [x] 2.4 Add widget tests for hierarchy interaction, search, details, refresh, and dark/narrow layouts
- [x] 2.5 Replace raw numeric detail paths with bounded widget-type breadcrumbs derived from snapshot lineage

## 3. Floating Integration

- [x] 3.1 Add the opt-in wrapper and accessible floating launcher with navigator-free open, close, refresh, and system-back handling
- [x] 3.2 Export the public APIs and add wrapper tests proving disabled passthrough and host-state preservation
- [x] 3.3 Add direct long-press point selection, bounds highlighting, and immediate node details while retaining the hierarchy launcher
- [x] 3.4 Add tests for deepest bounded-node selection, direct detail close/back handling, and disabled long-press passthrough
- [x] 3.5 Add a default-off runtime long-press inspection switch with host-configurable initial state and preserved host state

## 4. Example and Documentation

- [x] 4.1 Integrate a debug-gated launcher into the example app without replacing its existing builder behavior
- [x] 4.2 Document route and wrapper integration, privacy guidance, limits, and mobile behavior in English and Chinese READMEs
- [x] 4.3 Document direct long-press inspection as the primary mobile interaction and the launcher as the full-tree fallback
- [x] 4.4 Document the runtime switch and explain that numeric structural paths remain internal identifiers

## 5. Verification

- [x] 5.1 Format changed Dart sources and run static analysis plus the complete Flutter test suite
- [x] 5.2 Run the example widget test and validate OpenSpec artifacts/tasks against the implemented behavior
- [x] 5.3 Format and validate the long-press interaction with focused tests, full analysis, and OpenSpec strict validation
- [x] 5.4 Test switch gating, readable ancestry, state preservation, and rerun full validation
