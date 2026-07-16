import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:argos/model/argos_http_info_model.dart';
import 'package:argos/storage/argos_storage_adapter.dart';

/// Persists captured records behind a single serialized operation queue with an
/// in-memory cache as the source of truth.
///
/// Concurrency: every mutating and reading operation runs as a task on
/// [_opChain], so appends, clears and reads observe a total order — a `clear`
/// can never be silently undone by an in-flight write.
///
/// Performance: the cache is the authority, so a read never touches the adapter
/// after hydration and a write never re-decodes the store. The only synchronous
/// CPU cost left — `jsonEncode` — is coalesced: mutations mark the cache dirty
/// and a throttled timer flushes at most once per [persistInterval]. Reads never
/// wait on that flush; they return the cache immediately.
class ArgosPacketStorage {
  ArgosPacketStorage._internal();

  static final ArgosPacketStorage _instance = ArgosPacketStorage._internal();

  static ArgosPacketStorage get instance => _instance;

  static const String _key = 'argos_packet_records';

  ArgosStorageAdapter? _adapter;

  /// Serial queue: every op is chained here so ordering is total.
  Future<void> _opChain = Future.value();

  /// Authoritative in-memory copy. Null until hydrated from the adapter.
  List<Map<String, dynamic>>? _cache;

  bool _dirty = false;
  Timer? _flushTimer;

  /// How long to coalesce writes before flushing to the adapter. `Duration.zero`
  /// disables coalescing (persist on every write — no crash-loss window).
  Duration persistInterval = const Duration(seconds: 5);

  void setAdapter(ArgosStorageAdapter? adapter) {
    _adapter = adapter;
    // Rebind to a new backing store and discard transient state: the cache may
    // describe a different store, and any queued ops belong to the old one.
    // (In production this runs once at init, before any writes.)
    _cache = null;
    _dirty = false;
    _flushTimer?.cancel();
    _flushTimer = null;
    _opChain = Future.value();
  }

  /// Append a captured HTTP record. Trims oldest entries of the same kind when
  /// its per-kind cap is exceeded.
  ///
  /// Returns the op future so a caller (e.g. a test) can await this specific
  /// write's effect on the cache — not its eventual disk flush.
  Future<void> append(ArgosHttpInfo info,
      {int maxRecords = 200,
      int resourceMaxRecords = 50,
      String routeName = ''}) {
    final json = info.toJson();
    json['routeName'] = routeName;
    final record = ArgosPacketRecord.fromJson(json);
    return _enqueueWrite(record.toJson(), maxRecords, resourceMaxRecords);
  }

  /// Append a pre-built [ArgosPacketRecord] (e.g. from native capture).
  Future<void> appendRecord(ArgosPacketRecord record,
      {int maxRecords = 200, int resourceMaxRecords = 50}) {
    return _enqueueWrite(record.toJson(), maxRecords, resourceMaxRecords);
  }

  Future<void> _enqueueWrite(
      Map<String, dynamic> json, int maxRecords, int resourceMaxRecords) {
    return _run(() async {
      if (_adapter == null) return; // write is a no-op without a backing store
      await _ensureHydrated();
      _cache!.add(json);
      _trimKind(_cache!, _kindOf(json), maxRecords, resourceMaxRecords);
      _dirty = true;
      if (persistInterval == Duration.zero) {
        await _persist();
      } else {
        _scheduleFlush();
      }
    });
  }

  /// Returns all stored records sorted by startTimestamp descending. Reflects
  /// every operation issued before this call, straight from the cache.
  Future<List<ArgosPacketRecord>> getAllAsync() {
    return _run(() async {
      if (_adapter == null) return <ArgosPacketRecord>[];
      await _ensureHydrated();
      final records = _cache!
          .map((e) => ArgosPacketRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      records.sort((a, b) => b.startTimestamp.compareTo(a.startTimestamp));
      return records;
    });
  }

  /// Clears all stored records. Ordered with writes and flushed immediately.
  Future<void> clear() {
    _flushTimer?.cancel();
    _flushTimer = null;
    return _run(() async {
      _cache = [];
      _dirty = false;
      if (_adapter == null) return;
      try {
        await _adapter!.clear(_key);
      } catch (e) {
        debugPrint('ArgosPacketStorage clear error: $e');
      }
    });
  }

  /// Forces any pending (coalesced) write to disk now. No-op when clean.
  Future<void> flush() {
    _flushTimer?.cancel();
    _flushTimer = null;
    return _run(_persist);
  }

  // ── internals ──────────────────────────────────────────────────────────────

  /// Chains [task] onto the serial op queue and returns its result. Errors are
  /// surfaced to the caller but never break the chain for later ops.
  Future<T> _run<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _opChain = _opChain.then((_) async {
      try {
        completer.complete(await task());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<void> _ensureHydrated() async {
    if (_cache != null) return;
    if (_adapter == null) {
      _cache = [];
      return;
    }
    _cache = await _readList();
  }

  void _scheduleFlush() {
    if (persistInterval == Duration.zero) return;
    if (_flushTimer != null) return; // throttle: one pending flush at a time
    _flushTimer = Timer(persistInterval, () {
      _flushTimer = null;
      flush();
    });
  }

  /// Encodes the cache and writes it to the adapter. Keeps [_dirty] set on
  /// failure so a later successful flush self-heals.
  Future<void> _persist() async {
    if (_adapter == null || !_dirty || _cache == null) return;
    try {
      await _adapter!.write(_key, jsonEncode(_cache));
      _dirty = false;
    } catch (e) {
      debugPrint('ArgosPacketStorage write error: $e');
    }
  }

  /// Evicts oldest records of [kind] until it fits its own cap.
  ///
  /// A single append can only push its own kind over the limit, so only that
  /// kind is trimmed — other kinds (a captured crash, say) are never evicted by
  /// a flood of resource samples. Insertion order is preserved, so the tail
  /// stays newest and [getAllAsync]'s ordering is unaffected.
  void _trimKind(List<Map<String, dynamic>> records, String kind,
      int maxRecords, int resourceMaxRecords) {
    final cap = kind == 'resource' ? resourceMaxRecords : maxRecords;
    var overflow = records.where((e) => _kindOf(e) == kind).length - cap;
    if (overflow <= 0) return;
    records.removeWhere((e) => _kindOf(e) == kind && overflow-- > 0);
  }

  static String _kindOf(Map<String, dynamic> json) {
    final k = json['kind'];
    return k is String ? k : 'network';
  }

  Future<List<Map<String, dynamic>>> _readList() async {
    try {
      final raw = await _adapter?.read(_key);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }
}
