import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:argos_inspector/argos_inspector.dart';

/// In-memory adapter that counts read/write calls so coalescing and single-
/// hydration can be asserted. `writeDelay` holds a write in-flight to exercise
/// ordering against a racing clear.
class _CountingAdapter implements ArgosStorageAdapter {
  final Map<String, String> _store = {};
  int reads = 0;
  int writes = 0;
  Duration writeDelay = Duration.zero;

  @override
  Future<String?> read(String key) async {
    reads++;
    return _store[key];
  }

  @override
  Future<void> write(String key, String value) async {
    writes++;
    if (writeDelay != Duration.zero) await Future.delayed(writeDelay);
    _store[key] = value;
  }

  @override
  Future<void> clear(String key) async => _store.remove(key);

  List<dynamic> get stored {
    final raw = _store['argos_packet_records'];
    return raw == null ? const [] : jsonDecode(raw) as List<dynamic>;
  }
}

ArgosPacketRecord _rec(String kind, int ts) => ArgosPacketRecord(
      id: '$kind-$ts',
      uri: '$kind/$ts',
      method: kind == 'network' ? 'GET' : kind.toUpperCase(),
      startTimestamp: ts,
      endTimestamp: ts,
      requestHeaders: const {},
      requestBody: '',
      responseCode: 0,
      responseBody: '',
      responseHeaders: const {},
      responseSize: 0,
      kind: kind,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CountingAdapter adapter;

  setUp(() {
    adapter = _CountingAdapter();
    // Immediate persistence by default so most tests don't wait on a timer.
    ArgosPacketStorage.instance.persistInterval = Duration.zero;
    ArgosPacketStorage.instance.setAdapter(adapter);
  });

  tearDown(() {
    ArgosPacketStorage.instance.persistInterval = const Duration(seconds: 5);
    ArgosPacketStorage.instance.setAdapter(null);
  });

  group('serialization / ordering', () {
    test('clear after an in-flight write wins; data does not resurrect',
        () async {
      adapter.writeDelay = const Duration(milliseconds: 30);
      final w = ArgosPacketStorage.instance.appendRecord(_rec('network', 1));
      final c = ArgosPacketStorage.instance.clear();
      await Future.wait([w, c]);

      final records = await ArgosPacketStorage.instance.getAllAsync();
      expect(records, isEmpty, reason: 'clear was issued after the write');
      expect(adapter.stored, isEmpty);
    });

    test('write issued after clear is retained', () async {
      await ArgosPacketStorage.instance.clear();
      await ArgosPacketStorage.instance.appendRecord(_rec('crash', 2));

      final records = await ArgosPacketStorage.instance.getAllAsync();
      expect(records.map((r) => r.kind), ['crash']);
    });

    test('rapid concurrent writes are not lost', () async {
      final futures = [
        for (var i = 0; i < 20; i++)
          ArgosPacketStorage.instance.appendRecord(_rec('network', i)),
      ];
      await Future.wait(futures);

      final records = await ArgosPacketStorage.instance.getAllAsync();
      expect(records.where((r) => r.kind == 'network').length, 20);
    });

    test('read reflects a just-issued write', () async {
      await ArgosPacketStorage.instance.appendRecord(_rec('jank', 7));
      final records = await ArgosPacketStorage.instance.getAllAsync();
      expect(records.any((r) => r.kind == 'jank'), isTrue);
    });
  });

  group('hydration', () {
    test('hydrates from the adapter exactly once across many ops', () async {
      await adapter.write(
          'argos_packet_records', '[${_recJson('network', 1)}]');
      ArgosPacketStorage.instance.setAdapter(adapter);
      adapter.reads = 0; // count reads after (re)binding

      await ArgosPacketStorage.instance.getAllAsync();
      await ArgosPacketStorage.instance.appendRecord(_rec('crash', 2));
      await ArgosPacketStorage.instance.getAllAsync();

      expect(adapter.reads, 1, reason: 'cache serves subsequent ops');
    });

    test('setAdapter with pre-seeded data hydrates that data', () async {
      final fresh = _CountingAdapter();
      await fresh.write('argos_packet_records', '[${_recJson('crash', 9)}]');
      ArgosPacketStorage.instance.setAdapter(fresh);

      final records = await ArgosPacketStorage.instance.getAllAsync();
      expect(records.map((r) => r.uri), ['crash/9']);
    });
  });

  group('coalesced persistence', () {
    test('immediate mode (Duration.zero) writes on every append', () async {
      await ArgosPacketStorage.instance.appendRecord(_rec('network', 1));
      await ArgosPacketStorage.instance.appendRecord(_rec('network', 2));
      await ArgosPacketStorage.instance.appendRecord(_rec('network', 3));
      expect(adapter.writes, 3);
    });

    // Plain `test` (real event loop) so the throttle Timer actually fires;
    // `testWidgets`' FakeAsync would freeze the timer and the singleton's op
    // chain across zones.
    test('coalescing batches multiple writes into fewer adapter writes',
        () async {
      ArgosPacketStorage.instance.persistInterval =
          const Duration(milliseconds: 100);

      for (var i = 0; i < 5; i++) {
        await ArgosPacketStorage.instance.appendRecord(_rec('network', i));
      }
      // Nothing persisted yet — the throttle timer hasn't fired.
      expect(adapter.writes, 0);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(adapter.writes, 1, reason: '5 writes coalesced into 1 flush');
      final records = await ArgosPacketStorage.instance.getAllAsync();
      expect(records.where((r) => r.kind == 'network').length, 5);
    });

    test('flush() forces a pending write to disk', () async {
      ArgosPacketStorage.instance.persistInterval = const Duration(seconds: 30);
      await ArgosPacketStorage.instance.appendRecord(_rec('network', 1));
      expect(adapter.writes, 0, reason: 'coalesced, timer not yet fired');

      await ArgosPacketStorage.instance.flush();
      expect(adapter.writes, 1);
      expect(adapter.stored.length, 1);
    });
  });
}

String _recJson(String kind, int ts) =>
    '{"id":"$kind-$ts","uri":"$kind/$ts","method":"GET","startTimestamp":$ts,'
    '"endTimestamp":$ts,"requestHeaders":{},"requestBody":"","responseCode":0,'
    '"responseBody":"","responseHeaders":{},"responseSize":0,"kind":"$kind",'
    '"routeName":""}';
