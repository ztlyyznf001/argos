import 'package:flutter/material.dart';
import 'package:argos_inspector/argos_inspector.dart';

/// Top-level event-type filter. This is the primary axis: HTTP method is only
/// meaningful once you've narrowed to network records, so it hangs off this.
enum _EventFilter {
  all('全部', null),
  network('网络', ArgosKind.network),
  crash('崩溃', ArgosKind.crash),
  jank('卡顿', ArgosKind.jank),
  resource('资源', ArgosKind.resource);

  const _EventFilter(this.label, this.kind);
  final String label;
  final String? kind;
}

class ArgosPacketListPage extends StatefulWidget {
  const ArgosPacketListPage({Key? key}) : super(key: key);

  @override
  State<ArgosPacketListPage> createState() => _ArgosPacketListPageState();
}

class _ArgosPacketListPageState extends State<ArgosPacketListPage> {
  List<ArgosPacketRecord> _allRecords = [];
  String _searchQuery = '';
  String _selectedMethod = 'ALL';
  _EventFilter _selectedEvent = _EventFilter.all;
  bool _captureEnabled = ArgosManager.instance.captureEnabled;

  static const _methods = ['ALL', 'GET', 'POST', 'PUT', 'DELETE'];

  /// Method filtering only applies where a method exists. Showing it while
  /// "崩溃" is selected would offer combinations that are empty by construction.
  bool get _methodFilterVisible =>
      _selectedEvent == _EventFilter.all ||
      _selectedEvent == _EventFilter.network;

  /// Everything matching the search box, before the event-type filter. Counts
  /// on the type chips are computed against this so each chip reports what you
  /// would actually see if you tapped it.
  List<ArgosPacketRecord> get _searched {
    if (_searchQuery.isEmpty) return _allRecords;
    final q = _searchQuery.toLowerCase();
    return _allRecords.where((r) => r.uri.toLowerCase().contains(q)).toList();
  }

  Map<_EventFilter, int> get _counts {
    final searched = _searched;
    return {
      for (final f in _EventFilter.values)
        f: f.kind == null
            ? searched.length
            : searched.where((r) => r.kind == f.kind).length,
    };
  }

  List<ArgosPacketRecord> get _filtered {
    return _searched.where((r) {
      final kindMatch =
          _selectedEvent.kind == null || r.kind == _selectedEvent.kind;
      // A non-network record has no HTTP verb; the method filter must never be
      // the reason it disappears.
      final methodMatch = _selectedMethod == 'ALL' ||
          (r.kind == ArgosKind.network &&
              r.method.toUpperCase() == _selectedMethod);
      return kindMatch && methodMatch;
    }).toList();
  }

  /// Returns ordered groups: named routes first (sorted by first-seen order),
  /// then "未知页面" at the end if any empty-routeName records exist.
  List<_RouteGroup> get _groups {
    final filtered = _filtered;
    // Preserve insertion order of route names as seen in the full sorted list.
    final seen = <String>[];
    for (final r in filtered) {
      if (!seen.contains(r.routeName)) seen.add(r.routeName);
    }

    final groups = <_RouteGroup>[];
    for (final route in seen) {
      if (route.isNotEmpty) {
        final records = filtered.where((r) => r.routeName == route).toList();
        if (records.isNotEmpty) groups.add(_RouteGroup(route, records));
      }
    }
    // Append "未知页面" last.
    final unknown = filtered.where((r) => r.routeName.isEmpty).toList();
    if (unknown.isNotEmpty) groups.add(_RouteGroup('未知页面', unknown));
    return groups;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await ArgosPacketStorage.instance.getAllAsync();
    if (mounted) {
      setState(() {
        _allRecords = records;
      });
    }
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('将删除所有记录，此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ArgosPacketStorage.instance.clear();
      _load();
    }
  }

