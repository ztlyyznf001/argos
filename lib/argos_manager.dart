// You have generated a new plugin project without
// specifying the `--platforms` flag. A plugin project supports no platforms is generated.
// To add platforms, run `flutter create -t plugin --platforms <platforms> .` under the same
// directory. You can also find a detailed instruction on how to add platforms in the `pubspec.yaml` at https://flutter.dev/docs/development/packages-and-plugins/developing-packages#plugin-platforms.

import 'package:flutter/widgets.dart';

import 'package:argos/apm/argos_fps_monitor.dart';
import 'package:argos/apm/argos_http_monitor.dart';
import 'package:argos/apm/argos_crash_monitor.dart';
import 'package:argos/apm/argos_jank_monitor.dart';
import 'package:argos/apm/argos_resource_monitor.dart';
import 'package:argos/config/argos_config.dart';
import 'package:argos/model/argos_model.dart';
import 'package:argos/model/argos_http_info_model.dart';
import 'package:argos/storage/argos_packet_storage.dart';

class ArgosManager {
  Function(ArgosBaseModel?)? listener;

  ArgosConfig? config;

  String currentRoute = '';

  bool captureEnabled = false;
  ArgosManager._internal();

  static late final ArgosManager _instance = ArgosManager._internal();

  static ArgosManager get instance => _instance;

  _ArgosLifecycleObserver? _lifecycleObserver;

  ArgosManager init({
    ArgosConfig? config,
    Function(ArgosBaseModel?)? listener,
  }) {
    this.config = config;
    this.listener = listener;
    captureEnabled = config?.enableStorage ?? false;
    ArgosPacketStorage.instance.persistInterval =
        config?.storagePersistInterval ?? const Duration(seconds: 5);
    _registerLifecycleObserver();
    initializeMonitors();
    return this;
  }

  /// Flush any coalesced writes when the app is backgrounded — the OS is most
  /// likely to kill the process after this, so it bounds the crash-loss window.
  void _registerLifecycleObserver() {
    if (_lifecycleObserver != null) return; // init may be called more than once
    final binding = WidgetsBinding.instance;
    _lifecycleObserver = _ArgosLifecycleObserver();
    binding.addObserver(_lifecycleObserver!);
  }

  void initializeMonitors() {
    config?.apmTypes?.forEach((element) {
      switch (element) {
        case ArgosCapability.fps:
          ArgosFpsMonitor.instance.init();
          break;
        case ArgosCapability.network:
          ArgosHttpMonitor.instance.init();
          ArgosHttpMonitor.instance.proxyProvider = config?.proxyProvider;
          ArgosPacketStorage.instance.setAdapter(config?.storageAdapter);
          break;
        case ArgosCapability.crash:
          ArgosPacketStorage.instance.setAdapter(config?.storageAdapter);
          ArgosCrashMonitor.instance.init(config: config);
          break;
        case ArgosCapability.jank:
          ArgosPacketStorage.instance.setAdapter(config?.storageAdapter);
          ArgosJankMonitor.instance.init(config: config);
          break;
        case ArgosCapability.resource:
          ArgosPacketStorage.instance.setAdapter(config?.storageAdapter);
          ArgosResourceMonitor.instance.init(config: config);
          break;
        default:
      }
    });
  }

  void updateProxyProvider(String? Function() provider) {
    ArgosHttpMonitor.instance.proxyProvider = provider;
  }

  /// Shared dispatch path for monitor events: always notifies [listener], and
  /// persists [record] to [ArgosPacketStorage] when storage is enabled.
  void dispatch(ArgosBaseModel model, {ArgosPacketRecord? record}) {
    if (listener != null) {
      listener!(model);
    }
    if ((config?.enableStorage ?? false) && record != null) {
      ArgosPacketStorage.instance.appendRecord(
        record,
        maxRecords: config?.maxPacketRecords ?? 200,
        resourceMaxRecords: config?.resourceMaxRecords ?? 50,
      );
    }
  }
}

class _ArgosLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ArgosPacketStorage.instance.flush();
    }
  }
}
