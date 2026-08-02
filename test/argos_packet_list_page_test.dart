import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:argos_inspector/argos_inspector.dart';

/// In-memory adapter so the real list page can be pumped against seeded data.
class _FakeAdapter implements ArgosStorageAdapter {
  final Map<String, String> _store = {};

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async => _store[key] = value;

  @override
  Future<void> clear(String key) async => _store.remove(key);
}

ArgosPacketRecord _rec({
  required String kind,
  required int ts,
  String uri = 'e',
  String method = '-',
  int responseCode = 0,
  int responseSize = 0,
  Map<String, String> responseHeaders = const {},
  String route = 'HomePage',
  String sessionId = 'ui-session',
}) {
  return ArgosPacketRecord(
    id: '$ts',
    uri: uri,
    method: method,
    startTimestamp: ts,
    endTimestamp: ts,
    requestHeaders: const {},
    requestBody: '',
    responseCode: responseCode,
    responseBody: '',
    responseHeaders: responseHeaders,
    responseSize: responseSize,
    routeName: route,
    kind: kind,
    sessionId: sessionId,
    sequence: ts + 1,
  );
}

ArgosPacketRecord _resource(int ts, int rss) => _rec(
      kind: 'resource',
      ts: ts,
      uri: 'RSS',
      method: 'RES',
      responseHeaders: {'currentRss': '$rss', 'maxRss': '$rss'},
      responseSize: rss,
    );

Future<_FakeAdapter> _seed(List<ArgosPacketRecord> records) async {
  final adapter = _FakeAdapter();
  final sessionIds = records.map((record) => record.sessionId).toSet();
  await adapter.write(
    ArgosPacketStorage.storeKey,
    jsonEncode(<String, dynamic>{
      'schemaVersion': 1,
      'sessions': sessionIds
          .whereType<String>()
          .map((id) => ArgosDiagnosticSession(
                id: id,
                startedAt: 1,
                endedAt: 2,
                endReason: ArgosSessionEndReason.completed,
              ).toJson())
          .toList(),
      'records': records.map((record) => record.toJson()).toList(),
    }),
  );
  ArgosPacketStorage.instance.setAdapter(adapter);
  return adapter;
}

