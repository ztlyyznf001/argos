import 'package:flutter/material.dart';

import 'package:argos_inspector/ui/argos_widget_inspector_page.dart';
import 'package:argos_inspector/ui/argos_widget_snapshot.dart';
import 'package:argos_inspector/ui/argos_widget_tuning.dart';

/// Opt-in floating entry point for the on-device Widget Inspector.
///
/// Place this inside [MaterialApp.builder] so it can preserve the application's
/// mounted Navigator while adding a launcher above it:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => ArgosWidgetInspector(
///     enabled: kDebugMode,
///     child: child!,
///   ),
/// )
/// ```
///
/// Turn on the runtime long-press switch to inspect the deepest laid-out widget
/// at a position, or tap the launcher to browse the complete hierarchy. The
/// wrapper returns [child] directly while [enabled] is false and never
/// traverses the element tree until one of those explicit interactions occurs.
class ArgosWidgetInspector extends StatefulWidget {
  const ArgosWidgetInspector({
    Key? key,
    required this.child,
    this.enabled = false,
    this.maxDepth = 200,
    this.maxNodes = 5000,
    this.longPressInitiallyEnabled = false,
    this.tuningController,
    this.launcherAlignment = Alignment.bottomRight,
    this.launcherMargin = const EdgeInsets.all(16),
  }) : super(key: key);

  final Widget child;
  final bool enabled;
  final int maxDepth;
  final int maxNodes;

  /// Initial value of the runtime long-press inspection switch.
  ///
  /// The switch defaults off so enabling the debug wrapper does not
  /// immediately reserve long-press gestures from the host application.
  final bool longPressInitiallyEnabled;

  /// Optional owner-controlled storage for ephemeral runtime tuning values.
  ///
  /// When omitted, this inspector creates and disposes its own controller.
  final ArgosTuningController? tuningController;
  final Alignment launcherAlignment;
  final EdgeInsets launcherMargin;

  @override
  State<ArgosWidgetInspector> createState() => _ArgosWidgetInspectorState();
}

