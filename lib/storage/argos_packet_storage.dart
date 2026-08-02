import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:argos_inspector/model/argos_diagnostic_session.dart';
import 'package:argos_inspector/model/argos_http_info_model.dart';
import 'package:argos_inspector/storage/argos_storage_adapter.dart';

/// Versioned storage for diagnostic sessions and their event records.
///
/// Every operation shares [_opChain], making begin/append/complete/clear fully
/// ordered even when callers intentionally do not await intermediate writes.
class ArgosPacketStorage {
  ArgosPacketStorage._internal();

  static final ArgosPacketStorage _instance = ArgosPacketStorage._internal();

  static ArgosPacketStorage get instance => _instance;

  static const int schemaVersion = 1;
  static const String storeKey = 'argos_diagnostic_store_v1';
  static const String legacyStoreKey = 'argos_packet_records';

  ArgosStorageAdapter? _adapter;
  Future<void> _opChain = Future<void>.value();
  _DiagnosticEnvelope? _cache;
  bool _dirty = false;
  bool _readOnlyUnknownSchema = false;
  Timer? _flushTimer;

  /// Called after a successful in-memory clear so the manager can discard its
  /// active session without introducing a storage -> manager import cycle.
  VoidCallback? onCleared;

  Duration persistInterval = const Duration(seconds: 5);

  void setAdapter(ArgosStorageAdapter? adapter) {
    if (identical(_adapter, adapter)) return;
    _adapter = adapter;
    _cache = null;
    _dirty = false;
    _readOnlyUnknownSchema = false;
    _flushTimer?.cancel();
    _flushTimer = null;
    _opChain = Future<void>.value();
  }

  /// Hydrates the versioned envelope and recovers open sessions as interrupted.
  Future<void> hydrate() => _run(_ensureHydrated);

  Future<void> beginSession(
    ArgosDiagnosticSession session, {
    int maxSessions = 5,
  }) {
    return _run(() async {
      if (_adapter == null) return;
      await _ensureHydrated();
      if (_readOnlyUnknownSchema) return;
      final existing = _sessionIndex(session.id);
      if (existing < 0) {
        _cache!.sessions.add(session);
      } else {
        _cache!.sessions[existing] = session;
      }
      _trimSessions(maxSessions, activeSessionId: session.id);
      await _markDirty();
    });
  }

  /// Pause/resume are runtime states, but still enter the queue to preserve a
  /// total order with surrounding session and event operations.
  Future<void> pauseSession(String sessionId) => _touchSession(sessionId);

  Future<void> resumeSession(String sessionId) => _touchSession(sessionId);

  Future<void> _touchSession(String sessionId) {
    return _run(() async {
      if (_adapter == null) return;
      await _ensureHydrated();
      if (_readOnlyUnknownSchema) return;
      _sessionIndex(sessionId);
    });
  }

  Future<void> completeSession(
    ArgosDiagnosticSession session, {
    int maxSessions = 5,
  }) {
    return _run(() async {
      if (_adapter == null) return;
      await _ensureHydrated();
      if (_readOnlyUnknownSchema) return;
      final index = _sessionIndex(session.id);
      if (index < 0) return;
      _cache!.sessions[index] = session;
      _trimSessions(maxSessions);
      await _markDirty();
    });
  }

  /// Backward-compatible append helper for callers that still build HTTP info.
  Future<void> append(
    ArgosHttpInfo info, {
    int maxRecords = 200,
    int resourceMaxRecords = 50,
    int maxSessions = 5,
    String routeName = '',
  }) {
    final json = info.toJson()..['routeName'] = routeName;
    return appendRecord(
      ArgosPacketRecord.fromJson(json),
      maxRecords: maxRecords,
      resourceMaxRecords: resourceMaxRecords,
      maxSessions: maxSessions,
    );
  }

  Future<void> appendRecord(
    ArgosPacketRecord record, {
    int maxRecords = 200,
    int resourceMaxRecords = 50,
    int maxSessions = 5,
  }) {
    return _run(() async {
      if (_adapter == null) return;
      await _ensureHydrated();
      if (_readOnlyUnknownSchema) return;

      final sessionId = record.sessionId;
      if (sessionId != null) {
        final index = _sessionIndex(sessionId);
        if (index < 0 || _cache!.sessions[index].isEnded) {
          debugPrint(
            'ArgosPacketStorage ignored orphan record ${record.id}',
          );
          return;
        }
        _cache!.records.add(record);
        final eventAt = record.endTimestamp > 0
            ? record.endTimestamp
            : record.startTimestamp;
        _cache!.sessions[index] = _cache!.sessions[index].copyWith(
          lastEventAt: eventAt,
        );
        final trimmed = _trimRecordBucket(
          sessionId: sessionId,
          kind: record.kind,
          maxRecords: maxRecords,
          resourceMaxRecords: resourceMaxRecords,
        );
        if (trimmed) {
          final refreshedIndex = _sessionIndex(sessionId);
          _cache!.sessions[refreshedIndex] =
              _cache!.sessions[refreshedIndex].copyWith(truncated: true);
        }
      } else {
        _cache!.records.add(record);
        _trimRecordBucket(
          sessionId: null,
          kind: record.kind,
          maxRecords: maxRecords,
          resourceMaxRecords: resourceMaxRecords,
        );
      }

      _trimSessions(maxSessions, activeSessionId: sessionId);
      await _markDirty();
    });
  }

