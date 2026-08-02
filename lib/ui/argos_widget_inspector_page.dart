// Flutter 3.0 compatibility requires WillPopScope, ColorScheme.surfaceVariant,
// and Color.withOpacity; their modern replacements were added in later SDKs.
// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:argos_inspector/ui/argos_widget_snapshot.dart';
import 'package:argos_inspector/ui/argos_widget_tuning.dart';

/// Creates a fresh widget-tree snapshot for the inspector's refresh action.
typedef ArgosWidgetSnapshotLoader = ArgosWidgetSnapshot? Function();

/// A self-contained, phone-friendly viewer for a captured Flutter widget tree.
class ArgosWidgetInspectorPage extends StatefulWidget {
  const ArgosWidgetInspectorPage({
    Key? key,
    this.initialSnapshot,
    this.snapshotLoader,
    this.onClose,
    this.maxDepth = 200,
    this.maxNodes = 5000,
  }) : super(key: key);

  /// Snapshot displayed on the first frame. When omitted, the binding root is
  /// captured after this page is mounted.
  final ArgosWidgetSnapshot? initialSnapshot;

  /// Optional host-specific capture callback used by the refresh action.
  final ArgosWidgetSnapshotLoader? snapshotLoader;

  /// Closes an inline inspector. When omitted, the current route is popped.
  final VoidCallback? onClose;

  final int maxDepth;
  final int maxNodes;

  @override
  State<ArgosWidgetInspectorPage> createState() =>
      _ArgosWidgetInspectorPageState();
}

