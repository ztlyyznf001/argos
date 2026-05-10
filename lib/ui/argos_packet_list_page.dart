import 'package:flutter/material.dart';
import 'package:argos/argos.dart';

class ArgosPacketListPage extends StatefulWidget {
  const ArgosPacketListPage({Key? key}) : super(key: key);

  @override
  State<ArgosPacketListPage> createState() => _ArgosPacketListPageState();
}

class _ArgosPacketListPageState extends State<ArgosPacketListPage> {
  List<ArgosPacketRecord> _allRecords = [];
  String _searchQuery = '';
  String _selectedMethod = 'ALL';
  bool _captureEnabled = ArgosManager.instance.captureEnabled;

  static const _methods = ['ALL', 'GET', 'POST', 'PUT', 'DELETE'];

  List<ArgosPacketRecord> get _filtered {
    return _allRecords.where((r) {
      final urlMatch = _searchQuery.isEmpty ||
          r.uri.toLowerCase().contains(_searchQuery.toLowerCase());
      final methodMatch = _selectedMethod == 'ALL' ||
          r.method.toUpperCase() == _selectedMethod;
      return urlMatch && methodMatch;
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
        content: const Text('将删除所有抓包记录，此操作不可撤销。'),
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

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
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
            Icon(Icons.wifi_tethering, size: 18, color: Colors.white),
            SizedBox(width: 6),
            Text('抓包记录'),
          ],
        ),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        actions: [
          IconButton(
            icon: Icon(
              _captureEnabled ? Icons.pause_circle_outline : Icons.fiber_manual_record,
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
                hintText: '搜索 URL...',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                prefixIcon: const Icon(Icons.search, size: 18, color: Colors.white70),
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
          // Method filter chips
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
                  label: Text(m,
                      style: TextStyle(
                          fontSize: 11,
                          color: selected ? Colors.white : null)),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedMethod = m),
                  selectedColor: Theme.of(context).primaryColor,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              },
            ),
          ),
          // Grouped list
          Expanded(
            child: !hasAny
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('暂无抓包记录',
                            style:
                                TextStyle(color: Colors.grey, fontSize: 15)),
                      ],
                    ),
                  )
                : !hasFiltered
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off,
                                size: 48, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('无匹配记录',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 15)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          return _RouteGroupTile(
                            group: group,
                            onRecordTap: (record) async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ArgosPacketDetailPage(record: record),
                                ),
                              );
                              _load();
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

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
                  color: Theme.of(context).primaryColor,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(2),
                    bottomRight: Radius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 11),
                  child: Row(
                    children: [
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: Colors.grey,
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
                          color: Theme.of(context)
                              .primaryColor
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${group.records.length}',
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).primaryColor,
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
        const Divider(height: 1),
        if (_expanded)
          ...group.records.map((record) => _PacketListItem(
                record: record,
                onTap: () => widget.onRecordTap(record),
              )),
      ],
    );
  }
}

class _PacketListItem extends StatelessWidget {
  const _PacketListItem(
      {Key? key, required this.record, required this.onTap})
      : super(key: key);

  final ArgosPacketRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(record.responseCode);
    final methodColor = _methodColor(record.method);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                      _formatTime(record.startTimestamp),
                      style:
                          const TextStyle(fontSize: 11, color: Colors.grey),
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
                  Text(
                    '${record.durationMs} ms',
                    style: TextStyle(
                        fontSize: 11,
                        color: _durationColor(record.durationMs)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _methodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return const Color(0xFF1976D2);
      case 'POST':
        return const Color(0xFF388E3C);
      case 'PUT':
        return const Color(0xFFF57C00);
      case 'DELETE':
        return const Color(0xFFD32F2F);
      case 'PATCH':
        return const Color(0xFF7B1FA2);
      default:
        return Colors.blueGrey;
    }
  }

  Color _durationColor(int ms) {
    if (ms > 3000) return Colors.red;
    if (ms >= 1000) return Colors.orange;
    return Colors.grey;
  }

  Color _statusColor(int code) {
    if (code >= 200 && code < 300) return Colors.green;
    if (code >= 300 && code < 400) return Colors.orange;
    if (code >= 400) return Colors.red;
    return Colors.grey;
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

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}
