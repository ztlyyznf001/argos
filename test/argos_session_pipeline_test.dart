import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:argos_inspector/argos_inspector.dart';
import 'package:argos_inspector/apm/argos_http_monitor.dart';

class _MemoryAdapter implements ArgosStorageAdapter {
  final Map<String, String> store = <String, String>{};

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write(String key, String value) async => store[key] = value;

  @override
  Future<void> clear(String key) async => store.remove(key);
}

class _FailingAdapter extends _MemoryAdapter {
  int writeAttempts = 0;

  @override
  Future<void> write(String key, String value) async {
    writeAttempts++;
    throw StateError('disk unavailable');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final manager = ArgosManager.instance;

  setUp(() {
    manager.resetForTesting();
    ArgosCrashMonitor.instance.resetForTesting();
    ArgosResourceMonitor.instance.dispose();
    ArgosPacketStorage.instance.persistInterval = Duration.zero;
    ArgosPacketStorage.instance.setAdapter(null);
  });

  tearDown(() {
    ArgosCrashMonitor.instance.resetForTesting();
    ArgosResourceMonitor.instance.dispose();
    manager.resetForTesting();
    ArgosPacketStorage.instance.persistInterval = const Duration(seconds: 5);
    ArgosPacketStorage.instance.setAdapter(null);
  });

  test('all persistable pipelines share sequence and pause gating', () async {
    final adapter = _MemoryAdapter();
    final seen = <ArgosBaseModel>[];
    manager.init(
      config: ArgosConfig(
        enableStorage: true,
        sessionMode: ArgosSessionMode.manual,
        hostWhiteList: const <String>['allowed.example'],
        storageAdapter: adapter,
        storagePersistInterval: Duration.zero,
        apmTypes: const <ArgosCapability>[],
      ),
      listener: (model) {
        if (model != null) seen.add(model);
      },
    );
    final session = manager.startSession();

    final blocked = ArgosHttpInfo(
      Uri.parse('https://blocked.example/no'),
      'GET',
    );
    await ArgosHttpMonitor.instance.dispatchForTesting(blocked);

    final http = ArgosHttpInfo(
      Uri.parse('https://allowed.example/ok'),
      'GET',
    );
    await ArgosHttpMonitor.instance.dispatchForTesting(http);
    await ArgosHttpMonitor.instance.dispatchForTesting(http);

    await ArgosNativeCapture.instance.handleEventForTesting(
      jsonEncode(_record('native-source', 2, kind: 'network').toJson()),
    );
    await ArgosCrashMonitor.instance.recordForTesting(
      'boom',
      stack: 'first frame',
    );
    await ArgosJankMonitor.instance.dispatchForTesting(
      ArgosJankInfo(
        droppedFrames: 2,
        totalDurationMs: 40,
        maxFrameMs: 24,
        buildMs: 10,
        rasterMs: 20,
      ),
    );
    await ArgosResourceMonitor.instance.dispatchForTesting(
      ArgosResourceInfo(currentRssBytes: 100, maxRssBytes: 120),
    );

    final accepted = await manager.getSessionRecords(session.id);
    expect(accepted.map((record) => record.sequence), <int>[1, 2, 3, 4, 5]);
    expect(
      accepted.map((record) => record.kind),
      <String>['network', 'network', 'crash', 'jank', 'resource'],
    );
    expect(accepted.map((record) => record.id).toSet(), hasLength(5));
    expect(seen, hasLength(5));
    expect(
      seen.map((model) => model.eventMetadata!.sessionId).toSet(),
      <String>{session.id},
    );
    expect(blocked.eventMetadata, isNull,
        reason: 'host filtering happens before sequence allocation');

    manager.pauseSession();
    await ArgosHttpMonitor.instance.dispatchForTesting(
      ArgosHttpInfo(Uri.parse('https://allowed.example/paused'), 'GET'),
    );
    await ArgosNativeCapture.instance.handleEventForTesting(
      jsonEncode(_record('paused-native', 6).toJson()),
    );
    await ArgosCrashMonitor.instance.recordForTesting('paused boom');
    await ArgosJankMonitor.instance.dispatchForTesting(
      ArgosJankInfo(
        droppedFrames: 1,
        totalDurationMs: 20,
        maxFrameMs: 20,
        buildMs: 10,
        rasterMs: 10,
      ),
    );
    await ArgosResourceMonitor.instance.dispatchForTesting(
      ArgosResourceInfo(currentRssBytes: 130, maxRssBytes: 130),
    );

    expect(await manager.getSessionRecords(session.id), hasLength(5));
    expect(seen, hasLength(5));

    manager.resumeSession();
    final resumed = ArgosHttpInfo(
      Uri.parse('https://allowed.example/resumed'),
      'GET',
    );
    await ArgosHttpMonitor.instance.dispatchForTesting(resumed);
    expect(resumed.eventMetadata!.sequence, 6);
  });

  test('crash best-effort flush failure still chains the host handler',
      () async {
    final adapter = _FailingAdapter();
    final previous = FlutterError.onError;
    var hostCalls = 0;
    FlutterError.onError = (_) => hostCalls++;
    addTearDown(() => FlutterError.onError = previous);

    manager.init(
      config: ArgosConfig(
        enableStorage: true,
        storageAdapter: adapter,
        apmTypes: const <ArgosCapability>[ArgosCapability.crash],
      ),
    );
    final sessionId = manager.activeSession!.id;

    FlutterError.onError!(FlutterErrorDetails(
      exception: StateError('handler-chain'),
      stack: StackTrace.current,
    ));

    expect(hostCalls, 1, reason: 'host handler is chained synchronously');
    await Future<void>.delayed(Duration.zero);
    await manager.flush();

    expect(adapter.writeAttempts, greaterThanOrEqualTo(1));
    expect(await manager.getSessionRecords(sessionId), hasLength(1));
  });
}

ArgosPacketRecord _record(String id, int timestamp,
        {String kind = 'network'}) =>
    ArgosPacketRecord(
      id: id,
      uri: 'https://allowed.example/$id',
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
