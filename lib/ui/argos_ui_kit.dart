import 'package:flutter/material.dart';
import 'package:argos_inspector/model/argos_http_info_model.dart';

/// Record kinds carried by [ArgosPacketRecord.kind].
abstract class ArgosKind {
  static const network = 'network';
  static const crash = 'crash';
  static const jank = 'jank';
  static const resource = 'resource';
}

/// Semantic colors for HTTP methods and event kinds.
///
/// These are information encodings, not theme decoration: the hue is fixed so
/// that "red means danger" holds in every theme. Only lightness shifts between
/// light and dark mode, to keep contrast against the surface.
abstract class ArgosColors {
  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color _pick(BuildContext context, Color light, Color dark) =>
      _isDark(context) ? dark : light;

  static Color method(BuildContext context, String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return _pick(context, const Color(0xFF1976D2), const Color(0xFF64B5F6));
      case 'POST':
        return _pick(context, const Color(0xFF388E3C), const Color(0xFF81C784));
      case 'PUT':
        return _pick(context, const Color(0xFFF57C00), const Color(0xFFFFB74D));
      case 'DELETE':
        return _pick(context, const Color(0xFFD32F2F), const Color(0xFFE57373));
      case 'PATCH':
        return _pick(context, const Color(0xFF7B1FA2), const Color(0xFFCE93D8));
      default:
        return _pick(context, const Color(0xFF546E7A), const Color(0xFFB0BEC5));
    }
  }

  static Color kind(BuildContext context, String kind) {
    switch (kind) {
      case ArgosKind.crash:
        return _pick(context, const Color(0xFFD32F2F), const Color(0xFFE57373));
      case ArgosKind.jank:
        return _pick(context, const Color(0xFFF57C00), const Color(0xFFFFB74D));
      case ArgosKind.resource:
        return _pick(context, const Color(0xFF00897B), const Color(0xFF4DB6AC));
      case ArgosKind.network:
        return _pick(context, const Color(0xFF1976D2), const Color(0xFF64B5F6));
      default:
        return _pick(context, const Color(0xFF546E7A), const Color(0xFFB0BEC5));
    }
  }

  static Color status(BuildContext context, int code) {
    if (code >= 200 && code < 300) {
      return _pick(context, const Color(0xFF2E7D32), const Color(0xFF81C784));
    }
    if (code >= 300 && code < 400) {
      return _pick(context, const Color(0xFFEF6C00), const Color(0xFFFFB74D));
    }
    if (code >= 400) {
      return _pick(context, const Color(0xFFC62828), const Color(0xFFEF9A9A));
    }
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  /// Slow requests are worth spotting at a glance: >3s reads as an error, 1–3s
  /// as a warning, anything faster stays visually quiet.
  static Color duration(BuildContext context, int ms) {
    if (ms > 3000) {
      return _pick(context, const Color(0xFFC62828), const Color(0xFFEF9A9A));
    }
    if (ms >= 1000) {
      return _pick(context, const Color(0xFFEF6C00), const Color(0xFFFFB74D));
    }
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }
}

/// Icon + label for each event kind, shared by the list and the detail title so
/// the two never drift apart.
abstract class ArgosKindStyle {
  static IconData icon(String kind) {
    switch (kind) {
      case ArgosKind.crash:
        return Icons.bug_report;
      case ArgosKind.jank:
        return Icons.slow_motion_video;
      case ArgosKind.resource:
        return Icons.memory;
      case ArgosKind.network:
        return Icons.swap_vert;
      default:
        return Icons.info_outline;
    }
  }

  static String label(String kind) {
    switch (kind) {
      case ArgosKind.crash:
        return '崩溃';
      case ArgosKind.jank:
        return '卡顿';
      case ArgosKind.resource:
        return '资源';
      case ArgosKind.network:
        return '网络';
      default:
        return kind.toUpperCase();
    }
  }
}

// ─── Resource sample aggregation ────────────────────────────────────────────

/// One rendered row in the record list.
abstract class ArgosListEntry {
  const ArgosListEntry();
}

