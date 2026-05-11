import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:argos/model/argos_http_info_model.dart';
import 'package:argos/ui/argos_curl_builder.dart';

class ArgosPacketDetailPage extends StatelessWidget {
  const ArgosPacketDetailPage({Key? key, required this.record})
      : super(key: key);

  final ArgosPacketRecord record;

  @override
  Widget build(BuildContext context) {
    final methodColor = _methodColor(record.method);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: methodColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: methodColor.withValues(alpha: 0.6), width: 1),
                ),
                child: Text(
                  record.method,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
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

  Color _methodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return const Color(0xFF64B5F6);
      case 'POST':
        return const Color(0xFF81C784);
      case 'PUT':
        return const Color(0xFFFFB74D);
      case 'DELETE':
        return const Color(0xFFE57373);
      case 'PATCH':
        return const Color(0xFFCE93D8);
      default:
        return Colors.blueGrey.shade200;
    }
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
          _InfoRow(label: '时间', value: _formatTime(record.startTimestamp)),
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

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
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
        // Error card
        if (record.error != null) _ErrorCard(error: record.error!),
        _Section(title: '响应信息', children: [
          _InfoRow(label: '状态码', value: record.responseCode.toString()),
          _InfoRow(label: '大小', value: '${record.responseSize} bytes'),
        ]),
        if (record.responseHeaders.isNotEmpty)
          _HeaderSection(title: '响应头', headers: record.responseHeaders),
        _BodySection(
          title: '响应体',
          body: record.responseBody,
          headers: record.responseHeaders,
          onCopy: (formattedBody) => _copyResponseBody(context, formattedBody),
        ),
      ],
    );
  }

  void _copyResponseBody(BuildContext context, String body) {
    Clipboard.setData(ClipboardData(text: body));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制响应体'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// ─── Shared widgets ─────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red.shade300),
        borderRadius: BorderRadius.circular(6),
        color: Colors.red.shade50,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              error,
              style: const TextStyle(fontSize: 12, color: Colors.red),
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
          side: BorderSide(color: Theme.of(context).dividerColor),
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
          side: BorderSide(color: Theme.of(context).dividerColor),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
                fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          SelectableText(
            value,
            style: const TextStyle(fontSize: 12),
          ),
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
      this.onCopy});
  final String title;
  final String body;
  final Map<String, String> headers;
  final ValueChanged<String>? onCopy;

  @override
  Widget build(BuildContext context) {
    final formatted = _formatBody(body, headers);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Theme.of(context).dividerColor),
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
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (onCopy != null)
                    IconButton(
                      icon: const Icon(Icons.copy_outlined, size: 16),
                      tooltip: '复制响应体',
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
                      color: Colors.grey.shade200,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
