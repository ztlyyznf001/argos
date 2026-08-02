import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:argos_inspector/argos_manager.dart';
import 'package:argos_inspector/config/argos_config.dart';
import 'package:argos_inspector/model/argos_http_info_model.dart';
import 'package:argos_inspector/model/argos_model.dart';

class ArgosNativeCapture {
  ArgosNativeCapture._internal();

  static final ArgosNativeCapture _instance = ArgosNativeCapture._internal();

  static ArgosNativeCapture get instance => _instance;

  static const MethodChannel _methodChannel =
      MethodChannel('dev.panoptes.argos/native_capture_method');
  static const EventChannel _eventChannel =
      EventChannel('dev.panoptes.argos/native_capture');

  bool _enabled = false;
  StreamSubscription<dynamic>? _subscription;

  /// Enables native packet capture on iOS and Android.
  /// Idempotent — safe to call multiple times.
  Future<void> enable() async {
    if (_enabled) return;
    _enabled = true;

    _subscription = _eventChannel.receiveBroadcastStream().listen(
          _onNativeEvent,
          onError: (_) {},
          cancelOnError: false,
        );

    try {
      await _methodChannel.invokeMethod<void>('enable');
    } catch (_) {}
  }

  Future<void> _onNativeEvent(dynamic event) {
    if (event is! String) return Future<void>.value();
    try {
      final map = jsonDecode(event) as Map<String, dynamic>;
      final record = ArgosPacketRecord.fromJson(map);
      return ArgosManager.instance.dispatch(
        _ArgosNativeNetworkInfo(record),
        record: record,
      );
    } catch (_) {
      return Future<void>.value();
    }
  }

  @visibleForTesting
  Future<void> handleEventForTesting(dynamic event) => _onNativeEvent(event);

  Future<void> disable() async {
    if (!_enabled) return;
    _enabled = false;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _methodChannel.invokeMethod<void>('disable');
    } catch (_) {}
  }
}

class _ArgosNativeNetworkInfo extends ArgosBaseModel {
  _ArgosNativeNetworkInfo(this.record) {
    type = ArgosCapability.network;
  }

  final ArgosPacketRecord record;

  @override
  String getValue() => '${record.method} ${record.uri}';
}
