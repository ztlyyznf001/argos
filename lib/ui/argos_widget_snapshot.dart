import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Returns true when an [Element] and its descendants should be omitted from a
/// widget snapshot.
typedef ArgosWidgetElementPredicate = bool Function(Element element);

/// A captured diagnostic property belonging to an [ArgosWidgetNode].
@immutable
class ArgosWidgetProperty {
  const ArgosWidgetProperty({required this.name, required this.value});

  final String name;
  final String value;

  @override
  String toString() => name.isEmpty ? value : '$name: $value';
}

/// An immutable description of one mounted widget at snapshot time.
///
/// This object intentionally retains no [Element], [Widget], or [RenderObject]
/// reference, so it remains safe to read after the application rebuilds.
@immutable
class ArgosWidgetNode {
  // A const constructor cannot defensively copy the two list arguments.
  // ignore: prefer_const_constructors_in_immutables
  ArgosWidgetNode({
    required this.path,
    required this.widgetType,
    required this.depth,
    required this.description,
    this.key,
    this.bounds,
    List<ArgosWidgetProperty> properties = const <ArgosWidgetProperty>[],
    List<ArgosWidgetNode> children = const <ArgosWidgetNode>[],
  })  : properties = UnmodifiableListView<ArgosWidgetProperty>(
          List<ArgosWidgetProperty>.of(properties),
        ),
        children = UnmodifiableListView<ArgosWidgetNode>(
          List<ArgosWidgetNode>.of(children),
        );

  /// Structural index path, for example `0/2/1`.
  final String path;

  final String widgetType;
  final String? key;
  final int depth;
  final String description;

  /// Global logical-pixel bounds when the element had a laid-out RenderBox.
  final Rect? bounds;

  final UnmodifiableListView<ArgosWidgetProperty> properties;
  final UnmodifiableListView<ArgosWidgetNode> children;

  int get childCount => children.length;

  /// Whether this node contains [query] in any user-visible captured field.
  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    if (widgetType.toLowerCase().contains(normalized) ||
        (key?.toLowerCase().contains(normalized) ?? false) ||
        description.toLowerCase().contains(normalized)) {
      return true;
    }
    return properties.any(
      (property) =>
          property.name.toLowerCase().contains(normalized) ||
          property.value.toLowerCase().contains(normalized),
    );
  }

  /// Depth-first iteration over this node and all captured descendants.
  Iterable<ArgosWidgetNode> get depthFirst sync* {
    yield this;
    for (final child in children) {
      yield* child.depthFirst;
    }
  }
}

/// An immutable, bounded view of a mounted Flutter element subtree.
@immutable
class ArgosWidgetSnapshot {
  const ArgosWidgetSnapshot({
    required this.capturedAt,
    required this.root,
    required this.nodeCount,
    required this.maxDepth,
    required this.maxNodes,
    required this.truncated,
  });

  final DateTime capturedAt;
  final ArgosWidgetNode? root;
  final int nodeCount;
  final int maxDepth;
  final int maxNodes;
  final bool truncated;

  bool get isEmpty => root == null;

  /// Returns the deepest captured node whose layout bounds contain [position].
  ///
  /// [position] uses the same global logical-pixel coordinate space as
  /// [ArgosWidgetNode.bounds]. When overlapping nodes have the same depth, the
  /// later depth-first node wins, which follows Flutter's usual later-painted
  /// sibling ordering for common Stack-based layouts.
  ArgosWidgetNode? deepestNodeAt(Offset position) {
    ArgosWidgetNode? result;
    final root = this.root;
    if (root == null) return null;
    for (final node in root.depthFirst) {
      final bounds = node.bounds;
      if (bounds == null || !bounds.contains(position)) continue;
      if (result == null || node.depth >= result.depth) result = node;
    }
    return result;
  }

