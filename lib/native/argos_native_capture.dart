import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:argos/model/argos_http_info_model.dart';
import 'package:argos/storage/argos_packet_storage.dart';

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

  void _onNativeEvent(dynamic event) {
    if (event is! String) return;
    try {
      final map = jsonDecode(event) as Map<String, dynamic>;
      final record = ArgosPacketRecord.fromJson(map);
      ArgosPacketStorage.instance.appendRecord(record);
    } catch (_) {}
  }

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
