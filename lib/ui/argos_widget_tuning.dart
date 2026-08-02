import 'package:flutter/material.dart';

/// Builds a widget from the current runtime tuning values.
typedef ArgosTunableBuilder = Widget Function(
  BuildContext context,
  ArgosTuningValues values,
);

/// Describes one value that an [ArgosTunable] exposes to the inspector.
abstract class ArgosTuningProperty {
  const ArgosTuningProperty({
    required this.id,
    required this.label,
  })  : assert(id != ''),
        assert(label != '');

  /// Stable identifier used by [ArgosTuningValues].
  final String id;

  /// Human-readable label shown in the on-device editor.
  final String label;

  /// Source-controlled value used before an override exists and after reset.
  Object get initialValue;

  bool accepts(Object value);

  Object normalize(Object value);
}

/// A bounded numeric tuning property rendered as a slider.
class ArgosDoubleTuningProperty extends ArgosTuningProperty {
  const ArgosDoubleTuningProperty({
    required String id,
    required String label,
    required this.initialValue,
    required this.min,
    required this.max,
    this.divisions,
    this.decimalPlaces = 1,
  })  : assert(min < max),
        assert(initialValue >= min && initialValue <= max),
        assert(divisions == null || divisions > 0),
        assert(decimalPlaces >= 0 && decimalPlaces <= 6),
        super(id: id, label: label);

  @override
  final double initialValue;
  final double min;
  final double max;
  final int? divisions;
  final int decimalPlaces;

  @override
  bool accepts(Object value) => value is num && value.isFinite;

  @override
  double normalize(Object value) {
    return (value as num).toDouble().clamp(min, max).toDouble();
  }

  String format(double value) => value.toStringAsFixed(decimalPlaces);
}

/// One optional color shortcut for [ArgosColorTuningProperty].
@immutable
class ArgosTuningColorOption {
  const ArgosTuningColorOption({
    required this.label,
    required this.color,
  }) : assert(label != '');

  final String label;
  final Color color;
}

/// A color tuning property that accepts any Flutter [Color].
///
/// [options] may provide convenient host-declared shortcuts, but the on-device
/// editor also exposes hexadecimal and HSVA controls for arbitrary colors.
class ArgosColorTuningProperty extends ArgosTuningProperty {
  const ArgosColorTuningProperty({
    required String id,
    required String label,
    required this.initialValue,
    this.options = const <ArgosTuningColorOption>[],
  }) : super(id: id, label: label);

  @override
  final Color initialValue;
  final List<ArgosTuningColorOption> options;

  @override
  bool accepts(Object value) => value is Color;

  @override
  Color normalize(Object value) => value as Color;
}

/// Immutable typed values passed to an [ArgosTunableBuilder].
@immutable
class ArgosTuningValues {
  ArgosTuningValues._(Map<String, Object> values)
      : _values = Map<String, Object>.unmodifiable(values);

  final Map<String, Object> _values;

  bool contains(String propertyId) => _values.containsKey(propertyId);

  double doubleValue(String propertyId) {
    final value = _values[propertyId];
    if (value is double) return value;
    throw StateError('No double tuning property named "$propertyId".');
  }

  Color colorValue(String propertyId) {
    final value = _values[propertyId];
    if (value is Color) return value;
    throw StateError('No color tuning property named "$propertyId".');
  }

  Object value(String propertyId) {
    final value = _values[propertyId];
    if (value != null) return value;
    throw StateError('No tuning property named "$propertyId".');
  }

  Map<String, Object> toMap() => _values;
}

/// Immutable view of one currently mounted tuning target.
@immutable
class ArgosTuningTarget {
  const ArgosTuningTarget({
    required this.id,
    required this.label,
    required this.properties,
    required this.values,
    this.bounds,
  });

  final String id;
  final String label;
  final List<ArgosTuningProperty> properties;
  final ArgosTuningValues values;
  final Rect? bounds;
}

class _ArgosTuningRegistration {
  const _ArgosTuningRegistration({
    required this.owner,
    required this.label,
    required this.properties,
    required this.boundaryKey,
  });

  final Object owner;
  final String label;
  final List<ArgosTuningProperty> properties;
  final GlobalKey boundaryKey;
}

