import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';

import 'package:argos_inspector/apm/argos_crash_monitor.dart';
import 'package:argos_inspector/apm/argos_fps_monitor.dart';
import 'package:argos_inspector/apm/argos_http_monitor.dart';
import 'package:argos_inspector/apm/argos_jank_monitor.dart';
import 'package:argos_inspector/apm/argos_resource_monitor.dart';
import 'package:argos_inspector/config/argos_config.dart';
import 'package:argos_inspector/model/argos_diagnostic_session.dart';
import 'package:argos_inspector/model/argos_http_info_model.dart';
import 'package:argos_inspector/model/argos_model.dart';
import 'package:argos_inspector/storage/argos_packet_storage.dart';

class ArgosManager {
  ArgosManager._internal() {
    ArgosPacketStorage.instance.onCleared = _handleStorageCleared;
  }

  static final ArgosManager _instance = ArgosManager._internal();

  static ArgosManager get instance => _instance;

  Function(ArgosBaseModel?)? listener;
  ArgosConfig? config;
  String currentRoute = '';

  ArgosDiagnosticSession? _activeSession;
  ArgosSessionState _sessionState = ArgosSessionState.idle;
  bool _activeSessionIsAutomatic = false;
  ArgosAutomaticSessionPolicy? _activeAutomaticPolicy;
  ArgosSessionContext? _automaticContext;
  int? _maxDurationDeadlineAt;
  int? _explicitPauseStartedAt;
  int? _backgroundedAt;
  int _nextSequence = 0;
  int _sessionCounter = 0;
  bool _initialized = false;
  _ArgosLifecycleObserver? _lifecycleObserver;
  DateTime Function() _now = DateTime.now;

  ArgosDiagnosticSession? get activeSession => _activeSession;

  ArgosSessionState get sessionState => _sessionState;

  /// Compatibility view over the diagnostic-session state machine.
  bool get captureEnabled => _sessionState == ArgosSessionState.recording;

  set captureEnabled(bool enabled) {
    if (enabled) {
      if (_sessionState == ArgosSessionState.paused) {
        resumeSession();
      } else if (_sessionState == ArgosSessionState.idle) {
        startSession();
      }
    } else if (_sessionState == ArgosSessionState.recording) {
      pauseSession();
    }
  }

  ArgosManager init({
    ArgosConfig? config,
    Function(ArgosBaseModel?)? listener,
  }) {
    final isFirstInit = !_initialized;
    final effectiveConfig = config ?? ArgosConfig();
    this.config = effectiveConfig;
    this.listener = listener;
    _initialized = true;

    final storage = ArgosPacketStorage.instance;
    storage.onCleared = _handleStorageCleared;
    storage.persistInterval = effectiveConfig.storagePersistInterval;
    storage.setAdapter(effectiveConfig.storageAdapter);
    // Queue recovery before an automatic begin. Neither operation needs to
    // block the synchronous public init API.
    unawaited(storage.hydrate());

    _registerLifecycleObserver();
    if (isFirstInit &&
        _activeSession == null &&
        effectiveConfig.sessionMode == ArgosSessionMode.automatic &&
        effectiveConfig.enableStorage) {
      _startNewSession(
        now: _now(),
        automaticManaged: true,
        automaticPolicy: effectiveConfig.automaticSessionPolicy,
      );
    }
    initializeMonitors();
    return this;
  }

  ArgosDiagnosticSession startSession({
    String? label,
    String? note,
    Map<String, String> attributes = const <String, String>{},
  }) {
    if (_sessionState == ArgosSessionState.recording) {
      return _activeSession!;
    }
    if (_sessionState == ArgosSessionState.paused) {
      resumeSession();
      return _activeSession!;
    }

    return _startNewSession(
      now: _now(),
      automaticManaged: false,
      label: label,
      note: note,
      attributes: attributes,
    );
  }

