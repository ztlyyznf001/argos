## ADDED Requirements

### Requirement: On-demand bounded widget tree snapshot
The library SHALL capture a mounted Flutter element subtree only on explicit request and return an immutable snapshot containing a stable structural path, widget type, key text when present, depth, short description, bounded diagnostic properties, child nodes, and global render bounds when available. Capture MUST enforce configurable depth and node-count limits and MUST report when traversal is truncated.

#### Scenario: Capture a mounted subtree
- **WHEN** a caller captures a mounted subtree containing nested keyed widgets and laid-out render boxes
- **THEN** the snapshot contains their hierarchy, types, key text, depths, diagnostics, and available global bounds without retaining live element references

#### Scenario: Bound a large hierarchy
- **WHEN** traversal reaches the configured maximum depth or node count
- **THEN** capture stops adding nodes beyond the limit, returns the nodes already visited, and marks the snapshot as truncated

#### Scenario: Tolerate unavailable diagnostics or layout
- **WHEN** a node is unmounted, not laid out, not backed by a render box, or throws while producing diagnostics
- **THEN** capture continues for the remaining accessible tree and leaves unavailable fields empty rather than failing the snapshot

### Requirement: Mobile hierarchy navigation and search
The library SHALL provide a phone-sized inspector page that displays the snapshot as an indented hierarchy, allows nodes with children to expand and collapse, and filters case-insensitively by widget type, key, description, or diagnostic text. Search results MUST include the ancestor path of each match.

#### Scenario: Navigate the hierarchy
- **WHEN** the page opens with a non-empty snapshot and no search query
- **THEN** it shows the root node and allows the user to reveal or hide descendant rows using node expansion controls

#### Scenario: Search for a descendant
- **WHEN** the user enters text matching a collapsed descendant by type, key, description, or diagnostics
- **THEN** the page shows that descendant together with the ancestor rows needed to understand its position

#### Scenario: Search has no matches
- **WHEN** the user enters a query that matches no snapshot node
- **THEN** the page displays a clear no-results state and remains refreshable

### Requirement: Widget node details
The inspector page SHALL allow a user to select a visible node and SHALL show an in-page detail surface containing its type, readable widget-type ancestry, depth, key, child count, bounds, short description, and diagnostic properties. The raw numeric structural path SHALL remain available to the snapshot model for node identity but SHALL NOT be the primary user-facing hierarchy label. The detail surface MUST be closable without closing or mutating the host application.

#### Scenario: Inspect a laid-out keyed widget
- **WHEN** the user selects a keyed node with known render bounds
- **THEN** the detail surface shows the key, global position and size, identity fields, description, and captured diagnostics

#### Scenario: Inspect a node without bounds
- **WHEN** the user selects a node whose global bounds were unavailable at capture time
- **THEN** the detail surface labels bounds as unavailable and still shows the remaining metadata

#### Scenario: Inspect a deeply wrapped node
- **WHEN** the selected node is nested below many single-child Flutter wrappers
- **THEN** the detail surface shows a bounded breadcrumb of widget type names instead of a long sequence of numeric zero indexes

### Requirement: Explicit snapshot refresh
The inspector page SHALL expose a refresh action that replaces the displayed snapshot with a newly captured tree, updates the capture time and truncation state, clears stale selection state, and preserves the current search query where possible.

#### Scenario: Refresh after the host tree changes
- **WHEN** the host subtree changes and the user invokes refresh
- **THEN** the hierarchy reflects the new snapshot, no longer exposes a selected node from the old snapshot, and retains the active search text

### Requirement: Optional floating mobile entry point
The library SHALL provide an opt-in wrapper that can place an accessible floating inspector launcher above host content and open the inspector without requiring host route registration or a navigator key. The wrapper MUST preserve the mounted host child while the inspector is opened and closed, and MUST return the child directly when disabled.

#### Scenario: Open and close from the launcher
- **WHEN** the wrapper is enabled and the user taps the floating launcher
- **THEN** it captures the wrapped host subtree, displays the inspector above the still-mounted host, and closing the inspector reveals the same host state

#### Scenario: Wrapper is disabled
- **WHEN** the wrapper is built with inspection disabled
- **THEN** no launcher or inspection layer is present and the wrapper returns the host child without snapshot traversal

#### Scenario: Host handles system back
- **WHEN** the inspector overlay is open and the user invokes the system back action
- **THEN** the inspector closes before the host route is popped

### Requirement: Direct long-press widget inspection
When the opt-in wrapper is enabled, the library SHALL expose a visible runtime switch for long-press inspection. The switch SHALL default to off unless the host explicitly requests an initially enabled state. While the switch is on, the library SHALL let a user long-press host content to select the deepest captured widget with layout bounds containing the press position. It SHALL immediately show the selected widget's detail surface and a visual indication of its captured bounds without first opening or searching the hierarchy page. The floating launcher SHALL remain available as an auxiliary entry point for inspecting the complete tree.

#### Scenario: Enable long-press inspection
- **WHEN** the wrapper is enabled and the user turns on the long-press inspection switch
- **THEN** the switch exposes an active state and subsequent eligible host long presses perform widget inspection

#### Scenario: Long-press mode is off
- **WHEN** the long-press inspection switch is off and the user long-presses host content
- **THEN** Argos performs no snapshot traversal or selection and the host gesture behavior remains available

#### Scenario: Long-press a visible widget
- **WHEN** the user long-presses a laid-out widget while the wrapper and long-press inspection mode are enabled
- **THEN** the wrapper captures the current host subtree, selects the deepest bounded node under the press position, highlights its bounds, and opens its details

#### Scenario: Close direct details
- **WHEN** direct details are visible and the user closes them or invokes system back
- **THEN** the detail surface and highlight disappear before the host route is popped, and the same host state remains mounted

#### Scenario: Disabled wrapper preserves host gestures
- **WHEN** the wrapper is disabled and the user long-presses host content
- **THEN** the wrapper adds no gesture detector, snapshot traversal, detail surface, or highlight

### Requirement: Safe integration guidance
The package documentation SHALL show route-based and `MaterialApp.builder` integrations, SHALL recommend gating the feature with `kDebugMode` or an equivalent internal-build flag, and SHALL warn that widget diagnostics may contain application data.

#### Scenario: Developer follows the quick-start guide
- **WHEN** a developer integrates the documented builder example in a debug build
- **THEN** the floating launcher can open the inspector on iOS or Android without native configuration or an added dependency