/// Owns in-memory tuning overrides and mounted target registrations.
///
/// Values are intentionally ephemeral. Supply a controller to
/// [ArgosWidgetInspector] when they need to survive inspector rebuilds, and
/// dispose that controller from the owning State.
class ArgosTuningController extends ChangeNotifier {
  final Map<String, _ArgosTuningRegistration> _registrations =
      <String, _ArgosTuningRegistration>{};
  final Map<String, List<ArgosTuningProperty>> _schemas =
      <String, List<ArgosTuningProperty>>{};
  final Map<String, Map<String, Object>> _values =
      <String, Map<String, Object>>{};

  /// Returns a mounted target, or null when [targetId] is not currently live.
  ArgosTuningTarget? target(String targetId) {
    final registration = _registrations[targetId];
    if (registration == null) return null;
    return _snapshotTarget(targetId, registration);
  }

  /// Returns the smallest mounted target containing [globalPosition].
  ArgosTuningTarget? targetAt(Offset globalPosition) {
    ArgosTuningTarget? result;
    var smallestArea = double.infinity;
    for (final entry in _registrations.entries) {
      final target = _snapshotTarget(entry.key, entry.value);
      final bounds = target.bounds;
      if (bounds == null ||
          bounds.isEmpty ||
          !bounds.contains(globalPosition)) {
        continue;
      }
      final area = bounds.width * bounds.height;
      if (area <= smallestArea) {
        smallestArea = area;
        result = target;
      }
    }
    return result;
  }

  /// Updates one property, clamping bounded numeric values when necessary.
  ///
  /// Returns false for unknown targets/properties or incompatible values.
  bool updateValue(String targetId, String propertyId, Object value) {
    final property = _property(targetId, propertyId);
    if (property == null || !property.accepts(value)) return false;
    final normalized = property.normalize(value);
    final targetValues = _values[targetId];
    if (targetValues == null) return false;
    if (targetValues[propertyId] == normalized) return true;
    targetValues[propertyId] = normalized;
    notifyListeners();
    return true;
  }

  /// Resets every property on [targetId] to its declared initial value.
  bool resetTarget(String targetId) {
    final properties = _schemas[targetId];
    final current = _values[targetId];
    if (properties == null || current == null) return false;
    final defaults = _defaultMap(properties);
    if (_mapsEqual(current, defaults)) return true;
    _values[targetId] = defaults;
    notifyListeners();
    return true;
  }

