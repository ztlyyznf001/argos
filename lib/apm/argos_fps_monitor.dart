import 'dart:collection';
import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:argos/apm/argos_base_monitor.dart';
import 'package:argos/config/argos_config.dart';
import 'package:argos/argos_manager.dart';
import 'package:argos/model/argos_model.dart';
import 'package:argos/model/argos_fps_info_model.dart';

class ArgosFpsMonitor implements ArgosBaseMonitor {
  ArgosFpsMonitor._internal();

  ArgosConfig? config;

  static late final ArgosFpsMonitor _instance = ArgosFpsMonitor._internal();

  static ArgosFpsMonitor get instance => _instance;

  static const maxFrames = 120;

  static const frameInterval =
      Duration(microseconds: Duration.microsecondsPerSecond ~/ 60);

  final _lastFrames = ListQueue<FrameTiming>(maxFrames);

  @override
  ArgosFpsMonitor init({
    ArgosConfig? config,
  }) {
    SchedulerBinding.instance.addTimingsCallback(_onReportTimings);
    return this;
  }

  void _onReportTimings(List<FrameTiming> timings) {
    for (FrameTiming timing in timings) {
      _lastFrames.addFirst(timing);
    }

    while (_lastFrames.length >= maxFrames) {
      _lastFrames.removeLast();
    }

    ArgosFpsInfo infoModel = ArgosFpsInfo(fps);

    if (ArgosManager.instance.listener != null) {
      ArgosManager.instance.listener!(infoModel);
    }
  }

  double get fps {
    var lastFramesSet = <FrameTiming>[];
    for (FrameTiming timing in _lastFrames) {
      if (lastFramesSet.isEmpty) {
        lastFramesSet.add(timing);
      } else {
        var lastStart =
            lastFramesSet.last.timestampInMicroseconds(FramePhase.buildStart);
        if (lastStart -
                timing.timestampInMicroseconds(FramePhase.rasterFinish) >
            (frameInterval.inMicroseconds * 2)) {
          // in different set
          break;
        }
        lastFramesSet.add(timing);
      }
    }
    final frameCount = lastFramesSet.length;
    var costCount = lastFramesSet.map((t) {
      return (t.totalSpan.inMicroseconds ~/ frameInterval.inMicroseconds) + 1;
    }).fold(0, (previousValue, element) {
      return (int.tryParse(previousValue.toString()) ?? 0) +
          (int.tryParse(element.toString()) ?? 0);
    });
    return frameCount * 60 / costCount;
  }

  @override
  void onReport(ArgosBaseModel model) {}
}