  Future<List<ArgosPacketRecord>> getAllAsync() {
    return _run(() async {
      if (_adapter == null) return <ArgosPacketRecord>[];
      await _ensureHydrated();
      final records = List<ArgosPacketRecord>.of(_cache!.records);
      records.sort(_globalRecordOrder);
      return records;
    });
  }

  Future<List<ArgosDiagnosticSession>> getSessions() {
    return _run(() async {
      if (_adapter == null) return <ArgosDiagnosticSession>[];
      await _ensureHydrated();
      final sessions = List<ArgosDiagnosticSession>.of(_cache!.sessions);
      sessions.sort((a, b) {
        final time = b.startedAt.compareTo(a.startedAt);
        return time != 0 ? time : b.id.compareTo(a.id);
      });
      return sessions;
    });
  }

  Future<List<ArgosPacketRecord>> getRecordsForSession(String sessionId) {
    return _run(() async {
      if (_adapter == null) return <ArgosPacketRecord>[];
      await _ensureHydrated();
      if (_sessionIndex(sessionId) < 0) return <ArgosPacketRecord>[];
      final records = _cache!.records
          .where((record) => record.sessionId == sessionId)
          .toList();
      records.sort(_sessionRecordOrder);
      return records;
    });
  }

  /// Clears the versioned store and the rollback-compatible legacy snapshot.
  Future<void> clear() {
    _flushTimer?.cancel();
    _flushTimer = null;
    return _run(() async {
      _cache = _DiagnosticEnvelope.empty();
      _dirty = false;
      _readOnlyUnknownSchema = false;
      final adapter = _adapter;
      if (adapter != null) {
        for (final key in <String>[storeKey, legacyStoreKey]) {
          try {
            await adapter.clear(key);
          } catch (error) {
            debugPrint('ArgosPacketStorage clear error for $key: $error');
          }
        }
      }
      onCleared?.call();
    });
  }

  Future<void> flush() {
    _flushTimer?.cancel();
    _flushTimer = null;
    return _run(_persist);
  }

  Future<T> _run<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _opChain = _opChain.then((_) async {
      try {
        completer.complete(await task());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> _ensureHydrated() async {
    if (_cache != null) return;
    if (_adapter == null) {
      _cache = _DiagnosticEnvelope.empty();
      return;
    }

    _cache = await _readEnvelope();
    if (_readOnlyUnknownSchema) return;

    var recovered = false;
    for (var i = 0; i < _cache!.sessions.length; i++) {
      final session = _cache!.sessions[i];
      if (session.endedAt != null) continue;
      _cache!.sessions[i] = session.copyWith(
        endedAt: session.lastEventAt ?? session.startedAt,
        endReason: ArgosSessionEndReason.interrupted,
      );
      recovered = true;
    }
    if (recovered) await _markDirty();
  }

  Future<_DiagnosticEnvelope> _readEnvelope() async {
    try {
      final raw = await _adapter!.read(storeKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) {
          _protectUnknownStore('versioned value is not a JSON object');
          return _DiagnosticEnvelope.empty();
        }
        final map = Map<String, dynamic>.from(decoded);
        final version = _asInt(map['schemaVersion']);
        if (version != schemaVersion) {
          _protectUnknownStore('unsupported schemaVersion $version');
          return _DiagnosticEnvelope.empty();
        }
        return _DiagnosticEnvelope.fromJson(map);
      }
    } catch (error) {
      _protectUnknownStore('failed to decode versioned store: $error');
      return _DiagnosticEnvelope.empty();
    }

    try {
      final legacyRaw = await _adapter!.read(legacyStoreKey);
      if (legacyRaw == null || legacyRaw.isEmpty) {
        return _DiagnosticEnvelope.empty();
      }
      final decoded = jsonDecode(legacyRaw);
      if (decoded is! List) return _DiagnosticEnvelope.empty();
      final records = <ArgosPacketRecord>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          records.add(
            ArgosPacketRecord.fromJson(Map<String, dynamic>.from(item))
                .copyWith(clearSessionId: true, sequence: 0),
          );
        } catch (error) {
          debugPrint('ArgosPacketStorage skipped legacy record: $error');
        }
      }
      return _DiagnosticEnvelope(
        sessions: <ArgosDiagnosticSession>[],
        records: records,
      );
    } catch (error) {
      debugPrint('ArgosPacketStorage legacy read error: $error');
      return _DiagnosticEnvelope.empty();
    }
  }

