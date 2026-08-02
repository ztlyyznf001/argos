import 'dart:convert';

import 'package:argos_inspector/argos_inspector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingAdapter implements ArgosStorageAdapter {
  final Map<String, String> store = <String, String>{};
  final List<Map<String, dynamic>> writes = <Map<String, dynamic>>[];
  bool failWrites = false;
  int writeAttempts = 0;

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write(String key, String value) async {
    writeAttempts++;
    if (failWrites) throw StateError('disk unavailable');
    store[key] = value;
    if (key == ArgosPacketStorage.storeKey) {
      writes.add(
        Map<String, dynamic>.from(jsonDecode(value) as Map<dynamic, dynamic>),
      );
    }
  }

  @override
  Future<void> clear(String key) async => store.remove(key);
}

class _TestModel extends ArgosBaseModel {
  _TestModel() {
    type = ArgosCapability.network;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final manager = ArgosManager.instance;
  late _RecordingAdapter adapter;
  late DateTime now;

  setUp(() {
    manager.resetForTesting();
    adapter = _RecordingAdapter();
    now = DateTime.fromMillisecondsSinceEpoch(1000000);
    manager.setNowForTesting(() => now);
    ArgosPacketStorage.instance.persistInterval = Duration.zero;
    ArgosPacketStorage.instance.setAdapter(adapter);
  });

  tearDown(() {
    manager.resetForTesting();
    ArgosPacketStorage.instance.persistInterval = const Duration(seconds: 5);
    ArgosPacketStorage.instance.setAdapter(null);
  });

  test('default process strategy keeps one id across a long background',
      () async {
    manager.init(config: _config(adapter));
    final id = manager.activeSession!.id;

    manager.handleAppLifecycleStateForTesting(AppLifecycleState.paused);
    now = now.add(const Duration(days: 1));
    manager.handleAppLifecycleStateForTesting(AppLifecycleState.resumed);
    final model = await _dispatch(manager, now.millisecondsSinceEpoch);

    expect(manager.activeSession!.id, id);
    expect(model.eventMetadata!.sessionId, id);
    expect((await manager.getSessions()).single.endReason, isNull);
  });

  test('max duration rolls before metadata and resets sequence', () async {
    manager.init(
      config: _config(
        adapter,
        policy: ArgosAutomaticSessionPolicy.adaptive(
          backgroundTimeout: null,
          maxDuration: const Duration(seconds: 10),
        ),
      ),
    );
    final oldId = manager.activeSession!.id;
    now = now.add(const Duration(seconds: 9));
    final first = await _dispatch(manager, now.millisecondsSinceEpoch);
    now = now.add(const Duration(seconds: 1));
    final rollover = await _dispatch(manager, now.millisecondsSinceEpoch);
    final newId = manager.activeSession!.id;

    expect(first.eventMetadata!.sessionId, oldId);
    expect(first.eventMetadata!.sequence, 1);
    expect(newId, isNot(oldId));
    expect(rollover.eventMetadata!.sessionId, newId);
    expect(rollover.eventMetadata!.sequence, 1);
    final sessions = await manager.getSessions();
    final old = sessions.singleWhere((session) => session.id == oldId);
    expect(old.endReason, ArgosSessionEndReason.maxDuration);
    expect(old.endedAt, 1010000);
  });

  test('context change wins over max duration and persists attributes only',
      () async {
    var context = ArgosSessionContext(
      fingerprint: 'user-a|tenant-a',
      attributes: const <String, String>{'tenant': 'a'},
    );
    manager.init(
      config: _config(
        adapter,
        policy: ArgosAutomaticSessionPolicy.adaptive(
          backgroundTimeout: null,
          maxDuration: const Duration(seconds: 1),
          contextProvider: () => context,
        ),
      ),
    );
    final oldId = manager.activeSession!.id;
    await manager.flush();
    adapter.writes.clear();
    context = ArgosSessionContext(
      fingerprint: 'user-b|tenant-b',
      attributes: const <String, String>{'tenant': 'b'},
    );
    now = now.add(const Duration(seconds: 2));

    final model = await _dispatch(manager, now.millisecondsSinceEpoch);
    await manager.flush();

    final sessions = await manager.getSessions();
    final old = sessions.singleWhere((session) => session.id == oldId);
    final current = manager.activeSession!;
    expect(old.endReason, ArgosSessionEndReason.contextChanged);
    expect(current.id, isNot(oldId));
    expect(current.attributes, <String, String>{'tenant': 'b'});
    expect(model.eventMetadata!.sessionId, current.id);
    expect(model.eventMetadata!.sequence, 1);
    expect(adapter.writes, hasLength(3));
    expect(
      ((adapter.writes[0]['sessions'] as List<dynamic>).single
          as Map<dynamic, dynamic>)['endReason'],
      'contextChanged',
    );
    expect(adapter.writes[1]['sessions'], hasLength(2));
    expect(adapter.writes[2]['records'], hasLength(1));
    expect(
      adapter.store[ArgosPacketStorage.storeKey],
      isNot(contains('user-b|tenant-b')),
    );
  });

  test('same context and route changes do not roll the session', () async {
    final context = ArgosSessionContext(
      fingerprint: 'stable',
      attributes: const <String, String>{'environment': 'staging'},
    );
    manager.init(
      config: _config(
        adapter,
        policy: ArgosAutomaticSessionPolicy.adaptive(
          backgroundTimeout: null,
          maxDuration: null,
          contextProvider: () => context,
        ),
      ),
    );
    final id = manager.activeSession!.id;
    manager.currentRoute = '/checkout';
    final first = await _dispatch(manager, now.millisecondsSinceEpoch);
    manager.currentRoute = '/confirmation';
    final second = await _dispatch(manager, now.millisecondsSinceEpoch + 1);

    expect(manager.activeSession!.id, id);
    expect(first.eventMetadata!.sequence, 1);
    expect(second.eventMetadata!.sequence, 2);
  });

  test('context provider failure keeps the last valid session', () async {
    var shouldThrow = false;
    final context = ArgosSessionContext(fingerprint: 'stable');
    manager.init(
      config: _config(
        adapter,
        policy: ArgosAutomaticSessionPolicy.adaptive(
          backgroundTimeout: null,
          maxDuration: null,
          contextProvider: () {
            if (shouldThrow) throw StateError('provider failed');
            return context;
          },
        ),
      ),
    );
    final id = manager.activeSession!.id;
    await _dispatch(manager, now.millisecondsSinceEpoch);
    shouldThrow = true;

    final second = await _dispatch(manager, now.millisecondsSinceEpoch + 1);

    expect(manager.activeSession!.id, id);
    expect(second.eventMetadata!.sequence, 2);
  });

  test('context provider failure during creation keeps capture available',
      () async {
    manager.init(
      config: _config(
        adapter,
        policy: ArgosAutomaticSessionPolicy.adaptive(
          backgroundTimeout: null,
          maxDuration: null,
          contextProvider: () => throw StateError('initial provider failed'),
        ),
      ),
    );
    final id = manager.activeSession!.id;

    final model = await _dispatch(manager, now.millisecondsSinceEpoch);

    expect(manager.activeSession!.id, id);
    expect(manager.activeSession!.attributes, isEmpty);
    expect(model.eventMetadata!.sessionId, id);
  });

  test('explicit pause shifts the max-duration deadline', () async {
    manager.init(
      config: _config(
        adapter,
        policy: ArgosAutomaticSessionPolicy.adaptive(
          backgroundTimeout: null,
          maxDuration: const Duration(seconds: 10),
        ),
      ),
    );
    final id = manager.activeSession!.id;
    now = now.add(const Duration(seconds: 5));
    manager.pauseSession();
    now = now.add(const Duration(seconds: 100));
    manager.resumeSession();

    now = now.add(const Duration(seconds: 4));
    final beforeDeadline = await _dispatch(manager, now.millisecondsSinceEpoch);
    expect(manager.activeSession!.id, id);
    expect(beforeDeadline.eventMetadata!.sequence, 1);

    now = now.add(const Duration(seconds: 1));
    final atDeadline = await _dispatch(manager, now.millisecondsSinceEpoch);
    expect(manager.activeSession!.id, isNot(id));
    expect(atDeadline.eventMetadata!.sequence, 1);
  });

  test('explicit session is never taken over by adaptive config', () async {
    var context = ArgosSessionContext(fingerprint: 'a');
    manager.init(
      config: _config(
        adapter,
        policy: ArgosAutomaticSessionPolicy.adaptive(
          backgroundTimeout: const Duration(seconds: 1),
          maxDuration: const Duration(seconds: 1),
          contextProvider: () => context,
        ),
      ),
    );
    await manager.stopSession();
    final explicitId = manager.startSession(label: 'explicit').id;
    context = ArgosSessionContext(fingerprint: 'b');
    manager.handleAppLifecycleStateForTesting(AppLifecycleState.paused);
    now = now.add(const Duration(hours: 1));
    manager.handleAppLifecycleStateForTesting(AppLifecycleState.resumed);

    final model = await _dispatch(manager, now.millisecondsSinceEpoch);

    expect(manager.activeSession!.id, explicitId);
    expect(model.eventMetadata!.sessionId, explicitId);
  });

  test('repeated init does not reclassify a process session as adaptive',
      () async {
    manager.init(config: _config(adapter));
    final id = manager.activeSession!.id;
    manager.init(
      config: _config(
        adapter,
        policy: ArgosAutomaticSessionPolicy.adaptive(
          backgroundTimeout: const Duration(seconds: 1),
          maxDuration: const Duration(seconds: 1),
        ),
      ),
    );
    manager.handleAppLifecycleStateForTesting(AppLifecycleState.paused);
    now = now.add(const Duration(hours: 1));
    manager.handleAppLifecycleStateForTesting(AppLifecycleState.resumed);
    await _dispatch(manager, now.millisecondsSinceEpoch);

    expect(manager.activeSession!.id, id);
  });

  test('manual and idle states never start from lifecycle timing', () async {
    manager.init(
      config: _config(
        adapter,
        sessionMode: ArgosSessionMode.manual,
        policy: ArgosAutomaticSessionPolicy.adaptive(
          backgroundTimeout: const Duration(seconds: 1),
          maxDuration: const Duration(seconds: 1),
        ),
      ),
    );
    manager.handleAppLifecycleStateForTesting(AppLifecycleState.paused);
    now = now.add(const Duration(hours: 1));
    manager.handleAppLifecycleStateForTesting(AppLifecycleState.resumed);
    expect(manager.activeSession, isNull);

    final id = manager.startSession().id;
    manager.handleAppLifecycleStateForTesting(AppLifecycleState.paused);
    now = now.add(const Duration(hours: 1));
    manager.handleAppLifecycleStateForTesting(AppLifecycleState.resumed);
    expect(manager.activeSession!.id, id);

    await manager.stopSession();
    manager.handleAppLifecycleStateForTesting(AppLifecycleState.paused);
    now = now.add(const Duration(hours: 1));
    manager.handleAppLifecycleStateForTesting(AppLifecycleState.resumed);
    expect(manager.activeSession, isNull);
  });

  test('short background and clock rollback preserve the active id', () {
    manager.init(
      config: _config(
        adapter,
        policy: ArgosAutomaticSessionPolicy.adaptive(
          backgroundTimeout: const Duration(minutes: 2),
          maxDuration: null,
        ),
      ),
    );
    final id = manager.activeSession!.id;
    manager.handleAppLifecycleStateForTesting(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 1));
    manager.handleAppLifecycleStateForTesting(AppLifecycleState.resumed);
    expect(manager.activeSession!.id, id);

    manager.handleAppLifecycleStateForTesting(AppLifecycleState.paused);
    now = now.subtract(const Duration(minutes: 5));
    manager.handleAppLifecycleStateForTesting(AppLifecycleState.resumed);
    expect(manager.activeSession!.id, id);
  });

