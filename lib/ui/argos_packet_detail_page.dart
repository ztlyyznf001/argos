import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:argos_inspector/model/argos_http_info_model.dart';
import 'package:argos_inspector/ui/argos_curl_builder.dart';
import 'package:argos_inspector/ui/argos_ui_kit.dart';

/// Dispatches to a view matching the record's kind.
///
/// Network records keep the request/response tab pair. APM events get a single
/// typed page instead: a crash has no "request", and forcing it into that shape
/// only produced two empty tabs.
class ArgosPacketDetailPage extends StatelessWidget {
  const ArgosPacketDetailPage({Key? key, required this.record})
      : super(key: key);

  final ArgosPacketRecord record;

  @override
  Widget build(BuildContext context) {
    if (record.kind == ArgosKind.network) {
      return _NetworkDetailPage(record: record);
    }
    return _ApmDetailPage(record: record);
  }
}

// ─── Shared chrome ──────────────────────────────────────────────────────────

const _appBarGradient = LinearGradient(
  colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// The dark app bar is a fixed brand surface, so its foreground stays white in
/// both themes; only the badge tint varies by method/kind.
Widget _badge(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withValues(alpha: 0.7), width: 1),
    ),
    child: Text(
      text,
      style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
    ),
  );
}

// ─── Network detail (unchanged structure) ───────────────────────────────────

class _NetworkDetailPage extends StatelessWidget {
  const _NetworkDetailPage({required this.record});
  final ArgosPacketRecord record;

  @override
  Widget build(BuildContext context) {
    final methodColor = ArgosColors.method(context, record.method);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: _appBarGradient),
          ),
          title: Row(
            children: [
              _badge(record.method, methodColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _shortUrl(record.uri),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: '复制 cURL',
              onPressed: () => _copyCurl(context),
            ),
          ],
          bottom: const TabBar(
            indicator: ShapeDecoration(
              shape: StadiumBorder(),
              color: Colors.white24,
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: '请求'),
              Tab(text: '响应'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _RequestTab(record: record),
            _ResponseTab(record: record),
          ],
        ),
      ),
    );
  }

  void _copyCurl(BuildContext context) {
    final curl = ArgosCurlBuilder.build(record);
    Clipboard.setData(ClipboardData(text: curl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制 cURL'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _shortUrl(String uri) {
    try {
      final u = Uri.parse(uri);
      return u.path.isEmpty ? u.host : u.path;
    } catch (_) {
      return uri.length > 40 ? '${uri.substring(0, 40)}…' : uri;
    }
  }
}

// ─── APM detail ─────────────────────────────────────────────────────────────

class _ApmDetailPage extends StatelessWidget {
  const _ApmDetailPage({required this.record});
  final ArgosPacketRecord record;

  @override
  Widget build(BuildContext context) {
    final color = ArgosColors.kind(context, record.kind);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: _appBarGradient),
        ),
        title: Row(
          children: [
            _badge(ArgosKindStyle.label(record.kind), color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                record.uri,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    switch (record.kind) {
      case ArgosKind.crash:
        return _CrashView(record: record);
      case ArgosKind.jank:
        return _JankView(record: record);
      case ArgosKind.resource:
        return _ResourceView(record: record);
      default:
        return _UnknownView(record: record);
    }
  }
}

class _CrashView extends StatelessWidget {
  const _CrashView({required this.record});
  final ArgosPacketRecord record;

  @override
  Widget build(BuildContext context) {
    final stack = record.responseBody;
    final library = record.responseHeaders['library'];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (record.error != null) _ErrorCard(error: record.error!),
        _Section(title: '基本信息', children: [
          _InfoRow(label: '路由', value: _routeLabel(record.routeName)),
          if (library != null && library.isNotEmpty)
            _InfoRow(label: '来源', value: library),
          _InfoRow(
              label: '时间', value: ArgosFormat.dateTime(record.startTimestamp)),
        ]),
        _BodySection(
          title: '堆栈',
          body: stack,
          headers: const {},
          copyTooltip: '复制堆栈',
          onCopy: (s) => _copy(context, s, '已复制堆栈'),
        ),
      ],
    );
  }
}

