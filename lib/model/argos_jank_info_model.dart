import 'package:argos_inspector/config/argos_config.dart';
import 'package:argos_inspector/model/argos_model.dart';
import 'package:argos_inspector/model/argos_http_info_model.dart';

/// A jank (stutter) interval aggregated from one or more consecutive dropped
/// frames detected via [FrameTiming].
class ArgosJankInfo extends ArgosBaseModel {
  ArgosJankInfo({
    required this.droppedFrames,
    required this.totalDurationMs,
    required this.maxFrameMs,
    required this.buildMs,
    required this.rasterMs,
    this.routeName = '',
  }) : startTimestamp = DateTime.now().millisecondsSinceEpoch;

  /// Number of frames in this jank interval that exceeded the frame budget.
  final int droppedFrames;

  /// Total span of the jank interval in milliseconds.
  final double totalDurationMs;

  /// Longest single frame in the interval, in milliseconds.
  final double maxFrameMs;

  /// Accumulated UI-thread (build) time across the interval, in milliseconds.
  final double buildMs;

  /// Accumulated raster-thread time across the interval, in milliseconds.
  final double rasterMs;

  /// Route in which the jank occurred.
  final String routeName;

  final int startTimestamp;

  String get summary =>
      '丢帧 $droppedFrames，最大 ${maxFrameMs.toStringAsFixed(1)} ms';

  @override
  String getValue() {
    return 'Jank: $summary\n'
        'total=${totalDurationMs.toStringAsFixed(1)}ms '
        'build=${buildMs.toStringAsFixed(1)}ms '
        'raster=${rasterMs.toStringAsFixed(1)}ms';
  }

  /// Serializable snapshot reusing [ArgosPacketRecord] so jank events can be
  /// persisted via [ArgosPacketStorage] alongside HTTP packets.
  ArgosPacketRecord toPacketRecord() {
    return ArgosPacketRecord(
      id: startTimestamp.toString(),
      uri: summary,
      method: 'JANK',
      startTimestamp: startTimestamp,
      endTimestamp: startTimestamp + totalDurationMs.round(),
      requestHeaders: const {},
      requestBody: '',
      responseCode: droppedFrames,
      responseBody: 'build=${buildMs.toStringAsFixed(1)}ms\n'
          'raster=${rasterMs.toStringAsFixed(1)}ms\n'
          'maxFrame=${maxFrameMs.toStringAsFixed(1)}ms\n'
          'total=${totalDurationMs.toStringAsFixed(1)}ms\n'
          'droppedFrames=$droppedFrames',
      responseHeaders: const {},
      responseSize: 0,
      routeName: routeName,
      kind: 'jank',
    );
  }

  @override
  // ignore: overridden_fields
  ArgosCapability? type = ArgosCapability.jank;
}