  void _protectUnknownStore(String reason) {
    _readOnlyUnknownSchema = true;
    debugPrint('ArgosPacketStorage opened read-only: $reason');
  }

  Future<void> _markDirty() async {
    _dirty = true;
    if (persistInterval == Duration.zero) {
      await _persist();
    } else {
      _scheduleFlush();
    }
  }

  void _scheduleFlush() {
    if (_flushTimer != null || persistInterval == Duration.zero) return;
    _flushTimer = Timer(persistInterval, () {
      _flushTimer = null;
      flush();
    });
  }

  Future<void> _persist() async {
    if (_adapter == null ||
        !_dirty ||
        _cache == null ||
        _readOnlyUnknownSchema) {
      return;
    }
    try {
      await _adapter!.write(storeKey, jsonEncode(_cache!.toJson()));
      _dirty = false;
    } catch (error) {
      debugPrint('ArgosPacketStorage write error: $error');
    }
  }

  int _sessionIndex(String sessionId) =>
      _cache!.sessions.indexWhere((session) => session.id == sessionId);

  bool _trimRecordBucket({
    required String? sessionId,
    required String kind,
    required int maxRecords,
    required int resourceMaxRecords,
  }) {
    final configuredCap = kind == 'resource' ? resourceMaxRecords : maxRecords;
    final cap = configuredCap > 0 ? configuredCap : 1;
    final bucket = _cache!.records
        .where(
          (record) => record.sessionId == sessionId && record.kind == kind,
        )
        .toList()
      ..sort(_sessionRecordOrder);
    final overflow = bucket.length - cap;
    if (overflow <= 0) return false;
    for (final record in bucket.take(overflow).toList()) {
      _cache!.records.remove(record);
    }
    return true;
  }

  void _trimSessions(int configuredMax, {String? activeSessionId}) {
    final maxSessions = configuredMax > 0 ? configuredMax : 1;
    while (_cache!.sessions.length > maxSessions) {
      final candidates = _cache!.sessions
          .where(
            (session) =>
                session.id != activeSessionId && session.endedAt != null,
          )
          .toList()
        ..sort((a, b) {
          final time = a.startedAt.compareTo(b.startedAt);
          return time != 0 ? time : a.id.compareTo(b.id);
        });
      if (candidates.isEmpty) return;
      final evicted = candidates.first;
      _cache!.sessions.removeWhere((session) => session.id == evicted.id);
      _cache!.records.removeWhere((record) => record.sessionId == evicted.id);
    }
  }

  static int _globalRecordOrder(
    ArgosPacketRecord a,
    ArgosPacketRecord b,
  ) {
    final time = b.startTimestamp.compareTo(a.startTimestamp);
    if (time != 0) return time;
    final sequence = b.sequence.compareTo(a.sequence);
    return sequence != 0 ? sequence : b.id.compareTo(a.id);
  }

  static int _sessionRecordOrder(
    ArgosPacketRecord a,
    ArgosPacketRecord b,
  ) {
    if (a.sequence > 0 && b.sequence > 0) {
      final sequence = a.sequence.compareTo(b.sequence);
      if (sequence != 0) return sequence;
    }
    final time = a.startTimestamp.compareTo(b.startTimestamp);
    return time != 0 ? time : a.id.compareTo(b.id);
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? -1;
  }
}

class _DiagnosticEnvelope {
  _DiagnosticEnvelope({required this.sessions, required this.records});

  factory _DiagnosticEnvelope.empty() => _DiagnosticEnvelope(
        sessions: <ArgosDiagnosticSession>[],
        records: <ArgosPacketRecord>[],
      );

  factory _DiagnosticEnvelope.fromJson(Map<String, dynamic> json) {
    final sessions = <ArgosDiagnosticSession>[];
    final rawSessions = json['sessions'];
    if (rawSessions is List) {
      for (final item in rawSessions) {
        if (item is! Map) continue;
        try {
          final session = ArgosDiagnosticSession.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (session.id.isNotEmpty) sessions.add(session);
        } catch (error) {
          debugPrint('ArgosPacketStorage skipped session: $error');
        }
      }
    }

    final records = <ArgosPacketRecord>[];
    final rawRecords = json['records'];
    if (rawRecords is List) {
      for (final item in rawRecords) {
        if (item is! Map) continue;
        try {
          records.add(
            ArgosPacketRecord.fromJson(Map<String, dynamic>.from(item)),
          );
        } catch (error) {
          debugPrint('ArgosPacketStorage skipped record: $error');
        }
      }
    }
    return _DiagnosticEnvelope(sessions: sessions, records: records);
  }

  final List<ArgosDiagnosticSession> sessions;
  final List<ArgosPacketRecord> records;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': ArgosPacketStorage.schemaVersion,
        'sessions': sessions.map((session) => session.toJson()).toList(),
        'records': records.map((record) => record.toJson()).toList(),
      };
}