class _JankView extends StatelessWidget {
  const _JankView({required this.record});
  final ArgosPacketRecord record;

  /// The jank monitor serializes its split as `key=value` lines in the body.
  Map<String, String> get _metrics {
    final map = <String, String>{};
    for (final line in record.responseBody.split('\n')) {
      final i = line.indexOf('=');
      if (i > 0) {
        map[line.substring(0, i).trim()] = line.substring(i + 1).trim();
      }
    }
    return map;
  }

  double _ms(String? raw) =>
      double.tryParse((raw ?? '').replaceAll('ms', '').trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final m = _metrics;
    final build = _ms(m['build']);
    final raster = _ms(m['raster']);
    final dropped = record.responseCode;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _Section(title: '卡顿概览', children: [
          _InfoRow(label: '丢帧数', value: '$dropped 帧'),
          _InfoRow(label: '区间总耗时', value: m['total'] ?? '-'),
          _InfoRow(label: '最大单帧', value: m['maxFrame'] ?? '-'),
          _InfoRow(
              label: '时间', value: ArgosFormat.dateTime(record.startTimestamp)),
          _InfoRow(label: '路由', value: _routeLabel(record.routeName)),
        ]),
        _Section(title: '线程耗时拆分', children: [
          _ThreadSplitBar(buildMs: build, rasterMs: raster),
        ]),
      ],
    );
  }
}

/// Shows whether the stall lived on the UI thread or the raster thread — the
/// single question a jank record exists to answer.
class _ThreadSplitBar extends StatelessWidget {
  const _ThreadSplitBar({required this.buildMs, required this.rasterMs});
  final double buildMs;
  final double rasterMs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = buildMs + rasterMs;
    final buildFlex = total <= 0 ? 1 : (buildMs * 100).round().clamp(1, 100000);
    final rasterFlex =
        total <= 0 ? 1 : (rasterMs * 100).round().clamp(1, 100000);
    const buildColor = Color(0xFF5C6BC0);
    const rasterColor = Color(0xFF26A69A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                Expanded(flex: buildFlex, child: Container(color: buildColor)),
                Expanded(
                    flex: rasterFlex, child: Container(color: rasterColor)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _LegendRow(
          color: buildColor,
          label: 'build（UI 线程）',
          value: '${buildMs.toStringAsFixed(1)} ms',
        ),
        _LegendRow(
          color: rasterColor,
          label: 'raster（Raster 线程）',
          value: '${rasterMs.toStringAsFixed(1)} ms',
        ),
        const SizedBox(height: 4),
        Text(
          total <= 0
              ? '无耗时数据'
              : buildMs >= rasterMs
                  ? '瓶颈偏向 UI 线程'
                  : '瓶颈偏向 Raster 线程',
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow(
      {required this.color, required this.label, required this.value});
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          Text(value,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ResourceView extends StatelessWidget {
  const _ResourceView({required this.record});
  final ArgosPacketRecord record;

  @override
  Widget build(BuildContext context) {
    final h = record.responseHeaders;
    final current = int.tryParse(h['currentRss'] ?? '') ?? record.responseSize;
    final max = int.tryParse(h['maxRss'] ?? '') ?? 0;
    final cpu = h['cpuPercent'];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _Section(title: '内存采样', children: [
          _InfoRow(label: '当前 RSS', value: ArgosFormat.bytes(current)),
          if (max > 0) _InfoRow(label: '峰值 RSS', value: ArgosFormat.bytes(max)),
          // CPU is left blank rather than filled with an estimate: the resource
          // monitor deliberately reports nothing when it cannot measure it.
          _InfoRow(label: 'CPU', value: cpu != null ? '$cpu%' : '不可用'),
          _InfoRow(
              label: '采样时刻',
              value: ArgosFormat.dateTime(record.startTimestamp)),
          _InfoRow(label: '路由', value: _routeLabel(record.routeName)),
        ]),
      ],
    );
  }
}

class _UnknownView extends StatelessWidget {
  const _UnknownView({required this.record});
  final ArgosPacketRecord record;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _Section(title: '事件', children: [
          _InfoRow(label: '类型', value: record.kind),
          _InfoRow(label: '摘要', value: record.uri),
          _InfoRow(
              label: '时间', value: ArgosFormat.dateTime(record.startTimestamp)),
        ]),
        if (record.responseBody.isNotEmpty)
          _BodySection(
              title: '详情', body: record.responseBody, headers: const {}),
      ],
    );
  }
}