  test('exact background threshold rolls once with bounded timestamps',
      () async {
    manager.init(
      config: _config(
        adapter,
        policy: ArgosAutomaticSessionPolicy.adaptive(
          backgroundTimeout: const Duration(minutes: 2),
          maxDuration: null,
        ),
      ),
    );
    final oldId = manager.activeSession!.id;
    await _dispatch(manager, 1000005);
    manager.handleAppLifecycleStateForTesting(AppLifecycleState.detached);
    await manager.flush();
    adapter.writes.clear();
    now = now.add(const Duration(minutes: 2));
    manager.handleAppLifecycleStateForTesting(AppLifecycleState.resumed);
    final newId = manager.activeSession!.id;
    final firstNewEvent = await _dispatch(manager, now.millisecondsSinceEpoch);

    manager.handleAppLifecycleStateForTesting(AppLifecycleState.resumed);
    await manager.flush();

    expect(newId, isNot(oldId));
    expect(manager.activeSession!.id, newId,
        reason: 'repeated resumed notification must not roll again');
    expect(firstNewEvent.eventMetadata!.sessionId, newId);
    expect(firstNewEvent.eventMetadata!.sequence, 1);
    expect(adapter.writes, hasLength(3));
    expect(
      ((adapter.writes[0]['sessions'] as List<dynamic>).first
          as Map<dynamic, dynamic>)['endReason'],
      'backgroundTimeout',
    );
    expect(adapter.writes[1]['sessions'], hasLength(2));
    expect(adapter.writes[2]['records'], hasLength(2));
    final old = (await manager.getSessions())
        .singleWhere((session) => session.id == oldId);
    expect(old.endReason, ArgosSessionEndReason.backgroundTimeout);
    expect(old.endedAt, 1120000);
    expect(manager.activeSession!.startedAt, 1120000);
  });