/// A single record, rendered on its own row.
class ArgosRecordEntry extends ArgosListEntry {
  const ArgosRecordEntry(this.record);
  final ArgosPacketRecord record;
}

/// A run of consecutive resource samples, collapsed into one expandable row.
class ArgosResourceRun extends ArgosListEntry {
  const ArgosResourceRun(this.samples);
  final List<ArgosPacketRecord> samples;

  int get count => samples.length;

  static int rssOf(ArgosPacketRecord r) =>
      int.tryParse(r.responseHeaders['currentRss'] ?? '') ?? r.responseSize;

  static int maxRssOf(ArgosPacketRecord r) =>
      int.tryParse(r.responseHeaders['maxRss'] ?? '') ?? rssOf(r);

  List<int> get series => samples.map(rssOf).toList();

  /// Last sample in the run — the level the app settled at.
  int get currentRss => rssOf(samples.last);

  /// Highest sample in the run. Surfaced in the collapsed state on purpose: an
  /// average or a last-value would hide a spike, which is the one thing you
  /// open a memory timeline to find.
  int get peakRss => series.reduce((a, b) => a > b ? a : b);

  /// Process-lifetime peak as reported by the samples themselves.
  int get reportedMaxRss =>
      samples.map(maxRssOf).reduce((a, b) => a > b ? a : b);

  int get startTs => samples.first.startTimestamp;
  int get endTs => samples.last.startTimestamp;
}

/// Collapses runs of consecutive resource samples so a 2-second sampler cannot
/// bury the HTTP requests and crashes around it.
///
/// A run breaks as soon as any non-resource event appears, which keeps the
/// memory baseline anchored to the events it sits between — collapsing across a
/// crash would destroy exactly the before/after reading you want from it.
///
/// This is presentation only: every sample is still an independent record in
/// storage, and a run of one is left as a plain row rather than being wrapped
/// in an expander that reveals nothing.
List<ArgosListEntry> argosBuildListEntries(List<ArgosPacketRecord> records) {
  final entries = <ArgosListEntry>[];
  var i = 0;
  while (i < records.length) {
    if (records[i].kind != ArgosKind.resource) {
      entries.add(ArgosRecordEntry(records[i]));
      i++;
      continue;
    }
    final run = <ArgosPacketRecord>[];
    while (i < records.length && records[i].kind == ArgosKind.resource) {
      run.add(records[i]);
      i++;
    }
    entries.add(
      run.length == 1 ? ArgosRecordEntry(run.first) : ArgosResourceRun(run),
    );
  }
  return entries;
}

abstract class ArgosFormat {
  static String bytes(int b) {
    if (b <= 0) return '0 B';
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1024 * 1024 * 1024) {
      return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  /// `14:03:22`
  static String clock(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${_pad2(dt.hour)}:${_pad2(dt.minute)}:${_pad2(dt.second)}';
  }

  /// `07-13 14:03:22`
  static String dateTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${_pad2(dt.month)}-${_pad2(dt.day)} ${clock(timestamp)}';
  }

  /// Coarse "how fresh is this" label. Deliberately recomputed on rebuild
  /// rather than driven by a timer — a slightly stale label costs nothing,
  /// a permanently-ticking Timer in an inspector overlay does.
  static String relative(int timestamp, {DateTime? now}) {
    final then = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final diff = (now ?? DateTime.now()).difference(then);
    if (diff.isNegative || diff.inSeconds < 5) return '刚刚';
    if (diff.inSeconds < 60) return '${diff.inSeconds} 秒前';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    return '${diff.inDays} 天前';
  }

  /// `2 分钟前 · 14:03:22` — freshness and the exact instant, side by side, so
  /// the reader can both judge recency and line the record up against a log.
  static String relativeAndClock(int timestamp, {DateTime? now}) =>
      '${relative(timestamp, now: now)} · ${clock(timestamp)}';

  static String _pad2(int v) => v.toString().padLeft(2, '0');
}
