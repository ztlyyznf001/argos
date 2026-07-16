import 'package:argos_inspector/config/argos_config.dart';
import 'package:argos_inspector/model/argos_model.dart';
import 'package:argos_inspector/model/argos_http_info_model.dart';

/// A captured Flutter framework error or unhandled Dart exception.
class ArgosCrashInfo extends ArgosBaseModel {
  ArgosCrashInfo({
    required this.message,
    this.stack,
    this.routeName = '',
    this.library,
  }) : startTimestamp = DateTime.now().millisecondsSinceEpoch;

  /// Exception message / `exceptionAsString`.
  final String message;

  /// Stack trace string (may be null for some framework errors).
  final String? stack;

  /// Route in which the error occurred.
  final String routeName;

  /// Optional Flutter library context (e.g. "widgets library").
  final String? library;

  final int startTimestamp;

  /// First non-empty line of the message, used as a short summary.
  String get summary {
    final firstLine = message.split('\n').firstWhere(
          (l) => l.trim().isNotEmpty,
          orElse: () => message,
        );
    return firstLine.trim();
  }

  @override
  String getValue() {
    final buffer = StringBuffer('Crash: $summary');
    if (library != null && library!.isNotEmpty) {
      buffer.write('\nLibrary: $library');
    }
    if (stack != null && stack!.isNotEmpty) {
      buffer.write('\n$stack');
    }
    return buffer.toString();
  }

  /// Serializable snapshot reusing [ArgosPacketRecord] so crash events can be
  /// persisted via [ArgosPacketStorage] alongside HTTP packets.
  ArgosPacketRecord toPacketRecord() {
    return ArgosPacketRecord(
      id: startTimestamp.toString(),
      uri: summary,
      method: 'CRASH',
      startTimestamp: startTimestamp,
      endTimestamp: startTimestamp,
      requestHeaders: const {},
      requestBody: '',
      responseCode: 0,
      responseBody: stack ?? '',
      responseHeaders: library != null ? {'library': library!} : const {},
      responseSize: 0,
      error: message,
      routeName: routeName,
      kind: 'crash',
    );
  }

  @override
  // ignore: overridden_fields
  ArgosCapability? type = ArgosCapability.crash;
}
