import 'package:argos/config/argos_config.dart';
import 'package:argos/model/argos_model.dart';
import 'package:argos/model/argos_http_info_model.dart';

/// A periodic runtime-resource sample (memory, and CPU when available).
class ArgosResourceInfo extends ArgosBaseModel {
  ArgosResourceInfo({
    required this.currentRssBytes,
    required this.maxRssBytes,
    this.cpuPercent,
    this.routeName = '',
  }) : startTimestamp = DateTime.now().millisecondsSinceEpoch;

  /// Current resident set size (bytes).
  final int currentRssBytes;

  /// Peak resident set size (bytes).
  final int maxRssBytes;

  /// Process CPU usage percent. Null when not reliably obtainable in pure Dart;
  /// callers MUST NOT fabricate a value.
  final double? cpuPercent;

  /// Route active at sample time.
  final String routeName;

  final int startTimestamp;

  static String _mb(int bytes) =>
      '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';

  String get summary =>
      'RSS ${_mb(currentRssBytes)} / peak ${_mb(maxRssBytes)}';

  @override
  String getValue() {
    final cpu =
        cpuPercent != null ? ' cpu=${cpuPercent!.toStringAsFixed(1)}%' : '';
    return 'Resource: $summary$cpu';
  }

  /// Serializable snapshot reusing [ArgosPacketRecord] so resource samples can
  /// be persisted via [ArgosPacketStorage] alongside HTTP packets.
  ArgosPacketRecord toPacketRecord() {
    final headers = <String, String>{
      'currentRss': currentRssBytes.toString(),
      'maxRss': maxRssBytes.toString(),
    };
    if (cpuPercent != null) {
      headers['cpuPercent'] = cpuPercent!.toStringAsFixed(2);
    }
    return ArgosPacketRecord(
      id: startTimestamp.toString(),
      uri: summary,
      method: 'RES',
      startTimestamp: startTimestamp,
      endTimestamp: startTimestamp,
      requestHeaders: const {},
      requestBody: '',
      responseCode: 0,
      responseBody: getValue(),
      responseHeaders: headers,
      responseSize: currentRssBytes,
      routeName: routeName,
      kind: 'resource',
    );
  }

  @override
  // ignore: overridden_fields
  ArgosCapability? type = ArgosCapability.resource;
}