class _ArgosWidgetInspectorState extends State<ArgosWidgetInspector>
    with WidgetsBindingObserver {
  final GlobalKey _contentBoundaryKey =
      GlobalKey(debugLabel: 'Argos inspected content');
  final GlobalKey _inspectorPageKey =
      GlobalKey(debugLabel: 'Argos widget inspector page');

  bool _routeOpen = false;
  bool _detailRouteOpen = false;
  late bool _longPressEnabled;
  ArgosWidgetSnapshot? _inlineSnapshot;
  ArgosWidgetNode? _inlineNode;
  Rect? _inlineHighlightBounds;
  String? _inlineWidgetBreadcrumb;
  String? _inlineTuningTargetId;
  late ArgosTuningController _tuningController;
  late bool _ownsTuningController;

  @override
  void initState() {
    super.initState();
    _longPressEnabled = widget.longPressInitiallyEnabled;
    _setTuningController();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant ArgosWidgetInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.longPressInitiallyEnabled !=
        widget.longPressInitiallyEnabled) {
      _longPressEnabled = widget.longPressInitiallyEnabled;
    }
    if (!identical(oldWidget.tuningController, widget.tuningController)) {
      if (_ownsTuningController) _tuningController.dispose();
      _setTuningController();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsTuningController) _tuningController.dispose();
    super.dispose();
  }

  void _setTuningController() {
    _ownsTuningController = widget.tuningController == null;
    _tuningController = widget.tuningController ?? ArgosTuningController();
  }

  /// Handles system back for the no-Navigator inline fallback. A normal
  /// inspector route is handled by its Navigator before this observer is used.
  @override
  Future<bool> didPopRoute() async {
    if (_inlineNode != null) {
      _closeInlineNode();
      return true;
    }
    if (_inlineSnapshot == null) return false;
    _closeInlineInspector();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return ArgosTuningScope(
      controller: _tuningController,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          GestureDetector(
            key: const ValueKey<String>('argos-widget-long-press-area'),
            behavior: HitTestBehavior.translucent,
            onLongPressStart: _longPressEnabled ? _inspectAt : null,
            child: KeyedSubtree(
              key: _contentBoundaryKey,
              child: widget.child,
            ),
          ),
          if (!_routeOpen &&
              !_detailRouteOpen &&
              _inlineSnapshot == null &&
              _inlineNode == null)
            _buildLauncher(),
          if (_inlineSnapshot != null)
            Positioned.fill(
              child: ArgosWidgetInspectorPage(
                key: _inspectorPageKey,
                initialSnapshot: _inlineSnapshot,
                snapshotLoader: _captureContent,
                onClose: _closeInlineInspector,
                maxDepth: widget.maxDepth,
                maxNodes: widget.maxNodes,
              ),
            ),
          if (_inlineNode != null)
            ArgosWidgetNodeDetailOverlay(
              node: _inlineNode!,
              highlightBounds: _inlineHighlightBounds,
              widgetBreadcrumb: _inlineWidgetBreadcrumb,
              tuningController: _tuningController,
              tuningTargetId: _inlineTuningTargetId,
              onClose: _closeInlineNode,
            ),
        ],
      ),
    );
  }

  Widget _buildLauncher() {
    return Positioned.fill(
      child: SafeArea(
        minimum: widget.launcherMargin,
        child: Align(
          alignment: widget.launcherAlignment,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Material(
                elevation: 4,
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text('长按检查'),
                      Switch(
                        key: const ValueKey<String>(
                          'argos-widget-long-press-switch',
                        ),
                        value: _longPressEnabled,
                        onChanged: (value) {
                          setState(() => _longPressEnabled = value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                button: true,
                label: '打开完整 Widget 树',
                child: FloatingActionButton(
                  key: const ValueKey<String>(
                    'argos-widget-inspector-launcher',
                  ),
                  heroTag: null,
                  mini: true,
                  onPressed: _openInspector,
                  child: const Icon(Icons.widgets_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openInspector() async {
    if (_routeOpen ||
        _detailRouteOpen ||
        _inlineSnapshot != null ||
        _inlineNode != null) {
      return;
    }
    final snapshot = _captureContent();
    if (snapshot == null || !mounted) return;

    final contentRoot = _contentRootElement();
    final navigator = contentRoot == null ? null : _findNavigator(contentRoot);
    if (navigator == null) {
      setState(() => _inlineSnapshot = snapshot);
      return;
    }

    setState(() => _routeOpen = true);
    try {
      await navigator.push<void>(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/argos/widget-inspector'),
          builder: (_) => ArgosWidgetInspectorPage(
            key: _inspectorPageKey,
            initialSnapshot: snapshot,
            snapshotLoader: _captureContent,
            maxDepth: widget.maxDepth,
            maxNodes: widget.maxNodes,
          ),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _inlineSnapshot = snapshot);
    } finally {
      if (mounted) setState(() => _routeOpen = false);
    }
  }

  void _closeInlineInspector() {
    if (!mounted || _inlineSnapshot == null) return;
    setState(() => _inlineSnapshot = null);
  }

  Future<void> _inspectAt(LongPressStartDetails details) async {
    if (_routeOpen ||
        _detailRouteOpen ||
        _inlineSnapshot != null ||
        _inlineNode != null) {
      return;
    }
    final snapshot = _captureContent();
    final node = snapshot?.deepestNodeAt(details.globalPosition);
    if (node == null || !mounted) return;

    final highlightBounds = _localBounds(node.bounds);
    final widgetBreadcrumb = snapshot!.widgetBreadcrumbFor(node);
    final tuningTarget = _tuningController.targetAt(details.globalPosition);
    final contentRoot = _contentRootElement();
    final navigator = contentRoot == null ? null : _findNavigator(contentRoot);
    if (navigator == null) {
      setState(() {
        _inlineNode = node;
        _inlineHighlightBounds = highlightBounds;
        _inlineWidgetBreadcrumb = widgetBreadcrumb;
        _inlineTuningTargetId = tuningTarget?.id;
      });
      return;
    }

    setState(() => _detailRouteOpen = true);
    try {
      await navigator.push<void>(
        PageRouteBuilder<void>(
          settings: const RouteSettings(
            name: '/argos/widget-inspector/detail',
          ),
          opaque: false,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (routeContext, _, __) => Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ArgosWidgetNodeDetailOverlay(
                node: node,
                highlightBounds: highlightBounds,
                widgetBreadcrumb: widgetBreadcrumb,
                tuningController: _tuningController,
                tuningTargetId: tuningTarget?.id,
                onClose: () => Navigator.of(routeContext).pop(),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _inlineNode = node;
          _inlineHighlightBounds = highlightBounds;
          _inlineWidgetBreadcrumb = widgetBreadcrumb;
          _inlineTuningTargetId = tuningTarget?.id;
        });
      }
    } finally {
      if (mounted) setState(() => _detailRouteOpen = false);
    }
  }

  void _closeInlineNode() {
    if (!mounted || _inlineNode == null) return;
    setState(() {
      _inlineNode = null;
      _inlineHighlightBounds = null;
      _inlineWidgetBreadcrumb = null;
      _inlineTuningTargetId = null;
    });
  }

  Rect? _localBounds(Rect? globalBounds) {
    if (globalBounds == null) return null;
    try {
      final renderObject =
          _contentBoundaryKey.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) return null;
      return renderObject.globalToLocal(globalBounds.topLeft) &
          globalBounds.size;
    } catch (_) {
      return null;
    }
  }

  ArgosWidgetSnapshot? _captureContent() {
    final root = _contentRootElement();
    if (root == null) return null;
    return ArgosWidgetSnapshot.capture(
      root,
      maxDepth: widget.maxDepth,
      maxNodes: widget.maxNodes,
      excludeElement: (element) => element.widget.key == _inspectorPageKey,
    );
  }

  Element? _contentRootElement() {
    final boundary = _contentBoundaryKey.currentContext;
    if (boundary is! Element) return null;
    Element? root;
    try {
      boundary.visitChildElements((child) => root ??= child);
    } catch (_) {
      return null;
    }
    return root ?? boundary;
  }

  NavigatorState? _findNavigator(Element root) {
    NavigatorState? result;

    void visit(Element element) {
      if (result != null) return;
      if (element is StatefulElement && element.state is NavigatorState) {
        result = element.state as NavigatorState;
        return;
      }
      try {
        element.visitChildElements(visit);
      } catch (_) {
        // Ignore an element that detached while looking for the Navigator.
      }
    }

    visit(root);
    return result;
  }
}