class _ArgosWidgetInspectorPageState extends State<ArgosWidgetInspectorPage> {
  ArgosWidgetSnapshot? _snapshot;
  ArgosWidgetNode? _selectedNode;
  final Set<String> _expandedPaths = <String>{};
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _setSnapshot(widget.initialSnapshot, notify: false);
    if (_snapshot == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ArgosWidgetInspectorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSnapshot != oldWidget.initialSnapshot &&
        widget.initialSnapshot != null) {
      _setSnapshot(widget.initialSnapshot!);
    }
  }

  void _setSnapshot(ArgosWidgetSnapshot? snapshot, {bool notify = true}) {
    void update() {
      _snapshot = snapshot;
      _selectedNode = null;
      _expandedPaths.clear();
      final root = snapshot?.root;
      if (root != null) _expandedPaths.add(root.path);
    }

    if (notify && mounted) {
      setState(update);
    } else {
      update();
    }
  }

  void _refresh() {
    ArgosWidgetSnapshot? snapshot;
    try {
      snapshot = widget.snapshotLoader?.call() ??
          ArgosWidgetSnapshot.captureBindingRoot(
            maxDepth: widget.maxDepth,
            maxNodes: widget.maxNodes,
          );
    } catch (_) {
      snapshot = null;
    }
    if (!mounted) return;
    _setSnapshot(snapshot);
  }

  void _closePage() {
    if (_selectedNode != null) {
      setState(() => _selectedNode = null);
      return;
    }
    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }
    Navigator.maybeOf(context)?.maybePop();
  }

  Future<bool> _handleBack() async {
    if (_selectedNode != null) {
      setState(() => _selectedNode = null);
      return false;
    }
    if (widget.onClose != null) {
      widget.onClose!();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final rows = _visibleRows(snapshot?.root);
    return WillPopScope(
      onWillPop: _handleBack,
      child: Stack(
        children: <Widget>[
          Scaffold(
            appBar: AppBar(
              leading: IconButton(
                key: const ValueKey<String>('argos-widget-inspector-close'),
                tooltip: '关闭 Widget Inspector',
                icon: const Icon(Icons.close),
                onPressed: _closePage,
              ),
              title: const Text(
                'Widget Inspector',
                overflow: TextOverflow.ellipsis,
              ),
              actions: <Widget>[
                IconButton(
                  key: const ValueKey<String>('argos-widget-inspector-refresh'),
                  tooltip: '刷新 Widget 快照',
                  icon: const Icon(Icons.refresh),
                  onPressed: _refresh,
                ),
              ],
            ),
            body: Column(
              children: <Widget>[
                _SnapshotSummary(snapshot: snapshot),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: TextField(
                    key: const ValueKey<String>('argos-widget-search'),
                    controller: _searchController,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '搜索类型、Key 或属性',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: '清除搜索',
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                if (snapshot?.truncated ?? false)
                  _TruncationNotice(snapshot: snapshot!),
                Expanded(
                  child: _buildHierarchy(snapshot, rows),
                ),
              ],
            ),
          ),
          if (_selectedNode != null)
            ArgosWidgetNodeDetailOverlay(
              node: _selectedNode!,
              widgetBreadcrumb: _snapshot?.widgetBreadcrumbFor(_selectedNode!),
              onClose: () => setState(() => _selectedNode = null),
            ),
        ],
      ),
    );
  }

  Widget _buildHierarchy(
    ArgosWidgetSnapshot? snapshot,
    List<_VisibleWidgetNode> rows,
  ) {
    if (snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.isEmpty) {
      return _InspectorEmptyState(
        icon: Icons.account_tree_outlined,
        message: '当前没有可检查的 Widget 树',
        actionLabel: '重新捕获',
        onAction: _refresh,
      );
    }
    if (rows.isEmpty) {
      return _InspectorEmptyState(
        icon: Icons.search_off,
        message: '没有匹配“${_query.trim()}”的 Widget',
        actionLabel: '刷新快照',
        onAction: _refresh,
      );
    }
    return Scrollbar(
      child: ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          return _WidgetTreeRow(
            node: row.node,
            directMatch: row.directMatch,
            expanded: _query.trim().isNotEmpty ||
                _expandedPaths.contains(row.node.path),
            onToggle: row.node.children.isEmpty
                ? null
                : () {
                    setState(() {
                      if (!_expandedPaths.remove(row.node.path)) {
                        _expandedPaths.add(row.node.path);
                      }
                    });
                  },
            onSelect: () => setState(() => _selectedNode = row.node),
          );
        },
      ),
    );
  }

  List<_VisibleWidgetNode> _visibleRows(ArgosWidgetNode? root) {
    if (root == null) return const <_VisibleWidgetNode>[];
    final query = _query.trim();
    final rows = <_VisibleWidgetNode>[];
    if (query.isEmpty) {
      void appendExpanded(ArgosWidgetNode node) {
        rows.add(_VisibleWidgetNode(node: node, directMatch: false));
        if (!_expandedPaths.contains(node.path)) return;
        for (final child in node.children) {
          appendExpanded(child);
        }
      }

      appendExpanded(root);
      return rows;
    }

    final subtreeMatches = <String, bool>{};
    bool markMatches(ArgosWidgetNode node) {
      var matches = node.matches(query);
      for (final child in node.children) {
        matches = markMatches(child) || matches;
      }
      subtreeMatches[node.path] = matches;
      return matches;
    }

    void appendMatches(ArgosWidgetNode node) {
      if (!(subtreeMatches[node.path] ?? false)) return;
      rows.add(
        _VisibleWidgetNode(node: node, directMatch: node.matches(query)),
      );
      for (final child in node.children) {
        appendMatches(child);
      }
    }

    markMatches(root);
    appendMatches(root);
    return rows;
  }
}

class _VisibleWidgetNode {
  const _VisibleWidgetNode({
    required this.node,
    required this.directMatch,
  });

  final ArgosWidgetNode node;
  final bool directMatch;
}

class _SnapshotSummary extends StatelessWidget {
  const _SnapshotSummary({required this.snapshot});