  ArgosDiagnosticSession _startNewSession({
    required DateTime now,
    required bool automaticManaged,
    ArgosAutomaticSessionPolicy? automaticPolicy,
    String? label,
    String? note,
    Map<String, String> attributes = const <String, String>{},
  }) {
    final policy = automaticManaged
        ? automaticPolicy ?? const ArgosAutomaticSessionPolicy.process()
        : null;
    final context = automaticManaged
        ? _sampleAutomaticContext(policy!, fallback: null)
        : null;
    final session = ArgosDiagnosticSession(
      id: _newSessionId(now),
      startedAt: now.millisecondsSinceEpoch,
      label: label,
      note: note,
      attributes: Map<String, String>.unmodifiable(
        automaticManaged
            ? context?.attributes ?? const <String, String>{}
            : attributes,
      ),
    );
    _activateSession(
      session,
      automaticManaged: automaticManaged,
      automaticPolicy: policy,
      context: context,
    );
    if (config?.enableStorage ?? false) {
      unawaited(
        ArgosPacketStorage.instance.beginSession(
          session,
          maxSessions: config?.maxSessions ?? 5,
        ),
      );
    }
    return session;
  }

  void pauseSession() {
    final session = _activeSession;
    if (_sessionState != ArgosSessionState.recording || session == null) return;
    _sessionState = ArgosSessionState.paused;
    _backgroundedAt = null;
    if (_isAdaptiveAutomaticSession && _maxDurationDeadlineAt != null) {
      _explicitPauseStartedAt = _nowMilliseconds;
    }
    if (config?.enableStorage ?? false) {
      unawaited(ArgosPacketStorage.instance.pauseSession(session.id));
    }
  }

  void resumeSession() {
    final session = _activeSession;
    if (_sessionState != ArgosSessionState.paused || session == null) return;
    final now = _nowMilliseconds;
    final pauseStartedAt = _explicitPauseStartedAt;
    final deadline = _maxDurationDeadlineAt;
    if (_isAdaptiveAutomaticSession &&
        pauseStartedAt != null &&
        deadline != null) {
      final pausedFor = now - pauseStartedAt;
      if (pausedFor > 0) _maxDurationDeadlineAt = deadline + pausedFor;
    }
    _explicitPauseStartedAt = null;
    _backgroundedAt = null;
    _sessionState = ArgosSessionState.recording;
    if (config?.enableStorage ?? false) {
      unawaited(ArgosPacketStorage.instance.resumeSession(session.id));
    }
  }

  Future<ArgosDiagnosticSession?> stopSession() async {
    final session = _activeSession;
    if (session == null) return null;
    final endedAt = _latestTimestamp(
      _nowMilliseconds,
      session.startedAt,
      session.lastEventAt,
    );
    final completed = session.copyWith(
      endedAt: endedAt,
      endReason: ArgosSessionEndReason.completed,
    );
    _clearActiveSession();
    if (config?.enableStorage ?? false) {
      await ArgosPacketStorage.instance.completeSession(
        completed,
        maxSessions: config?.maxSessions ?? 5,
      );
      await ArgosPacketStorage.instance.flush();
    }
    return completed;
  }

  Future<void> flush() => ArgosPacketStorage.instance.flush();

  Future<void> clear() => ArgosPacketStorage.instance.clear();

  Future<List<ArgosDiagnosticSession>> getSessions() =>
      ArgosPacketStorage.instance.getSessions();

  Future<List<ArgosPacketRecord>> getSessionRecords(String sessionId) =>
      ArgosPacketStorage.instance.getRecordsForSession(sessionId);

  /// The single admission and metadata-allocation point for persistable events.
  /// Rejected events return immediately without notifying, writing, or
  /// consuming a sequence number.
  Future<void> dispatch(
    ArgosBaseModel model, {
    ArgosPacketRecord? record,
  }) {
    if (_sessionState != ArgosSessionState.recording ||
        _activeSession == null) {
      return Future<void>.value();
    }

    final now = _nowMilliseconds;
    _applyAdaptivePolicyBeforeDispatch(now);
    final session = _activeSession;
    if (_sessionState != ArgosSessionState.recording || session == null) {
      return Future<void>.value();
    }

    final sequence = ++_nextSequence;
    final metadata = ArgosEventMetadata(
      id: '${session.id}:$sequence',
      sessionId: session.id,
      sequence: sequence,
    );
    model.eventMetadata = metadata;
    final eventAt = record == null
        ? now
        : (record.endTimestamp > 0
            ? record.endTimestamp
            : record.startTimestamp);
    _activeSession = session.copyWith(lastEventAt: eventAt);

    try {
      listener?.call(model);
    } catch (error, stackTrace) {
      debugPrint('ArgosManager listener error: $error\n$stackTrace');
    }

    if (!(config?.enableStorage ?? false) || record == null) {
      return Future<void>.value();
    }
    final assignedRecord = record.copyWith(
      id: metadata.id,
      sessionId: metadata.sessionId,
      sequence: metadata.sequence,
      routeName: currentRoute,
    );
    return ArgosPacketStorage.instance.appendRecord(
      assignedRecord,
      maxRecords: config?.maxPacketRecords ?? 200,
      resourceMaxRecords: config?.resourceMaxRecords ?? 50,
      maxSessions: config?.maxSessions ?? 5,
    );
  }