String _routeLabel(String routeName) => routeName.isEmpty ? '未知页面' : routeName;

void _copy(BuildContext context, String text, String message) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
  );
}

// ─── 请求 Tab ───────────────────────────────────────────────────────────────

class _RequestTab extends StatelessWidget {
  const _RequestTab({required this.record});
  final ArgosPacketRecord record;

  @override
  Widget build(BuildContext context) {
    final queryParams = Uri.tryParse(record.uri)?.queryParameters ?? {};
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _Section(title: '基本信息', children: [
          _InfoRow(label: 'URL', value: record.uri),
          _InfoRow(label: 'Method', value: record.method),
          _InfoRow(label: '耗时', value: '${record.durationMs} ms'),
          _InfoRow(
              label: '时间', value: ArgosFormat.dateTime(record.startTimestamp)),
        ]),
        if (queryParams.isNotEmpty)
          _Section(
            title: 'Query Params',
            children: queryParams.entries
                .map((e) => _InfoRow(label: e.key, value: e.value))
                .toList(),
          ),
        if (record.requestHeaders.isNotEmpty)
          _HeaderSection(title: '请求头', headers: record.requestHeaders),
        if (record.requestBody.isNotEmpty)
          _BodySection(
              title: '请求体',
              body: record.requestBody,
              headers: record.requestHeaders),
      ],
    );
  }
}

// ─── 响应 Tab ───────────────────────────────────────────────────────────────

class _ResponseTab extends StatelessWidget {
  const _ResponseTab({required this.record});
  final ArgosPacketRecord record;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (record.error != null) _ErrorCard(error: record.error!),
        _Section(title: '响应信息', children: [
          _InfoRow(label: '状态码', value: record.responseCode.toString()),
          _InfoRow(label: '大小', value: ArgosFormat.bytes(record.responseSize)),
        ]),
        if (record.responseHeaders.isNotEmpty)
          _HeaderSection(title: '响应头', headers: record.responseHeaders),
        _BodySection(
          title: '响应体',
          body: record.responseBody,
          headers: record.responseHeaders,
          copyTooltip: '复制响应体',
          onCopy: (formatted) => _copy(context, formatted, '已复制响应体'),
        ),
      ],
    );
  }
}

// ─── Shared widgets ─────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    final color = ArgosColors.kind(context, ArgosKind.crash);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: 0.08),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              error,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(title),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.title, required this.headers});
  final String title;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(title),
              ...headers.entries
                  .map((e) => _HeaderItem(name: e.key, value: e.value)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderItem extends StatelessWidget {
  const _HeaderItem({required this.name, required this.value});
  final String name;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500),
          ),
          SelectableText(value, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _BodySection extends StatelessWidget {
  const _BodySection(
      {required this.title,
      required this.body,
      required this.headers,
      this.onCopy,
      this.copyTooltip = '复制'});
  final String title;
  final String body;
  final Map<String, String> headers;
  final ValueChanged<String>? onCopy;
  final String copyTooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final formatted = _formatBody(body, headers);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (onCopy != null)
                    IconButton(
                      icon: const Icon(Icons.copy_outlined, size: 16),
                      tooltip: copyTooltip,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onCopy!(formatted),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SelectableText(
                      formatted.isEmpty ? '(empty)' : formatted,
                      style: const TextStyle(
                          fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatBody(String body, Map<String, String> headers) {
    if (body.isEmpty) return body;
    final contentType = headers.entries
        .firstWhere((e) => e.key.toLowerCase() == 'content-type',
            orElse: () => const MapEntry('', ''))
        .value;
    if (contentType.contains('json')) {
      try {
        final obj = jsonDecode(body);
        return const JsonEncoder.withIndent('  ').convert(obj);
      } catch (_) {}
    }
    return body;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          ),
          Expanded(
            child: SelectableText(value, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }
}
