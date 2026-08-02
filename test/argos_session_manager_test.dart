import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:argos_inspector/argos_inspector.dart';

class _MemoryAdapter implements ArgosStorageAdapter {
  final Map<String, String> store = <String, String>{};

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write(String key, String value) async => store[key] = value;

  @override
  Future<void> clear(String key) async => store.remove(key);
}

class _TestModel extends ArgosBaseModel {
  _TestModel(ArgosCapability capability) {
    type = capability;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MemoryAdapter adapter;
  final manager = ArgosManager.instance;

  setUp(() {
    manager.resetForTesting();
    adapter = _MemoryAdapter();
    ArgosPacketStorage.instance.persistInterval = Duration.zero;
    ArgosPacketStorage.instance.setAdapter(adapter);
  });

  tearDown(() {
    manager.resetForTesting();
    ArgosPacketStorage.instance.persistInterval = const Duration(seconds: 5);
    ArgosPacketStorage.instance.setAdapter(null);
  });

  test('automatic mode starts once when storage is enabled', () async {
    final config = ArgosConfig(
      enableStorage: true,
      storageAdapter: adapter,
      apmTypes: const <ArgosCapability>[],
      storagePersistInterval: Duration.zero,
    );
    manager.init(config: config);
    final firstId = manager.activeSession!.id;

    manager.init(config: config);
    await manager.flush();

    expect(manager.sessionState, ArgosSessionState.recording);
    expect(manager.captureEnabled, isTrue);
    expect(manager.activeSession!.id, firstId);
    expect(await manager.getSessions(), hasLength(1));
  });

  test('manual mode waits for explicit start', () {
    manager.init(
      config: ArgosConfig(
        enableStorage: true,
        sessionMode: ArgosSessionMode.manual,
        storageAdapter: adapter,
        apmTypes: const <ArgosCapability>[],
      ),
    );

    expect(manager.sessionState, ArgosSessionState.idle);
    expect(manager.captureEnabled, isFalse);
    expect(manager.activeSession, isNull);

    final session = manager.startSession(label: 'manual');
    expect(session.label, 'manual');
    expect(manager.captureEnabled, isTrue);
  });

  test('automatic mode remains idle when storage is disabled', () {
    manager.init(
      config: ArgosConfig(
        enableStorage: false,
        apmTypes: const <ArgosCapability>[],
      ),
    );

    expect(manager.sessionState, ArgosSessionState.idle);
    expect(manager.captureEnabled, isFalse);
  });

  test('start is idempotent and paused start resumes the same session', () {
    manager.init(
      config: ArgosConfig(
        sessionMode: ArgosSessionMode.manual,
        apmTypes: const <ArgosCapability>[],
      ),
    );
    final first = manager.startSession();

    expect(manager.startSession().id, first.id);
    manager.pauseSession();
    expect(manager.sessionState, ArgosSessionState.paused);
    expect(manager.startSession().id, first.id);
    expect(manager.sessionState, ArgosSessionState.recording);
  });

  test('captureEnabled maps idle/start, recording/pause, paused/resume', () {
    manager.init(
      config: ArgosConfig(
        sessionMode: ArgosSessionMode.manual,
        apmTypes: const <ArgosCapability>[],
      ),
    );

    manager.captureEnabled = true;
    final id = manager.activeSession!.id;
    manager.captureEnabled = false;
    expect(manager.sessionState, ArgosSessionState.paused);
    expect(manager.activeSession!.id, id);
    manager.captureEnabled = true;
    expect(manager.sessionState, ArgosSessionState.recording);
    expect(manager.activeSession!.id, id);
  });

  test('dispatch assigns matching metadata and stable unique sequence',
      () async {
    final seen = <ArgosBaseModel?>[];
    manager.init(
      config: ArgosConfig(
        enableStorage: true,
        sessionMode: ArgosSessionMode.manual,
        storageAdapter: adapter,
        storagePersistInterval: Duration.zero,
        apmTypes: const <ArgosCapability>[],
      ),
      listener: seen.add,
    );
    final session = manager.startSession();
    final firstModel = _TestModel(ArgosCapability.network);
    final secondModel = _TestModel(ArgosCapability.crash);
    final firstRecord = _record('source-a', 100, kind: 'network');
    final secondRecord = _record('source-b', 100, kind: 'crash');

    await manager.dispatch(firstModel, record: firstRecord);
    await manager.dispatch(secondModel, record: secondRecord);

    expect(seen, <ArgosBaseModel?>[firstModel, secondModel]);
    expect(firstModel.eventMetadata!.sessionId, session.id);
    expect(firstModel.eventMetadata!.sequence, 1);
    expect(secondModel.eventMetadata!.sequence, 2);
    expect(firstModel.eventMetadata!.id, isNot(secondModel.eventMetadata!.id));
    final stored = await manager.getSessionRecords(session.id);
    expect(stored.map((record) => record.sequence), <int>[1, 2]);
    expect(stored[0].id, firstModel.eventMetadata!.id);
    expect(stored[1].id, secondModel.eventMetadata!.id);
  });

  test('paused and idle dispatches do not notify, persist, or consume sequence',
      () async {
    var calls = 0;
    manager.init(
      config: ArgosConfig(
        enableStorage: true,
        sessionMode: ArgosSessionMode.manual,
        storageAdapter: adapter,
        storagePersistInterval: Duration.zero,
        apmTypes: const <ArgosCapability>[],
      ),
      listener: (_) => calls++,
    );
    final session = manager.startSession();
    await manager.dispatch(
      _TestModel(ArgosCapability.network),
      record: _record('accepted', 1),
    );
    manager.pauseSession();
    final rejected = _TestModel(ArgosCapability.crash);
    await manager.dispatch(rejected, record: _record('rejected', 2));
    manager.resumeSession();
    final resumed = _TestModel(ArgosCapability.resource);
    await manager.dispatch(resumed, record: _record('resumed', 3));

    expect(calls, 2);
    expect(rejected.eventMetadata, isNull);
    expect(resumed.eventMetadata!.sequence, 2);
    expect(await manager.getSessionRecords(session.id), hasLength(2));
  });

  test('explicit session remains listener-only without an adapter', () async {
    ArgosPacketStorage.instance.setAdapter(null);
    ArgosBaseModel? seen;
    manager.init(
      config: ArgosConfig(
        enableStorage: false,
        sessionMode: ArgosSessionMode.manual,
        apmTypes: const <ArgosCapability>[],
      ),
      listener: (model) => seen = model,
    );
    final session = manager.startSession();
    final model = _TestModel(ArgosCapability.jank);

    await manager.dispatch(model, record: _record('memory-only', 1));

    expect(seen, model);
    expect(model.eventMetadata!.sessionId, session.id);
    expect(await manager.getSessions(), isEmpty);
  });

  test('stop waits for event ordering and returns to idle', () async {
    manager.init(
      config: ArgosConfig(
        enableStorage: true,
        sessionMode: ArgosSessionMode.manual,
        storageAdapter: adapter,
        storagePersistInterval: Duration.zero,
        apmTypes: const <ArgosCapability>[],
      ),
    );
    final session = manager.startSession();
    final append = manager.dispatch(
      _TestModel(ArgosCapability.network),
      record: _record('event', 1),
    );
    final stopped = manager.stopSession();
    await Future.wait<dynamic>(<Future<dynamic>>[append, stopped]);

    expect(manager.sessionState, ArgosSessionState.idle);
    expect(manager.activeSession, isNull);
    expect(await manager.getSessionRecords(session.id), hasLength(1));
    final persisted = (await manager.getSessions()).single;
    expect(persisted.endReason, ArgosSessionEndReason.completed);
    expect(persisted.endedAt, isNotNull);
  });

  test('clear discards the active session and next start gets a new id',
      () async {
    manager.init(
      config: ArgosConfig(
        enableStorage: true,
        sessionMode: ArgosSessionMode.manual,
        storageAdapter: adapter,
        apmTypes: const <ArgosCapability>[],
      ),
    );
    final oldId = manager.startSession().id;

    await manager.clear();

    expect(manager.sessionState, ArgosSessionState.idle);
    expect(manager.activeSession, isNull);
    expect(manager.startSession().id, isNot(oldId));
    await manager.flush();
  });

  test('init recovers a persisted open session before automatic begin',
      () async {
    const old = ArgosDiagnosticSession(
      id: 'old-session',
      startedAt: 10,
      lastEventAt: 20,
    );
    adapter.store[ArgosPacketStorage.storeKey] = jsonEncode(<String, dynamic>{
      'schemaVersion': 1,
      'sessions': <Map<String, dynamic>>[old.toJson()],
      'records': <Map<String, dynamic>>[],
    });
    manager.init(
      config: ArgosConfig(
        enableStorage: true,
        storageAdapter: adapter,
        storagePersistInterval: Duration.zero,
        apmTypes: const <ArgosCapability>[],
      ),
    );
    final currentId = manager.activeSession!.id;

    final sessions = await manager.getSessions();

    expect(currentId, isNot(old.id));
    final recovered = sessions.singleWhere((session) => session.id == old.id);
    expect(recovered.endedAt, 20);
    expect(recovered.endReason, ArgosSessionEndReason.interrupted);
  });
}

ArgosPacketRecord _record(String id, int timestamp,
        {String kind = 'network'}) =>
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
      kind: kind,
    );
