// You have generated a new plugin project without
// specifying the `--platforms` flag. A plugin project supports no platforms is generated.
// To add platforms, run `flutter create -t plugin --platforms <platforms> .` under the same
// directory. You can also find a detailed instruction on how to add platforms in the `pubspec.yaml` at https://flutter.dev/docs/development/packages-and-plugins/developing-packages#plugin-platforms.

import 'package:argos/apm/argos_fps_monitor.dart';
import 'package:argos/apm/argos_http_monitor.dart';
import 'package:argos/config/argos_config.dart';
import 'package:argos/model/argos_model.dart';
import 'package:argos/storage/argos_packet_storage.dart';

class ArgosManager {
  Function(ArgosBaseModel?)? listener;

  ArgosConfig? config;

  String currentRoute = '';

  bool captureEnabled = false;
  ArgosManager._internal();

  static late final ArgosManager _instance = ArgosManager._internal();

  static ArgosManager get instance => _instance;

  ArgosManager init({
    ArgosConfig? config,
    Function(ArgosBaseModel?)? listener,
  }) {
    this.config = config;
    this.listener = listener;
    captureEnabled = config?.enableStorage ?? false;
    initializeMonitors();
    return this;
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
        default:
      }
    });
  }

  void updateProxyProvider(String? Function() provider) {
    ArgosHttpMonitor.instance.proxyProvider = provider;
  }
}