  test('background endedAt never precedes an accepted background event',
      () async {
    manager.init(
      config: _config(
        adapter,
        policy: ArgosAutomaticSessionPolicy.adaptive(
          backgroundTimeout: const Duration(minutes: 2),
          maxDuration: null,
        ),
      ),
    );
    final oldId = manager.activeSession!.id;
    manager.handleAppLifecycleStateForTesting(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 2, seconds: 5));
    await _dispatch(manager, 1124000);

    manager.handleAppLifecycleStateForTesting(AppLifecycleState.resumed);
    await manager.flush();

    final old = (await manager.getSessions())
        .singleWhere((session) => session.id == oldId);
    expect(old.endReason, ArgosSessionEndReason.backgroundTimeout);
    expect(old.lastEventAt, 1124000);
    expect(old.endedAt, 1124000);
    expect(manager.activeSession!.startedAt, 1125000);
  });

  test('explicitly paused adaptive session ignores background timeout', () {
    manager.init(
      config: _config(
        adapter,
        policy: ArgosAutomaticSessionPolicy.adaptive(
          backgroundTimeout: const Duration(seconds: 1),
          maxDuration: null,
        ),
      ),
    );
    final id = manager.activeSession!.id;
    manager.pauseSession();
    manager.handleAppLifecycleStateForTesting(AppLifecycleState.paused);
    now = now.add(const Duration(hours: 1));
    manager.handleAppLifecycleStateForTesting(AppLifecycleState.resumed);

    expect(manager.sessionState, ArgosSessionState.paused);
    expect(manager.activeSession!.id, id);
    manager.resumeSession();
    expect(manager.activeSession!.id, id);
  });

  test('rollover persists complete, begin, append in strict order', () async {
    manager.init(
      config: _config(
        adapter,
        policy: ArgosAutomaticSessionPolicy.adaptive(
          backgroundTimeout: null,
          maxDuration: const Duration(seconds: 1),
        ),
      ),
    );
    final oldId = manager.activeSession!.id;
    await manager.flush();
    adapter.writes.clear();
    now = now.add(const Duration(seconds: 1));

    final model = await _dispatch(manager, now.millisecondsSinceEpoch);

    expect(adapter.writes, hasLength(3));
    final completedSessions = adapter.writes[0]['sessions'] as List<dynamic>;
    expect(
      (completedSessions.single as Map<dynamic, dynamic>)['endReason'],
      'maxDuration',
    );
    final begunSessions = adapter.writes[1]['sessions'] as List<dynamic>;
    expect(begunSessions, hasLength(2));
    expect(adapter.writes[1]['records'], isEmpty);
    final appendedRecords = adapter.writes[2]['records'] as List<dynamic>;
    expect(appendedRecords, hasLength(1));
    expect(
      (appendedRecords.single as Map<dynamic, dynamic>)['sessionId'],
      model.eventMetadata!.sessionId,
    );
    expect(model.eventMetadata!.sessionId, isNot(oldId));
  });

  test('rapid rollover dispatches remain ordered and sequential', () async {
    manager.init(
      config: _config(
        adapter,
        policy: ArgosAutomaticSessionPolicy.adaptive(
          backgroundTimeout: null,
          maxDuration: const Duration(seconds: 1),
        ),
      ),
    );
    now = now.add(const Duration(seconds: 1));
    final firstModel = _TestModel();
    final secondModel = _TestModel();

    final first = manager.dispatch(
      firstModel,
      record: _record('first', now.millisecondsSinceEpoch),
    );
    final second = manager.dispatch(
      secondModel,
      record: _record('second', now.millisecondsSinceEpoch),
    );
    await Future.wait(<Future<void>>[first, second]);

    final id = manager.activeSession!.id;
    expect(firstModel.eventMetadata!.sessionId, id);
    expect(secondModel.eventMetadata!.sessionId, id);
    expect(firstModel.eventMetadata!.sequence, 1);
    expect(secondModel.eventMetadata!.sequence, 2);
    expect(
      (await manager.getSessionRecords(id)).map((record) => record.sequence),
      <int>[1, 2],
    );
  });

  test('maxSessions eviction preserves the newly active rollover session',
      () async {
    manager.init(
      config: _config(
        adapter,
        maxSessions: 1,
        policy: ArgosAutomaticSessionPolicy.adaptive(
          backgroundTimeout: null,
          maxDuration: const Duration(seconds: 1),
        ),
      ),
    );
    final oldId = manager.activeSession!.id;
    now = now.add(const Duration(seconds: 1));

    await _dispatch(manager, now.millisecondsSinceEpoch);

    final currentId = manager.activeSession!.id;
    expect(currentId, isNot(oldId));
    final sessions = await manager.getSessions();
    expect(sessions.map((session) => session.id), <String>[currentId]);
  });

  test('write failures do not break runtime rollover or dispatch', () async {
    adapter.failWrites = true;
    manager.init(
      config: _config(
        adapter,
        policy: ArgosAutomaticSessionPolicy.adaptive(
          backgroundTimeout: null,
          maxDuration: const Duration(seconds: 1),
        ),
      ),
    );
    final oldId = manager.activeSession!.id;
    now = now.add(const Duration(seconds: 1));

    final model = await _dispatch(manager, now.millisecondsSinceEpoch);
    await manager.flush();

    expect(manager.activeSession!.id, isNot(oldId));
    expect(model.eventMetadata!.sessionId, manager.activeSession!.id);
    expect(adapter.writeAttempts, greaterThanOrEqualTo(3));
  });

  test('new end reason remains in schema v1 without touching legacy key',
      () async {
    adapter.store[ArgosPacketStorage.legacyStoreKey] = '[]';
    manager.init(
      config: _config(
        adapter,
        policy: ArgosAutomaticSessionPolicy.adaptive(
          backgroundTimeout: null,
          maxDuration: const Duration(seconds: 1),
        ),
      ),
    );
    now = now.add(const Duration(seconds: 1));

    await _dispatch(manager, now.millisecondsSinceEpoch);
    await manager.flush();

    final envelope = jsonDecode(
      adapter.store[ArgosPacketStorage.storeKey]!,
    ) as Map<String, dynamic>;
    expect(envelope['schemaVersion'], 1);
    final sessions = envelope['sessions'] as List<dynamic>;
    expect(
      sessions.any(
        (dynamic item) =>
            (item as Map<dynamic, dynamic>)['endReason'] == 'maxDuration',
      ),
      isTrue,
    );
    expect(
      adapter.store[ArgosPacketStorage.legacyStoreKey],
      '[]',
    );
  });
}

ArgosConfig _config(
  ArgosStorageAdapter adapter, {
  ArgosAutomaticSessionPolicy automaticSessionPolicy =
      const ArgosAutomaticSessionPolicy.process(),
  ArgosAutomaticSessionPolicy? policy,
  int maxSessions = 5,
  ArgosSessionMode sessionMode = ArgosSessionMode.automatic,
}) {
  return ArgosConfig(
    enableStorage: true,
    storageAdapter: adapter,
    storagePersistInterval: Duration.zero,
    apmTypes: const <ArgosCapability>[],
    sessionMode: sessionMode,
    automaticSessionPolicy: policy ?? automaticSessionPolicy,
    maxSessions: maxSessions,
  );
}

Future<_TestModel> _dispatch(ArgosManager manager, int timestamp) async {
  final model = _TestModel();
  await manager.dispatch(model, record: _record('event-$timestamp', timestamp));
  return model;
}

ArgosPacketRecord _record(String id, int timestamp) => ArgosPacketRecord(
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
      kind: 'network',
    );
