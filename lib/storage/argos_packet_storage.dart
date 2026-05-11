import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:argos/model/argos_http_info_model.dart';
import 'package:argos/storage/argos_storage_adapter.dart';

class ArgosPacketStorage {
  ArgosPacketStorage._internal();

  static final ArgosPacketStorage _instance = ArgosPacketStorage._internal();

  static ArgosPacketStorage get instance => _instance;

  static const String _key = 'argos_packet_records';

  ArgosStorageAdapter? _adapter;
  Future<void> _writeChain = Future.value();

  void setAdapter(ArgosStorageAdapter? adapter) {
    _adapter = adapter;
  }

  /// Append a captured HTTP record. Trims oldest entries when [maxRecords] exceeded.
  void append(ArgosHttpInfo info,
      {int maxRecords = 200, String routeName = ''}) {
    final json = info.toJson();
    json['routeName'] = routeName;
    final record = ArgosPacketRecord.fromJson(json);
    _writeChain = _writeChain.then((_) => _writeAsync(record, maxRecords));
  }

  /// Append a pre-built [ArgosPacketRecord] (e.g. from native capture).
  void appendRecord(ArgosPacketRecord record, {int maxRecords = 200}) {
    _writeChain = _writeChain.then((_) => _writeAsync(record, maxRecords));
  }

  Future<void> _writeAsync(ArgosPacketRecord record, int maxRecords) async {
    if (_adapter == null) return;
    try {
      final records = await _readList();
      records.add(record.toJson());
      while (records.length > maxRecords) {
        records.removeAt(0);
      }
      await _adapter!.write(_key, jsonEncode(records));
    } catch (e) {
      debugPrint('ArgosPacketStorage write error: $e');
    }
  }

  /// Returns all stored records sorted by startTimestamp descending.
  Future<List<ArgosPacketRecord>> getAllAsync() async {
    if (_adapter == null) return [];
    final list = await _readList();
    final records = list
        .map((e) => ArgosPacketRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    records.sort((a, b) => b.startTimestamp.compareTo(a.startTimestamp));
    return records;
  }

  /// Clears all stored packet records.
  Future<void> clear() async {
    if (_adapter == null) return;
    try {
      await _adapter!.clear(_key);
    } catch (e) {
      debugPrint('ArgosPacketStorage clear error: $e');
    }
  }

  Future<List<dynamic>> _readList() async {
    try {
      final raw = await _adapter?.read(_key);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
    } catch (_) {}
    return [];
  }
}