  void _selectEvent(_EventFilter f) {
    setState(() {
      _selectedEvent = f;
      // Dropping to a kind that has no methods would otherwise strand a stale
      // "POST" that silently re-applies when the user comes back to 网络.
      if (!_methodFilterVisible) _selectedMethod = 'ALL';
    });
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    final counts = _counts;
    final hasAny = _allRecords.isNotEmpty;
    final hasFiltered = _filtered.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.radar, size: 18, color: Colors.white),
            SizedBox(width: 6),
            // The toolbar's middle slot is narrow once the capture toggle and
            // 清空 take their space; let the title shrink rather than overflow.
            Flexible(
              child: Text('Argos 记录', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        actions: [
          IconButton(
            icon: Icon(
              _captureEnabled
                  ? Icons.pause_circle_outline
                  : Icons.fiber_manual_record,
              color: _captureEnabled ? Colors.white : Colors.redAccent,
            ),
            tooltip: _captureEnabled ? '暂停抓包' : '开始抓包',
            onPressed: () {
              setState(() {
                _captureEnabled = !_captureEnabled;
                ArgosManager.instance.captureEnabled = _captureEnabled;
              });
            },
          ),
          if (hasAny)
            TextButton(
              onPressed: _confirmClear,
              child: const Text('清空', style: TextStyle(color: Colors.white)),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: '搜索 URL / 事件...',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                prefixIcon:
                    const Icon(Icons.search, size: 18, color: Colors.white70),
                hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white54),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white, width: 1.5),
                ),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _EventFilterBar(
            selected: _selectedEvent,
            counts: counts,
            onSelected: _selectEvent,
          ),
          if (_methodFilterVisible)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                itemCount: _methods.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final m = _methods[i];
                  final selected = _selectedMethod == m;
                  return ChoiceChip(
                    label: Text(m, style: const TextStyle(fontSize: 11)),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedMethod = m),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  );
                },
              ),
            ),
          Expanded(
            child: !hasAny
                ? const _EmptyState(
                    icon: Icons.inbox_outlined,
                    text: '暂无记录',
                  )
                : !hasFiltered
                    ? _EmptyState(
                        icon: _searchQuery.isNotEmpty
                            ? Icons.search_off
                            : ArgosKindStyle.icon(_selectedEvent.kind ?? ''),
                        text: _searchQuery.isNotEmpty
                            ? '无匹配记录'
                            : '暂无${_selectedEvent.label}记录',
                      )
                    : ListView.builder(
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          return _RouteGroupTile(
                            group: groups[index],
                            onRecordTap: _openDetail,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(ArgosPacketRecord record) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ArgosPacketDetailPage(record: record)),
    );
    _load();
  }
}

// ─── Event type filter bar ──────────────────────────────────────────────────

