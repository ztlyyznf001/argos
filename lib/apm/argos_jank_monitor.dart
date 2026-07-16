import 'dart:ui';

import 'package:flutter/scheduler.dart';

import 'package:argos/apm/argos_base_monitor.dart';
import 'package:argos/config/argos_config.dart';
import 'package:argos/argos_manager.dart';
import 'package:argos/model/argos_model.dart';
import 'package:argos/model/argos_jank_info_model.dart';

/// Detects dropped frames via [FrameTiming], splits build/raster time, and
/// aggregates consecutive dropped frames into a single jank-interval event,
/// routing it into the unified Argos data flow.
class ArgosJankMonitor implements ArgosBaseMonitor {
  ArgosJankMonitor._internal();

  static late final ArgosJankMonitor _instance = ArgosJankMonitor._internal();

  static ArgosJankMonitor get instance => _instance;

  ArgosConfig? config;

  bool _installed = false;

  // Accumulator for the in-progress jank interval (consecutive dropped frames).
  int _droppedFrames = 0;
  double _totalMs = 0;
  double _maxFrameMs = 0;
  double _buildMs = 0;
  double _rasterMs = 0;

  @override
  ArgosJankMonitor init({ArgosConfig? config}) {
    this.config = config;
    if (_installed) return this;
    _installed = true;
    SchedulerBinding.instance.addTimingsCallback(_onReportTimings);
    return this;
  }

  /// Frame budget in milliseconds = 1000 / refreshRate. Prefers the display's
  /// reported refresh rate, falling back to 60Hz when unavailable.
  double get _frameBudgetMs {
    double refreshRate = 60;
    try {
      final views = PlatformDispatcher.instance.views;
      if (views.isNotEmpty) {
        final rate = views.first.display.refreshRate;
        if (rate > 0) refreshRate = rate;
      }
    } catch (_) {
      // Display info unavailable; keep the 60Hz fallback.
    }
    return 1000 / refreshRate;
  }

  void _onReportTimings(List<FrameTiming> timings) {
    final budgetMs = _frameBudgetMs;
    final threshold = budgetMs * (config?.jankThresholdMultiplier ?? 1.0);

    for (final timing in timings) {
      final totalMs = timing.totalSpan.inMicroseconds / 1000.0;
      if (totalMs > threshold) {
        // Dropped frame: accumulate into the current jank interval.
        _droppedFrames += 1;
        _totalMs += totalMs;
        if (totalMs > _maxFrameMs) _maxFrameMs = totalMs;
        _buildMs += timing.buildDuration.inMicroseconds / 1000.0;
        _rasterMs += timing.rasterDuration.inMicroseconds / 1000.0;
      } else {
        // Good frame ends the current interval (if any).
        _flush();
      }
    }
    // Flush any interval still open at the end of this batch.
    _flush();
  }

  void _flush() {
    if (_droppedFrames == 0) return;

    final info = ArgosJankInfo(
      droppedFrames: _droppedFrames,
      totalDurationMs: _totalMs,
      maxFrameMs: _maxFrameMs,
      buildMs: _buildMs,
      rasterMs: _rasterMs,
      routeName: ArgosManager.instance.currentRoute,
    );
    ArgosManager.instance.dispatch(info, record: info.toPacketRecord());

    _droppedFrames = 0;
    _totalMs = 0;
    _maxFrameMs = 0;
    _buildMs = 0;
    _rasterMs = 0;
  }

  @override
  void onReport(ArgosBaseModel model) {}
}
