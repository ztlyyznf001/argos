## ADDED Requirements

### Requirement: Hosts can register typed runtime tuning targets
The package SHALL provide an opt-in tunable widget API with a stable target ID, a display label, typed property descriptors, and a builder that receives the current typed values. The first version SHALL support bounded numeric properties and arbitrary color properties; a color property MAY additionally declare shortcut colors without restricting accepted custom values.

#### Scenario: Tunable widget builds from defaults
- **WHEN** a tunable widget is built without any runtime overrides
- **THEN** its builder receives every descriptor's declared initial value

#### Scenario: Tunable widget is outside an enabled inspector
- **WHEN** a tunable widget has no enabled inspector tuning scope
- **THEN** it builds from defaults and creates no live tuning registration

### Requirement: Tuned values rebuild safely and survive parent rebuilds
The controller SHALL validate updates against the registered descriptor, rebuild the owning tunable widget immediately, and retain compatible overrides by target and property ID for its lifetime.

#### Scenario: Numeric value changes
- **WHEN** a developer moves a registered numeric control within its configured range
- **THEN** the tunable builder receives the new value and the rendered widget updates

#### Scenario: Parent rebuilds after an edit
- **WHEN** the host parent rebuilds without replacing the inspector controller or changing the compatible property schema
- **THEN** the tuned value remains active

#### Scenario: Invalid update is requested
- **WHEN** an update has an unknown property ID, an incompatible type, or a numeric value outside the declared range
- **THEN** the controller rejects or clamps the update without delivering an invalid builder value

#### Scenario: Arbitrary color update is requested
- **WHEN** an update supplies any valid Flutter Color to a registered color property
- **THEN** the controller accepts the value even when it was not declared as a shortcut color

### Requirement: Long press discovers the nearest registered target
While long-press inspection is enabled, the inspector SHALL associate a direct selection with the smallest mounted tuning target whose global render bounds contain the press position.

#### Scenario: Nested targets contain the press
- **WHEN** two mounted tuning target bounds contain the long-press position
- **THEN** the inspector selects the target with the smallest render area for editing

#### Scenario: No tuning target contains the press
- **WHEN** the selected widget is not inside a mounted tuning target with usable bounds
- **THEN** the existing read-only node detail and highlight behavior remains unchanged

### Requirement: Direct details provide runtime editing and reset controls
The direct long-press detail surface SHALL show the associated target label, a suitable control for each supported property, its current value, and an action that resets all properties on that target.

#### Scenario: Numeric property is displayed
- **WHEN** a selected target declares a numeric property
- **THEN** the detail surface shows its label, current formatted value, and a bounded slider

#### Scenario: Color property is displayed
- **WHEN** a selected target declares a color property
- **THEN** the detail surface shows its label, current color, hexadecimal input, and controls for hue, saturation, brightness, and alpha

#### Scenario: Optional shortcut color is selected
- **WHEN** a color property declares shortcut colors and the developer selects one
- **THEN** that shortcut is applied without removing the ability to enter or tune an arbitrary color

#### Scenario: Built-in quick color is selected
- **WHEN** the developer selects a common color from the editor's built-in quick palette
- **THEN** that color is applied immediately while hexadecimal and HSVA controls remain available for arbitrary values

#### Scenario: Text and background colors are tuned independently
- **WHEN** a target declares separate color properties for foreground text and its background
- **THEN** the detail surface edits and rebuilds each property independently

#### Scenario: Multiple color properties share a compact editor
- **WHEN** a target declares more than one color property
- **THEN** the detail surface presents those property labels as tabs and expands only the selected property's color controls

#### Scenario: Color tab selection changes
- **WHEN** the developer switches from one color property tab to another
- **THEN** the editor shows the selected property's current color and controls without changing either property's value

#### Scenario: Target is reset
- **WHEN** the developer activates reset for the selected target
- **THEN** all of that target's values return to their declared defaults and its widget rebuilds

### Requirement: Runtime tuning remains opt-in and ephemeral
The package SHALL NOT use reflection, mutate arbitrary unregistered widgets, persist tuning values to application storage, or install tuning state when the inspector is disabled.

#### Scenario: Inspector is disabled
- **WHEN** `ArgosWidgetInspector.enabled` is false
- **THEN** the host child is returned directly and registered widgets use source defaults

#### Scenario: Controller lifetime ends
- **WHEN** the owning tuning controller is disposed and a new controller is created
- **THEN** prior runtime overrides are no longer available
