import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'package:argos_inspector/apm/argos_base_monitor.dart';
import 'package:argos_inspector/config/argos_config.dart';
import 'package:argos_inspector/argos_manager.dart';
import 'package:argos_inspector/model/argos_model.dart';
import 'package:argos_inspector/model/argos_crash_info_model.dart';

/// Captures Flutter framework errors ([FlutterError.onError]) and unhandled
/// Dart asynchronous exceptions ([PlatformDispatcher.onError]), routing them
/// into the unified Argos data flow.
class ArgosCrashMonitor implements ArgosBaseMonitor {
  ArgosCrashMonitor._internal();

  static late final ArgosCrashMonitor _instance = ArgosCrashMonitor._internal();

  static ArgosCrashMonitor get instance => _instance;

  ArgosConfig? config;

  bool _installed = false;

  /// Previous handlers preserved for chaining, so the host app's existing
  /// error reporting is not swallowed.
  FlutterExceptionHandler? _previousFlutterOnError;
  ErrorCallback? _previousPlatformOnError;

  // Dedup state: identical (message + first stack frame) within a short window
  // collapses into a single record (the two channels can both fire).
  String? _lastKey;
  int _lastKeyTimeMs = 0;
  static const int _dedupWindowMs = 500;

  @override
  ArgosCrashMonitor init({ArgosConfig? config}) {
    this.config = config;
    if (_installed) return this;
    _installed = true;

    _previousFlutterOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      unawaited(_recordFlutterError(details));
      // Chain to whatever the host had configured (defaults to dumpErrorToConsole).
      _previousFlutterOnError?.call(details);
    };

    _previousPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      unawaited(_record(error.toString(), stack.toString(), null));
      // Preserve previous handling; return false so the platform still reports
      // it when no prior handler claimed it.
      return _previousPlatformOnError?.call(error, stack) ?? false;
    };

    return this;
  }

  Future<void> _recordFlutterError(FlutterErrorDetails details) {
    final message = details.exceptionAsString();
    final stack = details.stack?.toString();
    final library = details.library;
    return _record(message, stack, library);
  }

  Future<void> _record(String message, String? stack, String? library) {
    final key = '$message|${_firstStackLine(stack)}';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (key == _lastKey && (nowMs - _lastKeyTimeMs) < _dedupWindowMs) {
      return Future<void>.value();
    }
    _lastKey = key;
    _lastKeyTimeMs = nowMs;

    final info = ArgosCrashInfo(
      message: message,
      stack: stack,
      library: library,
      routeName: ArgosManager.instance.currentRoute,
    );
    final manager = ArgosManager.instance;
    final shouldFlush =
        manager.captureEnabled && (manager.config?.enableStorage ?? false);
    final append = manager.dispatch(info, record: info.toPacketRecord());
    if (shouldFlush) {
      return _flushAfterAppend(append);
    }
    return append;
  }

  Future<void> _flushAfterAppend(Future<void> append) async {
    try {
      await append;
      await ArgosManager.instance.flush();
    } catch (error) {
      debugPrint('ArgosCrashMonitor flush error: $error');
    }
  }

  String _firstStackLine(String? stack) {
    if (stack == null || stack.isEmpty) return '';
    return stack.split('\n').firstWhere(
          (l) => l.trim().isNotEmpty,
          orElse: () => '',
        );
  }

  @override
  void onReport(ArgosBaseModel model) {}

  @visibleForTesting
  Future<void> recordForTesting(
    String message, {
    String? stack,
    String? library,
  }) =>
      _record(message, stack, library);

  @visibleForTesting
  void resetForTesting() {
    if (_installed) {
      FlutterError.onError = _previousFlutterOnError;
      PlatformDispatcher.instance.onError = _previousPlatformOnError;
    }
    _installed = false;
    _previousFlutterOnError = null;
    _previousPlatformOnError = null;
    _lastKey = null;
    _lastKeyTimeMs = 0;
    config = null;
  }
}