class _EventFilterBar extends StatelessWidget {
  const _EventFilterBar({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final _EventFilter selected;
  final Map<_EventFilter, int> counts;
  final ValueChanged<_EventFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _EventFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final f = _EventFilter.values[i];
          final isSelected = f == selected;
          final count = counts[f] ?? 0;
          final color = f.kind == null
              ? scheme.primary
              : ArgosColors.kind(context, f.kind!);
          return ChoiceChip(
            selected: isSelected,
            onSelected: (_) => onSelected(f),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            selectedColor: color.withValues(alpha: 0.18),
            side: BorderSide(
              color: isSelected ? color : scheme.outlineVariant,
            ),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (f.kind != null) ...[
                  Icon(ArgosKindStyle.icon(f.kind!), size: 13, color: color),
                  const SizedBox(width: 4),
                ],
                Text(
                  f.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    color: count == 0 ? scheme.onSurfaceVariant : color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ─── Route grouping ─────────────────────────────────────────────────────────

class _RouteGroup {
  final String routeName;
  final List<ArgosPacketRecord> records;
  _RouteGroup(this.routeName, this.records);
}

class _RouteGroupTile extends StatefulWidget {
  const _RouteGroupTile({
    Key? key,
    required this.group,
    required this.onRecordTap,
  }) : super(key: key);

  final _RouteGroup group;
  final void Function(ArgosPacketRecord) onRecordTap;

  @override
  State<_RouteGroupTile> createState() => _RouteGroupTileState();
}

class _RouteGroupTileState extends State<_RouteGroupTile> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final scheme = Theme.of(context).colorScheme;
    final entries = argosBuildListEntries(group.records);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(2),
                    bottomRight: Radius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  child: Row(
                    children: [
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          group.routeName,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${group.records.length}',
                          style: TextStyle(
                              fontSize: 11,
                              color: scheme.primary,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: scheme.outlineVariant),
        if (_expanded)
          ...entries.map((e) {
            if (e is ArgosResourceRun) {
              return _ResourceClusterItem(
                cluster: e,
                onSampleTap: widget.onRecordTap,
              );
            }
            final r = (e as ArgosRecordEntry).record;
            return _PacketListItem(
              record: r,
              onTap: () => widget.onRecordTap(r),
            );
          }),
      ],
    );
  }
}

// ─── Resource cluster ───────────────────────────────────────────────────────

class _ResourceClusterItem extends StatefulWidget {
  const _ResourceClusterItem({
    required this.cluster,
    required this.onSampleTap,
  });

  final ArgosResourceRun cluster;
  final void Function(ArgosPacketRecord) onSampleTap;

  @override
  State<_ResourceClusterItem> createState() => _ResourceClusterItemState();
}

class _ResourceClusterItemState extends State<_ResourceClusterItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.cluster;
    final scheme = Theme.of(context).colorScheme;
    final color = ArgosColors.kind(context, ArgosKind.resource);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Icon(ArgosKindStyle.icon(ArgosKind.resource),
                        size: 18, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '内存 ${ArgosFormat.bytes(c.currentRss)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '峰值 ${ArgosFormat.bytes(c.peakRss)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: color),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${c.count} 次采样 · '
                          '${ArgosFormat.clock(c.startTs)}–${ArgosFormat.clock(c.endTs)}',
                          style: TextStyle(
                              fontSize: 11, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 56,
                    height: 24,
                    child: CustomPaint(
                      painter: _SparklinePainter(c.series, color),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: scheme.outlineVariant),
            ...c.samples.map((s) => InkWell(
                  onTap: () => widget.onSampleTap(s),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    child: Row(
                      children: [
                        Text(
                          ArgosFormat.clock(s.startTimestamp),
                          style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          ArgosFormat.bytes(ArgosResourceRun.rssOf(s)),
                          style: const TextStyle(fontSize: 12),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right,
                            size: 14, color: scheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

/// Minimal memory trend line. Deliberately hand-drawn rather than pulling in a
/// charting dependency for a 56×24 sparkline.
class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values, this.color);
  final List<int> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final min = values.reduce((a, b) => a < b ? a : b).toDouble();
    final max = values.reduce((a, b) => a > b ? a : b).toDouble();
    final span = (max - min).abs() < 1 ? 1.0 : max - min;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * (i / (values.length - 1));
      final y = size.height - ((values[i] - min) / span) * size.height;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color;
}

// ─── List items ─────────────────────────────────────────────────────────────

class _PacketListItem extends StatelessWidget {
  const _PacketListItem({Key? key, required this.record, required this.onTap})
      : super(key: key);

  final ArgosPacketRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return record.kind == ArgosKind.network
        ? _buildNetworkItem(context)
        : _buildApmItem(context);
  }

  Widget _buildNetworkItem(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = ArgosColors.status(context, record.responseCode);
    final methodColor = ArgosColors.method(context, record.method);
    final isError = record.error != null || record.responseCode >= 400;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        // Failures get a border, not just a red number — they should be
        // findable while scrolling past, without reading each row.
        side: isError
            ? BorderSide(color: statusColor.withValues(alpha: 0.5))
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 48,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: methodColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  record.method,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: methodColor),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _shortUrl(record.uri),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ArgosFormat.relativeAndClock(record.startTimestamp),
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      record.responseCode > 0
                          ? record.responseCode.toString()
                          : '-',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (record.responseSize > 0) ...[
                        Text(
                          ArgosFormat.bytes(record.responseSize),
                          style: TextStyle(
                              fontSize: 11, color: scheme.onSurfaceVariant),
                        ),
                        Text(
                          ' · ',
                          style: TextStyle(
                              fontSize: 11, color: scheme.onSurfaceVariant),
                        ),
                      ],
                      Text(
                        '${record.durationMs} ms',
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              ArgosColors.duration(context, record.durationMs),
                          fontWeight: record.durationMs >= 1000
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// List item for non-network APM events (crash / jank / resource): renders a
  /// kind-specific icon and label instead of HTTP method/status/duration.
  Widget _buildApmItem(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = ArgosColors.kind(context, record.kind);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: record.kind == ArgosKind.crash
            ? BorderSide(color: color.withValues(alpha: 0.5))
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(ArgosKindStyle.icon(record.kind),
                    size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.uri,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ArgosFormat.relativeAndClock(record.startTimestamp),
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  ArgosKindStyle.label(record.kind),
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortUrl(String uri) {
    try {
      final u = Uri.parse(uri);
      final path = u.path.isEmpty ? '/' : u.path;
      return '${u.host}$path';
    } catch (_) {
      return uri;
    }
  }
}