  /// Returns a concise widget-type breadcrumb for [node].
  ///
  /// Structural paths are intentionally numeric because they identify child
  /// indexes. Flutter trees contain many single-child wrappers, so displaying
  /// those paths directly often produces an unhelpful run of zeroes. This
  /// method instead derives a readable lineage and keeps only its tail.
  String widgetBreadcrumbFor(
    ArgosWidgetNode node, {
    int maxSegments = 6,
  }) {
    assert(maxSegments > 0);
    final limit = maxSegments < 1 ? 1 : maxSegments;
    final lineage = _lineageFor(node.path);
    if (lineage.isEmpty) return node.widgetType;
    final types = lineage.map((ancestor) => ancestor.widgetType).toList();
    if (types.length <= limit) return types.join(' › ');
    return '… › ${types.skip(types.length - limit).join(' › ')}';
  }

  List<ArgosWidgetNode> _lineageFor(String path) {
    final root = this.root;
    if (root == null) return const <ArgosWidgetNode>[];
    final current = <ArgosWidgetNode>[];
    List<ArgosWidgetNode>? result;

    bool visit(ArgosWidgetNode node) {
      current.add(node);
      if (node.path == path) {
        result = List<ArgosWidgetNode>.of(current);
        current.removeLast();
        return true;
      }
      for (final child in node.children) {
        if (visit(child)) {
          current.removeLast();
          return true;
        }
      }
      current.removeLast();
      return false;
    }

    visit(root);
    return result ?? const <ArgosWidgetNode>[];
  }

  /// Captures [root] synchronously without retaining framework tree objects.
  ///
  /// Traversal happens only when this method is called. [excludeElement] can be
  /// used by an integration layer to omit its own inspector subtree.
  static ArgosWidgetSnapshot capture(
    Element root, {
    int maxDepth = 200,
    int maxNodes = 5000,
    int maxDiagnosticProperties = 20,
    ArgosWidgetElementPredicate? excludeElement,
  }) {
    assert(maxDepth >= 0);
    assert(maxNodes > 0);
    assert(maxDiagnosticProperties >= 0);
    final capturer = _ArgosWidgetTreeCapturer(
      maxDepth: maxDepth < 0 ? 0 : maxDepth,
      maxNodes: maxNodes < 1 ? 1 : maxNodes,
      maxDiagnosticProperties:
          maxDiagnosticProperties < 0 ? 0 : maxDiagnosticProperties,
      excludeElement: excludeElement,
    );
    final node = capturer.capture(root, depth: 0, path: '0');
    return ArgosWidgetSnapshot(
      capturedAt: DateTime.now(),
      root: node,
      nodeCount: capturer.nodeCount,
      maxDepth: capturer.maxDepth,
      maxNodes: capturer.maxNodes,
      truncated: capturer.truncated,
    );
  }

  /// Captures the subtree rooted at [context], when it is backed by an Element.
  static ArgosWidgetSnapshot? captureFromContext(
    BuildContext context, {
    int maxDepth = 200,
    int maxNodes = 5000,
    int maxDiagnosticProperties = 20,
    ArgosWidgetElementPredicate? excludeElement,
  }) {
    if (context is! Element) return null;
    return capture(
      context,
      maxDepth: maxDepth,
      maxNodes: maxNodes,
      maxDiagnosticProperties: maxDiagnosticProperties,
      excludeElement: excludeElement,
    );
  }

  /// Captures the application binding root, if one is currently attached.
  static ArgosWidgetSnapshot? captureBindingRoot({
    int maxDepth = 200,
    int maxNodes = 5000,
    int maxDiagnosticProperties = 20,
    ArgosWidgetElementPredicate? excludeElement,
  }) {
    // renderViewElement is retained for Flutter 3.0 compatibility; rootElement
    // became the preferred name in newer SDKs.
    // ignore: deprecated_member_use
    final root = WidgetsBinding.instance.renderViewElement;
    if (root == null) return null;
    return capture(
      root,
      maxDepth: maxDepth,
      maxNodes: maxNodes,
      maxDiagnosticProperties: maxDiagnosticProperties,
      excludeElement: excludeElement,
    );
  }
}