  void initializeMonitors() {
    config?.apmTypes?.forEach((capability) {
      switch (capability) {
        case ArgosCapability.fps:
          ArgosFpsMonitor.instance.init(config: config);
          break;
        case ArgosCapability.network:
          ArgosHttpMonitor.instance.init(config: config);
          ArgosHttpMonitor.instance.proxyProvider = config?.proxyProvider;
          break;
        case ArgosCapability.crash:
          ArgosCrashMonitor.instance.init(config: config);
          break;
        case ArgosCapability.jank:
          ArgosJankMonitor.instance.init(config: config);
          break;
        case ArgosCapability.resource:
          ArgosResourceMonitor.instance.init(config: config);
          break;
      }
    });
  }

  void updateProxyProvider(String? Function() provider) {
    ArgosHttpMonitor.instance.proxyProvider = provider;
  }

  void _registerLifecycleObserver() {
    if (_lifecycleObserver != null) return;
    _lifecycleObserver = _ArgosLifecycleObserver();
    WidgetsBinding.instance.addObserver(_lifecycleObserver!);
  }

  void _activateSession(
    ArgosDiagnosticSession session, {
    required bool automaticManaged,
    ArgosAutomaticSessionPolicy? automaticPolicy,
    ArgosSessionContext? context,
  }) {
    _activeSession = session;
    _sessionState = ArgosSessionState.recording;
    _nextSequence = 0;
    _activeSessionIsAutomatic = automaticManaged;
    _activeAutomaticPolicy = automaticManaged ? automaticPolicy : null;
    _automaticContext = automaticManaged ? context : null;
    _maxDurationDeadlineAt = automaticManaged
        ? _deadlineFor(session.startedAt, automaticPolicy?.maxDuration)
        : null;
    _explicitPauseStartedAt = null;
    _backgroundedAt = null;
  }

  bool get _isAdaptiveAutomaticSession =>
      _activeSessionIsAutomatic &&
      _activeAutomaticPolicy?.strategy ==
          ArgosAutomaticSessionStrategy.adaptive;

  int get _nowMilliseconds => _now().millisecondsSinceEpoch;

  int? _deadlineFor(int startedAt, Duration? duration) {
    if (duration == null) return null;
    return startedAt + duration.inMilliseconds;
  }

  ArgosSessionContext? _sampleAutomaticContext(
    ArgosAutomaticSessionPolicy policy, {
    required ArgosSessionContext? fallback,
  }) {
    final provider = policy.contextProvider;
    if (provider == null) return null;
    try {
      final context = provider();
      if (context.fingerprint.isEmpty) {
        debugPrint('Argos automatic session context has an empty fingerprint');
        return fallback;
      }
      return context;
    } catch (error, stackTrace) {
      debugPrint(
        'Argos automatic session context provider error: '
        '$error\n$stackTrace',
      );
      return fallback;
    }
  }

  void _applyAdaptivePolicyBeforeDispatch(int now) {
    if (!_isAdaptiveAutomaticSession ||
        _sessionState != ArgosSessionState.recording ||
        _activeSession == null) {
      return;
    }
    final policy = _activeAutomaticPolicy!;
    final sampledContext = _sampleAutomaticContext(
      policy,
      fallback: _automaticContext,
    );
    if (policy.contextProvider != null &&
        sampledContext != null &&
        sampledContext.fingerprint != _automaticContext?.fingerprint) {
      _rollAutomaticSession(
        reason: ArgosSessionEndReason.contextChanged,
        oldEndedAt: now,
        newStartedAt: now,
        nextContext: sampledContext,
      );
      return;
    }

    final deadline = _maxDurationDeadlineAt;
    if (deadline != null && now >= deadline) {
      _rollAutomaticSession(
        reason: ArgosSessionEndReason.maxDuration,
        oldEndedAt: deadline,
        newStartedAt: now,
        nextContext: sampledContext,
      );
    }
  }

