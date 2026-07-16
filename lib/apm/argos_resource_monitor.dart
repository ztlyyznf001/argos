import 'dart:async';
import 'dart:io';

import 'package:argos_inspector/apm/argos_base_monitor.dart';
import 'package:argos_inspector/config/argos_config.dart';
import 'package:argos_inspector/argos_manager.dart';
import 'package:argos_inspector/model/argos_model.dart';
import 'package:argos_inspector/model/argos_resource_info_model.dart';

/// Periodically samples process memory (`ProcessInfo.currentRss` / `maxRss`)
/// and emits resource-sample events into the unified Argos data flow. CPU is
/// left empty when not reliably obtainable in pure Dart.
class ArgosResourceMonitor implements ArgosBaseMonitor {
  ArgosResourceMonitor._internal();

  static late final ArgosResourceMonitor _instance =
      ArgosResourceMonitor._internal();

  static ArgosResourceMonitor get instance => _instance;

  ArgosConfig? config;

  Timer? _timer;

  @override
  ArgosResourceMonitor init({ArgosConfig? config}) {
    this.config = config;
    final interval =
        config?.resourceSampleInterval ?? const Duration(seconds: 2);
    // Avoid stacking timers if init() is called more than once.
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _sample());
    return this;
  }

  void _sample() {
    final info = ArgosResourceInfo(
      currentRssBytes: ProcessInfo.currentRss,
      maxRssBytes: ProcessInfo.maxRss,
      // CPU is intentionally left null: pure Dart has no reliable cross-platform
      // process CPU API, and fabricating a value would mislead.
      cpuPercent: null,
      routeName: ArgosManager.instance.currentRoute,
    );
    ArgosManager.instance.dispatch(info, record: info.toPacketRecord());
  }

  /// Stops periodic sampling and releases the timer, preventing leaks and
  /// background sampling once the monitor is disabled.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void onReport(ArgosBaseModel model) {}
}