  /// Drops all runtime overrides while retaining mounted registrations.
  void resetAll() {
    var changed = false;
    for (final entry in _schemas.entries) {
      final defaults = _defaultMap(entry.value);
      if (!_mapsEqual(_values[entry.key], defaults)) {
        _values[entry.key] = defaults;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void _register({
    required String targetId,
    required String label,
    required List<ArgosTuningProperty> properties,
    required GlobalKey boundaryKey,
    required Object owner,
  }) {
    _validateProperties(targetId, properties);
    final schema = List<ArgosTuningProperty>.unmodifiable(properties);
    _schemas[targetId] = schema;
    _values[targetId] = _reconcileValues(_values[targetId], schema);
    _registrations[targetId] = _ArgosTuningRegistration(
      owner: owner,
      label: label,
      properties: schema,
      boundaryKey: boundaryKey,
    );
  }

  void _unregister(String targetId, Object owner) {
    final current = _registrations[targetId];
    if (current != null && identical(current.owner, owner)) {
      _registrations.remove(targetId);
    }
  }

  ArgosTuningValues _valuesFor(
    String targetId,
    List<ArgosTuningProperty> properties,
  ) {
    final current = _values[targetId] ?? _defaultMap(properties);
    return ArgosTuningValues._(current);
  }

  ArgosTuningTarget _snapshotTarget(
    String targetId,
    _ArgosTuningRegistration registration,
  ) {
    return ArgosTuningTarget(
      id: targetId,
      label: registration.label,
      properties: registration.properties,
      values: _valuesFor(targetId, registration.properties),
      bounds: _globalBounds(registration.boundaryKey),
    );
  }

  ArgosTuningProperty? _property(String targetId, String propertyId) {
    final properties = _schemas[targetId];
    if (properties == null) return null;
    for (final property in properties) {
      if (property.id == propertyId) return property;
    }
    return null;
  }

  static Rect? _globalBounds(GlobalKey key) {
    try {
      final renderObject = key.currentContext?.findRenderObject();
      if (renderObject is! RenderBox ||
          !renderObject.attached ||
          !renderObject.hasSize) {
        return null;
      }
      return renderObject.localToGlobal(Offset.zero) & renderObject.size;
    } catch (_) {
      return null;
    }
  }

  static void _validateProperties(
    String targetId,
    List<ArgosTuningProperty> properties,
  ) {
    final ids = <String>{};
    for (final property in properties) {
      if (!ids.add(property.id)) {
        throw ArgumentError(
          'Tuning target "$targetId" contains duplicate property '
          '"${property.id}".',
        );
      }
      if (!property.accepts(property.initialValue)) {
        throw ArgumentError(
          'Tuning property "${property.id}" has an invalid initial value.',
        );
      }
    }
  }

  static Map<String, Object> _reconcileValues(
    Map<String, Object>? previous,
    List<ArgosTuningProperty> properties,
  ) {
    final result = <String, Object>{};
    for (final property in properties) {
      final previousValue = previous?[property.id];
      result[property.id] =
          previousValue != null && property.accepts(previousValue)
              ? property.normalize(previousValue)
              : property.initialValue;
    }
    return result;
  }

  static Map<String, Object> _defaultMap(
    List<ArgosTuningProperty> properties,
  ) {
    return <String, Object>{
      for (final property in properties) property.id: property.initialValue,
    };
  }

  @override
  void dispose() {
    _registrations.clear();
    _schemas.clear();
    _values.clear();
    super.dispose();
  }
}

/// Internal inherited bridge installed by [ArgosWidgetInspector].
///
/// It is intentionally hidden from the package's top-level exports.
class ArgosTuningScope extends InheritedWidget {
  const ArgosTuningScope({
    Key? key,
    required this.controller,
    required Widget child,
  }) : super(key: key, child: child);

  final ArgosTuningController controller;

  static ArgosTuningController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ArgosTuningScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(ArgosTuningScope oldWidget) {
    return !identical(controller, oldWidget.controller);
  }
}

/// Opt-in bridge between source-controlled widget construction and runtime
/// inspector values.
class ArgosTunable extends StatefulWidget {
  const ArgosTunable({
    Key? key,
    required this.id,
    required this.label,
    required this.properties,
    required this.builder,
  })  : assert(id != ''),
        assert(label != ''),
        super(key: key);

  final String id;
  final String label;
  final List<ArgosTuningProperty> properties;
  final ArgosTunableBuilder builder;

  @override
  State<ArgosTunable> createState() => _ArgosTunableState();
}

class _ArgosTunableState extends State<ArgosTunable> {
  final GlobalKey _boundaryKey =
      GlobalKey(debugLabel: 'Argos runtime tuning target');
  ArgosTuningController? _controller;
  Map<String, Object>? _lastValues;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = ArgosTuningScope.maybeOf(context);
    if (!identical(next, _controller)) {
      _detach(widget.id);
      _controller = next;
      _controller?.addListener(_handleControllerChanged);
    }
    _register();
  }

  @override
  void didUpdateWidget(covariant ArgosTunable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _controller?._unregister(oldWidget.id, this);
      _lastValues = null;
    }
    _register();
  }

  @override
  void dispose() {
    _detach(widget.id);
    super.dispose();
  }

  void _register() {
    _controller?._register(
      targetId: widget.id,
      label: widget.label,
      properties: widget.properties,
      boundaryKey: _boundaryKey,
      owner: this,
    );
  }

  void _detach(String targetId) {
    _controller?.removeListener(_handleControllerChanged);
    _controller?._unregister(targetId, this);
  }

  void _handleControllerChanged() {
    if (!mounted || _controller == null) return;
    final next = _controller!._valuesFor(widget.id, widget.properties).toMap();
    if (_mapsEqual(_lastValues, next)) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final values = _controller?._valuesFor(widget.id, widget.properties) ??
        ArgosTuningValues._(
          ArgosTuningController._defaultMap(widget.properties),
        );
    _lastValues = values.toMap();
    return KeyedSubtree(
      key: _boundaryKey,
      child: widget.builder(context, values),
    );
  }
}

bool _mapsEqual(Map<String, Object>? left, Map<String, Object>? right) {
  if (identical(left, right)) return true;
  if (left == null || right == null || left.length != right.length) {
    return false;
  }
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) return false;
  }
  return true;
}