  final ArgosWidgetSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final snapshot = this.snapshot;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surfaceVariant.withOpacity(0.45),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Text(
        snapshot == null
            ? '正在捕获 Widget 树…'
            : '${snapshot.nodeCount} 个节点 · ${_clock(snapshot.capturedAt)}'
                '${snapshot.truncated ? ' · 已截断' : ''}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
      ),
    );
  }

  static String _clock(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }
}

class _TruncationNotice extends StatelessWidget {
  const _TruncationNotice({required this.snapshot});

  final ArgosWidgetSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey<String>('argos-widget-truncation-notice'),
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: <Widget>[
          Icon(Icons.info_outline, size: 17, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '树已按 ${snapshot.maxNodes} 个节点 / ${snapshot.maxDepth} 层限制截断',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WidgetTreeRow extends StatelessWidget {
  const _WidgetTreeRow({
    required this.node,
    required this.directMatch,
    required this.expanded,
    required this.onToggle,
    required this.onSelect,
  });

  final ArgosWidgetNode node;
  final bool directMatch;
  final bool expanded;
  final VoidCallback? onToggle;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final indent = math.min(node.depth * 14.0, 98.0);
    return Material(
      color: directMatch
          ? scheme.primaryContainer.withOpacity(0.38)
          : Colors.transparent,
      child: InkWell(
        key: ValueKey<String>('argos-widget-row-${node.path}'),
        onTap: onSelect,
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: EdgeInsets.only(left: 4 + indent, right: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.dividerColor.withOpacity(0.35)),
            ),
          ),
          child: Row(
            children: <Widget>[
              if (onToggle != null)
                IconButton(
                  key: ValueKey<String>('argos-widget-toggle-${node.path}'),
                  tooltip: expanded ? '收起子节点' : '展开子节点',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                  icon: Icon(
                    expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 20,
                  ),
                  onPressed: onToggle,
                )
              else
                const SizedBox(width: 36),
              Icon(
                node.children.isEmpty
                    ? Icons.widgets_outlined
                    : Icons.account_tree,
                size: 16,
                color: directMatch ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      node.widgetType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: directMatch ? FontWeight.w600 : null,
                      ),
                    ),
                    if (node.key != null)
                      Text(
                        node.key!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                      ),
                  ],
                ),
              ),
              if (node.children.isNotEmpty)
                Text(
                  '${node.childCount}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(width: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _InspectorEmptyState extends StatelessWidget {
  const _InspectorEmptyState({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 42, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// A closable mobile detail surface for one captured widget node.
///
/// [highlightBounds] is optional because hierarchy-page details describe host
/// content on another route, while direct long-press details are drawn above
/// the content they describe.
class ArgosWidgetNodeDetailOverlay extends StatelessWidget {
  const ArgosWidgetNodeDetailOverlay({
    Key? key,
    required this.node,
    required this.onClose,
    this.highlightBounds,
    this.widgetBreadcrumb,
    this.tuningController,
    this.tuningTargetId,
  }) : super(key: key);

  final ArgosWidgetNode node;
  final VoidCallback onClose;
  final Rect? highlightBounds;
  final String? widgetBreadcrumb;
  final ArgosTuningController? tuningController;
  final String? tuningTargetId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final directSelection = highlightBounds != null;
    final tuningTarget = tuningTargetId == null
        ? null
        : tuningController?.target(tuningTargetId!);
    final showSheetAtTop = directSelection &&
        highlightBounds!.center.dy > MediaQuery.of(context).size.height / 2;
    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Semantics(
                button: true,
                label: '关闭 Widget 详情',
                child: GestureDetector(
                  key: const ValueKey<String>('argos-widget-detail-barrier'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onClose,
                  child: ColoredBox(color: Colors.black.withOpacity(0.46)),
                ),
              ),
            ),
            if (highlightBounds != null && !highlightBounds!.isEmpty)
              Positioned.fromRect(
                rect: highlightBounds!,
                child: IgnorePointer(
                  child: DecoratedBox(
                    key: const ValueKey<String>('argos-widget-highlight'),
                    decoration: BoxDecoration(
                      color: scheme.primary.withOpacity(0.12),
                      border: Border.all(color: scheme.primary, width: 2.5),
                    ),
                  ),
                ),
              ),
            Align(
              alignment:
                  showSheetAtTop ? Alignment.topCenter : Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: tuningTarget != null
                    ? 0.72
                    : directSelection
                        ? 0.46
                        : 0.72,
                widthFactor: 1,
                child: Material(
                  key: const ValueKey<String>('argos-widget-detail'),
                  elevation: 16,
                  color: scheme.surface,
                  borderRadius: BorderRadius.vertical(
                    top: showSheetAtTop
                        ? Radius.zero
                        : const Radius.circular(18),
                    bottom: showSheetAtTop
                        ? const Radius.circular(18)
                        : Radius.zero,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SafeArea(
                    top: showSheetAtTop,
                    bottom: !showSheetAtTop,
                    child: Column(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  node.widgetType,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                key: const ValueKey<String>(
                                  'argos-widget-detail-close',
                                ),
                                tooltip: '关闭详情',
                                icon: const Icon(Icons.close),
                                onPressed: onClose,
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            children: <Widget>[
                              _DetailField(
                                label: '组件层级',
                                value: widgetBreadcrumb ?? node.widgetType,
                              ),
                              _DetailField(
                                label: '深度',
                                value: '${node.depth}',
                              ),
                              _DetailField(
                                label: 'Key',
                                value: node.key ?? '无',
                              ),
                              _DetailField(
                                label: '子节点',
                                value: '${node.childCount}',
                              ),
                              _DetailField(
                                label: '全局边界',
                                value: _formatBounds(node.bounds),
                              ),
                              _DetailField(
                                label: '描述',
                                value: node.description.isEmpty
                                    ? '无'
                                    : node.description,
                              ),
                              if (tuningTarget != null) ...<Widget>[
                                const SizedBox(height: 4),
                                _RuntimeTuningEditor(
                                  controller: tuningController!,
                                  targetId: tuningTarget.id,
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                '诊断属性',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (node.properties.isEmpty)
                                Text(
                                  '无可用属性',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                )
                              else
                                for (final property in node.properties)
                                  _DetailField(
                                    label: property.name.isEmpty
                                        ? '属性'
                                        : property.name,
                                    value: property.value,
                                  ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatBounds(Rect? bounds) {
    if (bounds == null) return '不可用';
    return 'x ${bounds.left.toStringAsFixed(1)}, '
        'y ${bounds.top.toStringAsFixed(1)} · '
        '${bounds.width.toStringAsFixed(1)} × '
        '${bounds.height.toStringAsFixed(1)}';
  }
}

class _RuntimeTuningEditor extends StatelessWidget {
  const _RuntimeTuningEditor({
    required this.controller,
    required this.targetId,
  });

  final ArgosTuningController controller;
  final String targetId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final target = controller.target(targetId);
        if (target == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final colorProperties = target.properties
            .whereType<ArgosColorTuningProperty>()
            .toList(growable: false);
        return Container(
          key: const ValueKey<String>('argos-widget-tuning-editor'),
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.primary.withOpacity(0.06),
            border: Border.all(color: scheme.primary.withOpacity(0.26)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '实时调参',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          target.label,
                          key: const ValueKey<String>(
                            'argos-widget-tuning-target-label',
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey<String>('argos-widget-tuning-reset'),
                    onPressed: () => controller.resetTarget(target.id),
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text('重置'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              for (final property in target.properties)
                if (property is ArgosDoubleTuningProperty)
                  _DoubleTuningControl(
                    targetId: target.id,
                    property: property,
                    value: target.values.doubleValue(property.id),
                    onChanged: (value) => controller.updateValue(
                      target.id,
                      property.id,
                      value,
                    ),
                  ),
              if (colorProperties.length == 1)
                _ColorTuningControl(
                  targetId: target.id,
                  property: colorProperties.single,
                  value: target.values.colorValue(colorProperties.single.id),
                  onChanged: (value) => controller.updateValue(
                    target.id,
                    colorProperties.single.id,
                    value,
                  ),
                )
              else if (colorProperties.length > 1)
                _ColorTuningTabs(
                  targetId: target.id,
                  properties: colorProperties,
                  values: target.values,
                  onChanged: (propertyId, value) => controller.updateValue(
                    target.id,
                    propertyId,
                    value,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DoubleTuningControl extends StatelessWidget {
  const _DoubleTuningControl({
    required this.targetId,
    required this.property,
    required this.value,
    required this.onChanged,
  });

  final String targetId;
  final ArgosDoubleTuningProperty property;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(property.label)),
              Text(
                property.format(value),
                key: ValueKey<String>(
                  'argos-widget-tuning-value-$targetId-${property.id}',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider(
            key: ValueKey<String>(
              'argos-widget-tuning-slider-$targetId-${property.id}',
            ),
            value: value.clamp(property.min, property.max).toDouble(),
            min: property.min,
            max: property.max,
            divisions: property.divisions,
            label: property.format(value),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ColorTuningTabs extends StatefulWidget {
  const _ColorTuningTabs({
    required this.targetId,
    required this.properties,
    required this.values,
    required this.onChanged,
  });

  final String targetId;
  final List<ArgosColorTuningProperty> properties;
  final ArgosTuningValues values;
  final void Function(String propertyId, Color value) onChanged;

  @override
  State<_ColorTuningTabs> createState() => _ColorTuningTabsState();
}

class _ColorTuningTabsState extends State<_ColorTuningTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = _createTabController();
  }

  @override
  void didUpdateWidget(covariant _ColorTuningTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_hasSamePropertyIds(oldWidget.properties, widget.properties)) return;
    final oldIndex =
        _selectedIndex.clamp(0, oldWidget.properties.length - 1).toInt();
    final selectedId = oldWidget.properties[oldIndex].id;
    final nextIndex = widget.properties.indexWhere(
      (property) => property.id == selectedId,
    );
    _selectedIndex = nextIndex < 0 ? 0 : nextIndex;
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    _tabController = _createTabController();
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    super.dispose();
  }

  TabController _createTabController() {
    return TabController(
      length: widget.properties.length,
      initialIndex: _selectedIndex,
      vsync: this,
    )..addListener(_handleTabChanged);
  }

  void _handleTabChanged() {
    final nextIndex = _tabController.index;
    if (nextIndex == _selectedIndex || !mounted) return;
    setState(() => _selectedIndex = nextIndex);
  }

  static bool _hasSamePropertyIds(
    List<ArgosColorTuningProperty> first,
    List<ArgosColorTuningProperty> second,
  ) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index].id != second[index].id) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectedIndex =
        _selectedIndex.clamp(0, widget.properties.length - 1).toInt();
    final property = widget.properties[selectedIndex];
    final keyPrefix = 'argos-widget-tuning-color-tabs-${widget.targetId}';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TabBar(
            key: ValueKey<String>(keyPrefix),
            controller: _tabController,
            isScrollable: widget.properties.length > 3,
            labelColor: scheme.primary,
            unselectedLabelColor: scheme.onSurfaceVariant,
            indicatorColor: scheme.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: <Widget>[
              for (final tabProperty in widget.properties)
                Tab(
                  key: ValueKey<String>(
                    '$keyPrefix-${tabProperty.id}',
                  ),
                  text: tabProperty.label,
                ),
            ],
          ),
          _ColorTuningControl(
            key: ValueKey<String>(
              '$keyPrefix-editor-${property.id}',
            ),
            targetId: widget.targetId,
            property: property,
            value: widget.values.colorValue(property.id),
            showLabel: false,
            onChanged: (value) => widget.onChanged(property.id, value),
          ),
        ],
      ),
    );
  }
}

class _ColorTuningControl extends StatefulWidget {
  const _ColorTuningControl({
    Key? key,
    required this.targetId,
    required this.property,
    required this.value,
    required this.onChanged,
    this.showLabel = true,
  }) : super(key: key);

  final String targetId;
  final ArgosColorTuningProperty property;
  final Color value;
  final ValueChanged<Color> onChanged;
  final bool showLabel;

  @override
  State<_ColorTuningControl> createState() => _ColorTuningControlState();
}

const List<ArgosTuningColorOption> _builtInQuickColors =
    <ArgosTuningColorOption>[
  ArgosTuningColorOption(label: '黑色', color: Color(0xFF000000)),
  ArgosTuningColorOption(label: '白色', color: Color(0xFFFFFFFF)),
  ArgosTuningColorOption(label: '灰色', color: Color(0xFF9E9E9E)),
  ArgosTuningColorOption(label: '红色', color: Color(0xFFF44336)),
  ArgosTuningColorOption(label: '橙色', color: Color(0xFFFF9800)),
  ArgosTuningColorOption(label: '黄色', color: Color(0xFFFFEB3B)),
  ArgosTuningColorOption(label: '绿色', color: Color(0xFF4CAF50)),
  ArgosTuningColorOption(label: '蓝色', color: Color(0xFF2196F3)),
  ArgosTuningColorOption(label: '紫色', color: Color(0xFF9C27B0)),
];

class _ColorTuningControlState extends State<_ColorTuningControl> {
  late final TextEditingController _hexController;
  late final FocusNode _hexFocusNode;
  bool _hexIsValid = true;

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController(text: _formatColor(widget.value));
    _hexFocusNode = FocusNode()..addListener(_handleHexFocusChange);
  }

  @override
  void didUpdateWidget(covariant _ColorTuningControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_hexFocusNode.hasFocus) {
      _replaceHexText(_formatColor(widget.value));
      _hexIsValid = true;
    }
  }

  @override
  void dispose() {
    _hexFocusNode
      ..removeListener(_handleHexFocusChange)
      ..dispose();
    _hexController.dispose();
    super.dispose();
  }

  void _handleHexFocusChange() {
    if (_hexFocusNode.hasFocus) return;
    _replaceHexText(_formatColor(widget.value));
    if (!_hexIsValid && mounted) {
      setState(() => _hexIsValid = true);
    }
  }

  void _replaceHexText(String text) {
    _hexController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _handleHexChanged(String input) {
    final color = _parseColor(input);
    final valid = color != null;
    if (_hexIsValid != valid) {
      setState(() => _hexIsValid = valid);
    }
    if (color != null && color != widget.value) {
      widget.onChanged(color);
    }
  }

  static String _formatColor(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  static Color? _parseColor(String input) {
    var value = input.trim();
    if (value.startsWith('#')) value = value.substring(1);
    if (value.toLowerCase().startsWith('0x')) value = value.substring(2);
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8) return null;
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hsv = HSVColor.fromColor(widget.value);
    final keyPrefix =
        'argos-widget-tuning-color-${widget.targetId}-${widget.property.id}';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (widget.showLabel) ...<Widget>[
            Text(widget.property.label),
            const SizedBox(height: 6),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                key: ValueKey<String>('$keyPrefix-preview'),
                width: 44,
                height: 44,
                margin: const EdgeInsets.only(top: 4, right: 10),
                decoration: BoxDecoration(
                  color: widget.value,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black26),
                ),
              ),
              Expanded(
                child: TextField(
                  key: ValueKey<String>('$keyPrefix-hex'),
                  controller: _hexController,
                  focusNode: _hexFocusNode,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 10,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    labelText: '十六进制颜色',
                    hintText: '#RRGGBB 或 #AARRGGBB',
                    errorText: _hexIsValid ? null : '请输入 6 或 8 位十六进制颜色',
                    counterText: '',
                    isDense: true,
                  ),
                  onChanged: _handleHexChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('快选', style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          SizedBox(
            height: 36,
            child: ListView.separated(
              key: ValueKey<String>('$keyPrefix-quick-palette'),
              scrollDirection: Axis.horizontal,
              itemCount: _builtInQuickColors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final option = _builtInQuickColors[index];
                final colorKey = option.color.value
                    .toRadixString(16)
                    .padLeft(8, '0')
                    .toUpperCase();
                return _ColorQuickPickButton(
                  keyName: '$keyPrefix-quick-$colorKey',
                  option: option,
                  selected: option.color == widget.value,
                  onTap: () => widget.onChanged(option.color),
                );
              },
            ),
          ),
          if (widget.property.options.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                for (final option in widget.property.options)
                  ChoiceChip(
                    key: ValueKey<String>('$keyPrefix-${option.label}'),
                    selected: option.color == widget.value,
                    avatar: DecoratedBox(
                      decoration: BoxDecoration(
                        color: option.color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black26),
                      ),
                      child: const SizedBox(width: 16, height: 16),
                    ),
                    label: Text(option.label),
                    onSelected: (_) => widget.onChanged(option.color),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          _ColorChannelSlider(
            keyName: '$keyPrefix-hue',
            label: '色相',
            formattedValue: '${hsv.hue.round()}°',
            value: hsv.hue,
            min: 0,
            max: 360,
            divisions: 360,
            activeColor: HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
            onChanged: (value) => widget.onChanged(
              hsv.withHue(value).toColor(),
            ),
          ),
          _ColorChannelSlider(
            keyName: '$keyPrefix-saturation',
            label: '饱和度',
            formattedValue: '${(hsv.saturation * 100).round()}%',
            value: hsv.saturation,
            min: 0,
            max: 1,
            divisions: 100,
            activeColor: hsv.toColor(),
            onChanged: (value) => widget.onChanged(
              hsv.withSaturation(value).toColor(),
            ),
          ),
          _ColorChannelSlider(
            keyName: '$keyPrefix-value',
            label: '亮度',
            formattedValue: '${(hsv.value * 100).round()}%',
            value: hsv.value,
            min: 0,
            max: 1,
            divisions: 100,
            activeColor: hsv.toColor(),
            onChanged: (value) => widget.onChanged(
              hsv.withValue(value).toColor(),
            ),
          ),
          _ColorChannelSlider(
            keyName: '$keyPrefix-alpha',
            label: '透明度',
            formattedValue: '${(hsv.alpha * 100).round()}%',
            value: hsv.alpha,
            min: 0,
            max: 1,
            divisions: 100,
            activeColor: hsv.toColor(),
            onChanged: (value) => widget.onChanged(
              hsv.withAlpha(value).toColor(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorQuickPickButton extends StatelessWidget {
  const _ColorQuickPickButton({
    required this.keyName,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final String keyName;
  final ArgosTuningColorOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground =
        ThemeData.estimateBrightnessForColor(option.color) == Brightness.dark
            ? Colors.white
            : Colors.black;
    return Tooltip(
      message: option.label,
      child: Semantics(
        label: '${option.label}快捷颜色',
        button: true,
        selected: selected,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: ValueKey<String>(keyName),
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: option.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? scheme.primary : Colors.black38,
                  width: selected ? 3 : 1,
                ),
              ),
              child: selected
                  ? Icon(Icons.check, size: 18, color: foreground)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorChannelSlider extends StatelessWidget {
  const _ColorChannelSlider({
    required this.keyName,
    required this.label,
    required this.formattedValue,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.activeColor,
    required this.onChanged,
  });

  final String keyName;
  final String label;
  final String formattedValue;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final Color activeColor;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        SizedBox(
          width: 56,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: Slider(
            key: ValueKey<String>(keyName),
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: activeColor,
            label: formattedValue,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(
            formattedValue,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
