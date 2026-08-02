import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:argos_inspector/argos_inspector.dart';

class _MemoryAdapter implements ArgosStorageAdapter {
  final Map<String, String> store = <String, String>{};
  final List<String> clearedKeys = <String>[];

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write(String key, String value) async => store[key] = value;

  @override
  Future<void> clear(String key) async {
    clearedKeys.add(key);
    store.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MemoryAdapter adapter;

  setUp(() {
    adapter = _MemoryAdapter();
    ArgosPacketStorage.instance.persistInterval = Duration.zero;
    ArgosPacketStorage.instance.setAdapter(adapter);
  });

  tearDown(() {
    ArgosPacketStorage.instance.onCleared = null;
    ArgosPacketStorage.instance.persistInterval = const Duration(seconds: 5);
    ArgosPacketStorage.instance.setAdapter(null);
  });

  test('writes and reads a schemaVersion 1 envelope', () async {
    final session = _session('s1', 10);
    await ArgosPacketStorage.instance.beginSession(session);
    await ArgosPacketStorage.instance.appendRecord(
      _record('one', 11, sessionId: 's1', sequence: 1),
    );

    final envelope = jsonDecode(
      adapter.store[ArgosPacketStorage.storeKey]!,
    ) as Map<String, dynamic>;
    expect(envelope['schemaVersion'], 1);
    expect(envelope['sessions'], hasLength(1));
    expect(envelope['records'], hasLength(1));

    final sessions = await ArgosPacketStorage.instance.getSessions();
    final records =
        await ArgosPacketStorage.instance.getRecordsForSession('s1');
    expect(sessions.single.lastEventAt, 11);
    expect(records.single.id, 'one');
  });

  test('migrates legacy List without deleting the rollback snapshot', () async {
    final legacy = jsonEncode(<Map<String, dynamic>>[
      _record('legacy', 1).toJson(),
    ]);
    adapter.store[ArgosPacketStorage.legacyStoreKey] = legacy;
    ArgosPacketStorage.instance.setAdapter(null);
    ArgosPacketStorage.instance.setAdapter(adapter);

    final records = await ArgosPacketStorage.instance.getAllAsync();
    expect(records.single.sessionId, isNull);
    expect(records.single.sequence, 0);

    await ArgosPacketStorage.instance.beginSession(_session('new', 2));
    await ArgosPacketStorage.instance.flush();

    expect(adapter.store[ArgosPacketStorage.legacyStoreKey], legacy);
    final migrated = jsonDecode(
      adapter.store[ArgosPacketStorage.storeKey]!,
    ) as Map<String, dynamic>;
    expect(migrated['records'], hasLength(1));
  });

  test('protects an unknown schema from overwrite', () async {
    const futureValue = '{"schemaVersion":99,"future":true}';
    adapter.store[ArgosPacketStorage.storeKey] = futureValue;
    ArgosPacketStorage.instance.setAdapter(null);
    ArgosPacketStorage.instance.setAdapter(adapter);

    await ArgosPacketStorage.instance.appendRecord(_record('ignored', 1));
    await ArgosPacketStorage.instance.flush();

    expect(await ArgosPacketStorage.instance.getAllAsync(), isEmpty);
    expect(adapter.store[ArgosPacketStorage.storeKey], futureValue);
  });

  test('recovers open sessions as interrupted before a new begin', () async {
    adapter.store[ArgosPacketStorage.storeKey] = jsonEncode(<String, dynamic>{
      'schemaVersion': 1,
      'sessions': <Map<String, dynamic>>[
        _session('old', 10).copyWith(lastEventAt: 15).toJson(),
      ],
      'records': <Map<String, dynamic>>[],
    });
    ArgosPacketStorage.instance.setAdapter(null);
    ArgosPacketStorage.instance.setAdapter(adapter);

    final hydration = ArgosPacketStorage.instance.hydrate();
    final begin =
        ArgosPacketStorage.instance.beginSession(_session('current', 20));
    await Future.wait(<Future<void>>[hydration, begin]);

    final sessions = await ArgosPacketStorage.instance.getSessions();
    final old = sessions.singleWhere((session) => session.id == 'old');
    expect(old.endedAt, 15);
    expect(old.endReason, ArgosSessionEndReason.interrupted);
    expect(sessions.singleWhere((session) => session.id == 'current').endedAt,
        isNull);
  });

  test('empty interrupted session ends at startedAt', () async {
    adapter.store[ArgosPacketStorage.storeKey] = jsonEncode(<String, dynamic>{
      'schemaVersion': 1,
      'sessions': <Map<String, dynamic>>[_session('empty', 10).toJson()],
      'records': <Map<String, dynamic>>[],
    });
    ArgosPacketStorage.instance.setAdapter(null);
    ArgosPacketStorage.instance.setAdapter(adapter);

    final sessions = await ArgosPacketStorage.instance.getSessions();
    expect(sessions.single.endedAt, 10);
    expect(sessions.single.endReason, ArgosSessionEndReason.interrupted);
  });

  test('session query is sequence ascending and missing session is empty',
      () async {
    await ArgosPacketStorage.instance.beginSession(_session('s1', 1));
    await ArgosPacketStorage.instance.appendRecord(
      _record('third', 5, sessionId: 's1', sequence: 3),
    );
    await ArgosPacketStorage.instance.appendRecord(
      _record('first', 5, sessionId: 's1', sequence: 1),
    );

    final records =
        await ArgosPacketStorage.instance.getRecordsForSession('s1');
    expect(records.map((record) => record.sequence), <int>[1, 3]);
    expect(
      await ArgosPacketStorage.instance.getRecordsForSession('missing'),
      isEmpty,
    );
  });

  test('evicts the oldest ended session as a whole', () async {
    for (var i = 1; i <= 3; i++) {
      final session = _session('s$i', i);
      await ArgosPacketStorage.instance.beginSession(session, maxSessions: 2);
      await ArgosPacketStorage.instance.appendRecord(
        _record('r$i', i, sessionId: 's$i', sequence: 1),
        maxSessions: 2,
      );
      await ArgosPacketStorage.instance.completeSession(
        session.copyWith(
          endedAt: i + 1,
          endReason: ArgosSessionEndReason.completed,
        ),
        maxSessions: 2,
      );
    }

    final sessions = await ArgosPacketStorage.instance.getSessions();
    expect(sessions.map((session) => session.id), <String>['s3', 's2']);
    expect(
        (await ArgosPacketStorage.instance.getAllAsync())
            .any((record) => record.sessionId == 's1'),
        isFalse);
  });

  test('trims only the active session kind and marks it truncated', () async {
    await ArgosPacketStorage.instance.beginSession(_session('active', 1));
    for (var i = 1; i <= 3; i++) {
      await ArgosPacketStorage.instance.appendRecord(
        _record('r$i', i, sessionId: 'active', sequence: i),
        maxRecords: 2,
      );
    }

    final session = (await ArgosPacketStorage.instance.getSessions()).single;
    final records =
        await ArgosPacketStorage.instance.getRecordsForSession('active');
    expect(session.truncated, isTrue);
    expect(records.map((record) => record.sequence), <int>[2, 3]);
  });

  test('begin, append, and complete preserve issue order', () async {
    final session = _session('ordered', 1);
    final begin = ArgosPacketStorage.instance.beginSession(session);
    final append = ArgosPacketStorage.instance.appendRecord(
      _record('event', 2, sessionId: 'ordered', sequence: 1),
    );
    final complete = ArgosPacketStorage.instance.completeSession(
      session.copyWith(
        endedAt: 3,
        endReason: ArgosSessionEndReason.completed,
      ),
    );
    await Future.wait(<Future<void>>[begin, append, complete]);

    expect(
      await ArgosPacketStorage.instance.getRecordsForSession('ordered'),
      hasLength(1),
    );
    expect(
      (await ArgosPacketStorage.instance.getSessions()).single.endReason,
      ArgosSessionEndReason.completed,
    );
  });

  test('clear removes both keys and notifies the manager boundary', () async {
    adapter.store[ArgosPacketStorage.storeKey] = '{}';
    adapter.store[ArgosPacketStorage.legacyStoreKey] = '[]';
    var notified = false;
    ArgosPacketStorage.instance.onCleared = () => notified = true;

    await ArgosPacketStorage.instance.clear();

    expect(
        adapter.clearedKeys,
        containsAll(<String>[
          ArgosPacketStorage.storeKey,
          ArgosPacketStorage.legacyStoreKey,
        ]));
    expect(adapter.store, isEmpty);
    expect(notified, isTrue);
  });
}

ArgosDiagnosticSession _session(String id, int startedAt) =>
    ArgosDiagnosticSession(id: id, startedAt: startedAt);

ArgosPacketRecord _record(
  String id,
  int timestamp, {
  String? sessionId,
  int sequence = 0,
  String kind = 'network',
}) =>
    ArgosPacketRecord(
      id: id,
      uri: 'https://example.com/$id',
      method: 'GET',
      startTimestamp: timestamp,
      endTimestamp: timestamp,
      requestHeaders: const <String, String>{},
      requestBody: '',
      responseCode: 200,
      responseBody: '',
      responseHeaders: const <String, String>{},
      responseSize: 0,
      sessionId: sessionId,
      sequence: sequence,
      kind: kind,
    );