class _ArgosWidgetTreeCapturer {
  _ArgosWidgetTreeCapturer({
    required this.maxDepth,
    required this.maxNodes,
    required this.maxDiagnosticProperties,
    required this.excludeElement,
  });

  final int maxDepth;
  final int maxNodes;
  final int maxDiagnosticProperties;
  final ArgosWidgetElementPredicate? excludeElement;

  int nodeCount = 0;
  bool truncated = false;

  ArgosWidgetNode? capture(
    Element element, {
    required int depth,
    required String path,
  }) {
    if (!_isMounted(element) || _isExcluded(element)) return null;
    if (nodeCount >= maxNodes) {
      truncated = true;
      return null;
    }
    nodeCount++;

    final childElements = <Element>[];
    try {
      element.visitChildElements(childElements.add);
    } catch (_) {
      // An element can detach between the mounted check and traversal.
    }

    final children = <ArgosWidgetNode>[];
    if (depth >= maxDepth) {
      if (childElements.any((child) => !_isExcluded(child))) {
        truncated = true;
      }
    } else {
      for (var i = 0; i < childElements.length; i++) {
        if (nodeCount >= maxNodes) {
          if (childElements
              .skip(i)
              .any((child) => !_isExcluded(child) && _isMounted(child))) {
            truncated = true;
          }
          break;
        }
        final child = capture(
          childElements[i],
          depth: depth + 1,
          path: '$path/$i',
        );
        if (child != null) children.add(child);
      }
    }

    Widget? widget;
    try {
      widget = element.widget;
    } catch (_) {
      // A concurrent detach should result in an incomplete but usable node.
    }

    return ArgosWidgetNode(
      path: path,
      widgetType:
          widget?.runtimeType.toString() ?? element.runtimeType.toString(),
      key: _readKey(widget),
      depth: depth,
      description: _readDescription(widget, element),
      bounds: _readBounds(element),
      properties: _readProperties(widget),
      children: children,
    );
  }

  bool _isMounted(Element element) {
    try {
      return element.mounted;
    } catch (_) {
      return false;
    }
  }

  bool _isExcluded(Element element) {
    try {
      return excludeElement?.call(element) ?? false;
    } catch (_) {
      return false;
    }
  }

  String? _readKey(Widget? widget) {
    try {
      return widget?.key?.toString();
    } catch (_) {
      return null;
    }
  }

  String _readDescription(Widget? widget, Element element) {
    try {
      return _singleLine(widget?.toStringShort() ?? element.toStringShort());
    } catch (_) {
      return element.runtimeType.toString();
    }
  }

  Rect? _readBounds(Element element) {
    try {
      final renderObject = element.renderObject;
      if (renderObject is! RenderBox ||
          !renderObject.attached ||
          !renderObject.hasSize) {
        return null;
      }
      final origin = renderObject.localToGlobal(Offset.zero);
      final rect = origin & renderObject.size;
      return rect.isFinite ? rect : null;
    } catch (_) {
      return null;
    }
  }

  List<ArgosWidgetProperty> _readProperties(Widget? widget) {
    if (widget == null || maxDiagnosticProperties == 0) {
      return const <ArgosWidgetProperty>[];
    }
    try {
      final diagnostics = widget
          .toDiagnosticsNode(style: DiagnosticsTreeStyle.singleLine)
          .getProperties();
      final properties = <ArgosWidgetProperty>[];
      for (final diagnostic in diagnostics) {
        if (properties.length >= maxDiagnosticProperties) break;
        final value = _singleLine(diagnostic.toDescription());
        if (value.isEmpty) continue;
        properties.add(
          ArgosWidgetProperty(
            name: _singleLine(diagnostic.name ?? ''),
            value: value,
          ),
        );
      }
      return properties;
    } catch (_) {
      return const <ArgosWidgetProperty>[];
    }
  }

  String _singleLine(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 300) return normalized;
    return '${normalized.substring(0, 299)}…';
  }
}