Future<void> _pump(WidgetTester tester, {Brightness? brightness}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark
          ? ThemeData.dark(useMaterial3: true)
              .copyWith(splashFactory: NoSplash.splashFactory)
          : ThemeData.light(useMaterial3: true)
              .copyWith(splashFactory: NoSplash.splashFactory),
      home: const ArgosPacketListPage(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    ArgosManager.instance.resetForTesting();
    ArgosPacketStorage.instance.setAdapter(null);
  });

  group('event type filtering', () {
    testWidgets('APM events survive the default filter state', (tester) async {
      // The bug this change exists to fix: with only HTTP method chips, a
      // crash/jank/resource record had no way to be seen.
      await _seed([
        _rec(kind: 'network', ts: 400, uri: 'https://a.com/x', method: 'GET'),
        _rec(kind: 'crash', ts: 300, uri: 'boom'),
        _rec(kind: 'jank', ts: 200, uri: '丢帧 4'),
        _resource(100, 1024),
      ]);
      await _pump(tester);

      expect(find.text('boom'), findsOneWidget);
      expect(find.text('丢帧 4'), findsOneWidget);
    });

    testWidgets('selecting a kind hides the other kinds', (tester) async {
      await _seed([
        _rec(kind: 'network', ts: 400, uri: 'https://a.com/x', method: 'GET'),
        _rec(kind: 'crash', ts: 300, uri: 'boom'),
      ]);
      await _pump(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, '崩溃'));
      await tester.pumpAndSettle();

      expect(find.text('boom'), findsOneWidget);
      expect(find.textContaining('a.com'), findsNothing);
    });

    testWidgets('method chips are hidden for non-network kinds',
        (tester) async {
      await _seed([_rec(kind: 'crash', ts: 1, uri: 'boom')]);
      await _pump(tester);

      expect(find.text('GET'), findsOneWidget); // method chip, kind = 全部

      await tester.tap(find.widgetWithText(ChoiceChip, '崩溃'));
      await tester.pumpAndSettle();

      // No "崩溃 + GET" dead end can be expressed.
      expect(find.text('GET'), findsNothing);
    });

    testWidgets('switching away from 网络 clears a stale method selection',
        (tester) async {
      await _seed([
        _rec(kind: 'network', ts: 400, uri: 'https://a.com/x', method: 'GET'),
        _rec(kind: 'crash', ts: 300, uri: 'boom'),
      ]);
      await _pump(tester);

      // Narrow to POST (matches nothing), then leave and come back to 网络.
      await tester.tap(find.widgetWithText(ChoiceChip, '网络'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'POST'));
      await tester.pumpAndSettle();
      expect(find.textContaining('a.com'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, '崩溃'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '网络'));
      await tester.pumpAndSettle();

      // The GET request must be back: a stale POST must not silently persist.
      expect(find.textContaining('a.com'), findsOneWidget);
    });
  });

  group('resource aggregation in the list', () {
    testWidgets('a run of samples collapses into one row showing the peak',
        (tester) async {
      // Newest-first, as storage returns them. 300 is the spike.
      await _seed([
        for (var i = 0; i < 10; i++)
          _resource(100 + i, i == 5 ? 300 * 1024 * 1024 : 100 * 1024 * 1024),
      ]);
      await _pump(tester);

      expect(find.text('10 次采样', findRichText: true), findsNothing);
      expect(find.textContaining('10 次采样'), findsOneWidget);
      // The spike must be legible without expanding.
      expect(find.textContaining('峰值 300.0 MB'), findsOneWidget);
    });

    testWidgets('a network request between runs breaks the aggregation',
        (tester) async {
      await _seed([
        for (var i = 0; i < 5; i++) _resource(300 + i, 200 * 1024 * 1024),
        _rec(kind: 'network', ts: 200, uri: 'https://a.com/x', method: 'GET'),
        for (var i = 0; i < 5; i++) _resource(100 + i, 100 * 1024 * 1024),
      ]);
      await _pump(tester);

      expect(find.textContaining('5 次采样'), findsNWidgets(2));
      expect(find.textContaining('a.com'), findsOneWidget);
    });
  });

  group('empty state', () {
    testWidgets('speaks in terms of the selected kind, not "抓包"',
        (tester) async {
      await _seed([
        _rec(kind: 'network', ts: 1, uri: 'https://a.com/x', method: 'GET'),
      ]);
      await _pump(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, '崩溃'));
      await tester.pumpAndSettle();

      expect(find.text('暂无崩溃记录'), findsOneWidget);
    });
  });

  group('dark mode', () {
    testWidgets('renders without falling back to hard-coded grey',
        (tester) async {
      await _seed([
        _rec(
          kind: 'network',
          ts: 1,
          uri: 'https://a.com/x',
          method: 'GET',
          responseCode: 200,
          responseSize: 2048,
        ),
      ]);
      await _pump(tester, brightness: Brightness.dark);

      expect(tester.takeException(), isNull);
      // Response size is part of the new density; it must survive the theme.
      expect(find.text('2.0 KB'), findsOneWidget);
    });
  });

  group('diagnostic session controls', () {
    testWidgets('capture button pauses and resumes the same session',
        (tester) async {
      final adapter = await _seed(<ArgosPacketRecord>[
        _rec(kind: 'network', ts: 1, uri: 'https://a.com', method: 'GET'),
      ]);
      ArgosManager.instance.resetForTesting();
      ArgosManager.instance.init(
        config: ArgosConfig(
          enableStorage: true,
          sessionMode: ArgosSessionMode.manual,
          storageAdapter: adapter,
          storagePersistInterval: Duration.zero,
          apmTypes: const <ArgosCapability>[],
        ),
      );
      final id = ArgosManager.instance.startSession().id;
      await _pump(tester);

      expect(find.byTooltip('暂停抓包'), findsOneWidget);
      await tester.tap(find.byTooltip('暂停抓包'));
      await tester.pump();
      expect(ArgosManager.instance.sessionState, ArgosSessionState.paused);
      expect(ArgosManager.instance.activeSession!.id, id);

      await tester.tap(find.byTooltip('开始抓包'));
      await tester.pump();
      expect(ArgosManager.instance.sessionState, ArgosSessionState.recording);
      expect(ArgosManager.instance.activeSession!.id, id);
    });

    testWidgets('clear removes records and returns the manager to idle',
        (tester) async {
      final adapter = await _seed(<ArgosPacketRecord>[
        _rec(kind: 'crash', ts: 1, uri: 'boom'),
      ]);
      ArgosManager.instance.resetForTesting();
      ArgosManager.instance.init(
        config: ArgosConfig(
          enableStorage: true,
          sessionMode: ArgosSessionMode.manual,
          storageAdapter: adapter,
          storagePersistInterval: Duration.zero,
          apmTypes: const <ArgosCapability>[],
        ),
      );
      ArgosManager.instance.startSession();
      await _pump(tester);

      await tester.tap(find.widgetWithText(TextButton, '清空').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '清空').last);
      await tester.pumpAndSettle();

      expect(ArgosManager.instance.sessionState, ArgosSessionState.idle);
      expect(ArgosManager.instance.activeSession, isNull);
      expect(find.text('暂无记录'), findsOneWidget);
      expect(find.byTooltip('开始抓包'), findsOneWidget);
    });
  });
}