  void _rollAutomaticSession({
    required ArgosSessionEndReason reason,
    required int oldEndedAt,
    required int newStartedAt,
    required ArgosSessionContext? nextContext,
  }) {
    final oldSession = _activeSession;
    final policy = _activeAutomaticPolicy;
    if (oldSession == null ||
        !_isAdaptiveAutomaticSession ||
        policy == null ||
        _sessionState != ArgosSessionState.recording) {
      return;
    }

    final completed = oldSession.copyWith(
      endedAt: _latestTimestamp(
        oldEndedAt,
        oldSession.startedAt,
        oldSession.lastEventAt,
      ),
      endReason: reason,
    );
    final startedAt = _latestTimestamp(newStartedAt, completed.endedAt!);
    final nextSession = ArgosDiagnosticSession(
      id: _newSessionId(
        DateTime.fromMillisecondsSinceEpoch(startedAt),
      ),
      startedAt: startedAt,
      attributes: Map<String, String>.unmodifiable(
        nextContext?.attributes ?? const <String, String>{},
      ),
    );
    _activateSession(
      nextSession,
      automaticManaged: true,
      automaticPolicy: policy,
      context: nextContext,
    );

    if (config?.enableStorage ?? false) {
      final storage = ArgosPacketStorage.instance;
      unawaited(
        storage.completeSession(
          completed,
          maxSessions: config?.maxSessions ?? 5,
        ),
      );
      unawaited(
        storage.beginSession(
          nextSession,
          maxSessions: config?.maxSessions ?? 5,
        ),
      );
    }
  }

  int _latestTimestamp(int first, int second, [int? third]) {
    var latest = first > second ? first : second;
    if (third != null && third > latest) latest = third;
    return latest;
  }

  void _handleAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (_isAdaptiveAutomaticSession &&
          _sessionState == ArgosSessionState.recording &&
          _backgroundedAt == null) {
        _backgroundedAt = _nowMilliseconds;
      } else if (!_isAdaptiveAutomaticSession ||
          _sessionState != ArgosSessionState.recording) {
        _backgroundedAt = null;
      }
      unawaited(flush());
      return;
    }
    if (state != AppLifecycleState.resumed) return;

    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (backgroundedAt == null ||
        !_isAdaptiveAutomaticSession ||
        _sessionState != ArgosSessionState.recording ||
        _activeSession == null) {
      return;
    }
    final policy = _activeAutomaticPolicy!;
    final timeout = policy.backgroundTimeout;
    if (timeout == null) return;
    final now = _nowMilliseconds;
    final elapsed = now - backgroundedAt;
    if ((elapsed < 0 ? 0 : elapsed) < timeout.inMilliseconds) return;

    final nextContext = _sampleAutomaticContext(
      policy,
      fallback: _automaticContext,
    );
    _rollAutomaticSession(
      reason: ArgosSessionEndReason.backgroundTimeout,
      oldEndedAt: backgroundedAt + timeout.inMilliseconds,
      newStartedAt: now,
      nextContext: nextContext,
    );
  }

  String _newSessionId(DateTime now) {
    _sessionCounter++;
    var randomPart = 0;
    try {
      randomPart = Random.secure().nextInt(1 << 30);
    } catch (_) {
      randomPart = Random().nextInt(1 << 30);
    }
    return '${now.microsecondsSinceEpoch.toRadixString(36)}-'
        '${_sessionCounter.toRadixString(36)}-'
        '${randomPart.toRadixString(36)}';
  }

  void _handleStorageCleared() {
    _clearActiveSession();
  }

  void _clearActiveSession() {
    _activeSession = null;
    _sessionState = ArgosSessionState.idle;
    _activeSessionIsAutomatic = false;
    _activeAutomaticPolicy = null;
    _automaticContext = null;
    _maxDurationDeadlineAt = null;
    _explicitPauseStartedAt = null;
    _backgroundedAt = null;
    _nextSequence = 0;
  }

  @visibleForTesting
  void setNowForTesting(DateTime Function()? now) {
    _now = now ?? DateTime.now;
  }

  @visibleForTesting
  void handleAppLifecycleStateForTesting(AppLifecycleState state) {
    _handleAppLifecycleState(state);
  }

  @visibleForTesting
  void resetForTesting() {
    listener = null;
    config = null;
    currentRoute = '';
    _clearActiveSession();
    _initialized = false;
    _now = DateTime.now;
  }
}

class _ArgosLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ArgosManager.instance._handleAppLifecycleState(state);
  }
}
