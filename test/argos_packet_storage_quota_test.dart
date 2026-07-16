import 'package:flutter_test/flutter_test.dart';
import 'package:argos/argos.dart';

/// In-memory adapter so the storage layer can be exercised without MMKV.
class _FakeAdapter implements ArgosStorageAdapter {
  final Map<String, String> _store = {};
  @override
  Future<String?> read(String key) async => _store[key];
  @override
  Future<void> write(String key, String value) async => _store[key] = value;
  @override
  Future<void> clear(String key) async => _store.remove(key);
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

/// Awaits the specific write (appendRecord returns its write future), then
/// reads back — so the assertion never races the write chain.
Future<List<ArgosPacketRecord>> _appendAndRead(
  ArgosPacketRecord record, {
  int maxRecords = 200,
  int resourceMaxRecords = 50,
}) async {
  await ArgosPacketStorage.instance.appendRecord(
    record,
    maxRecords: maxRecords,
    resourceMaxRecords: resourceMaxRecords,
  );
  return ArgosPacketStorage.instance.getAllAsync();
}

Future<List<ArgosPacketRecord>> _appendMany(
  String kind,
  int count,
  int startTs, {
  int maxRecords = 200,
  int resourceMaxRecords = 50,
}) async {
  List<ArgosPacketRecord> latest = const [];
  for (var i = 0; i < count; i++) {
    latest = await _appendAndRead(
      _rec(kind, startTs + i),
      maxRecords: maxRecords,
      resourceMaxRecords: resourceMaxRecords,
    );
  }
  return latest;
}

int _countKind(List<ArgosPacketRecord> records, String kind) =>
    records.where((r) => r.kind == kind).length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => ArgosPacketStorage.instance.setAdapter(_FakeAdapter()));
  tearDown(() => ArgosPacketStorage.instance.setAdapter(null));

  test('resource samples never evict a captured crash or network record',
      () async {
    await _appendAndRead(_rec('crash', 1));
    await _appendAndRead(_rec('network', 2));

    // Flood well past the resource cap.
    final records =
        await _appendMany('resource', 120, 100, resourceMaxRecords: 50);

    expect(_countKind(records, 'crash'), 1, reason: 'crash must survive');
    expect(_countKind(records, 'network'), 1, reason: 'network must survive');
    expect(_countKind(records, 'resource'), 50, reason: 'capped at its own 50');
  });

  test('overflowing a kind evicts only that kind, oldest first', () async {
    final records =
        await _appendMany('resource', 55, 1000, resourceMaxRecords: 50);

    expect(_countKind(records, 'resource'), 50);
    // The 5 oldest (ts 1000..1004) were dropped; newest 50 remain.
    final tss = records.map((r) => r.startTimestamp).toList()..sort();
    expect(tss.first, 1005);
    expect(tss.last, 1054);
  });

  test('each kind tops out independently', () async {
    // Fill network to its cap, then a crash still lands and is retained.
    await _appendMany('network', 3, 10, maxRecords: 3);
    final records = await _appendAndRead(_rec('crash', 999), maxRecords: 3);

    expect(_countKind(records, 'network'), 3);
    expect(_countKind(records, 'crash'), 1);
  });

  test('custom resourceMaxRecords is honored', () async {
    final records =
        await _appendMany('resource', 30, 1, resourceMaxRecords: 20);
    expect(_countKind(records, 'resource'), 20);
  });

  test('custom maxPacketRecords applies per non-resource kind', () async {
    await _appendMany('network', 8, 1, maxRecords: 5);
    final records = await _appendMany('crash', 8, 100, maxRecords: 5);

    // Both non-resource kinds independently capped at 5 — not 5 total.
    expect(_countKind(records, 'network'), 5);
    expect(_countKind(records, 'crash'), 5);
  });

  test('default resource cap is 50 when unspecified', () async {
    // Note: append(...) default param is 50; drive it via the public default.
    Future<void> last = Future.value();
    for (var i = 0; i < 60; i++) {
      last = ArgosPacketStorage.instance.appendRecord(_rec('resource', i));
    }
    await last; // chained, so this settles all 60 writes
    final records = await ArgosPacketStorage.instance.getAllAsync();
    expect(_countKind(records, 'resource'), 50);
  });

  test('mixed timeline stays newest-first after trimming', () async {
    await _appendAndRead(_rec('crash', 5));
    await _appendMany('resource', 3, 10, resourceMaxRecords: 50);
    final records = await _appendAndRead(_rec('network', 99));

    final tss = records.map((r) => r.startTimestamp).toList();
    expect(tss, [99, 12, 11, 10, 5],
        reason: 'getAllAsync returns startTimestamp descending');
  });
}
