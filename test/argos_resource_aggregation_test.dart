import 'package:flutter_test/flutter_test.dart';
import 'package:argos_inspector/model/argos_http_info_model.dart';
import 'package:argos_inspector/ui/argos_ui_kit.dart';

ArgosPacketRecord _resource(int ts, int rssBytes, {int? maxRss}) {
  return ArgosPacketRecord(
    id: '$ts',
    uri: 'RSS',
    method: 'RES',
    startTimestamp: ts,
    endTimestamp: ts,
    requestHeaders: const {},
    requestBody: '',
    responseCode: 0,
    responseBody: '',
    responseHeaders: {
      'currentRss': '$rssBytes',
      'maxRss': '${maxRss ?? rssBytes}',
    },
    responseSize: rssBytes,
    kind: 'resource',
  );
}

ArgosPacketRecord _network(int ts) => ArgosPacketRecord(
      id: '$ts',
      uri: 'https://example.com/a',
      method: 'GET',
      startTimestamp: ts,
      endTimestamp: ts + 5,
      requestHeaders: const {},
      requestBody: '',
      responseCode: 200,
      responseBody: '',
      responseHeaders: const {},
      responseSize: 10,
      kind: 'network',
    );

ArgosPacketRecord _crash(int ts) => ArgosPacketRecord(
      id: '$ts',
      uri: 'boom',
      method: 'CRASH',
      startTimestamp: ts,
      endTimestamp: ts,
      requestHeaders: const {},
      requestBody: '',
      responseCode: 0,
      responseBody: 'stack',
      responseHeaders: const {},
      responseSize: 0,
      error: 'boom',
      kind: 'crash',
    );

void main() {
  group('argosBuildListEntries', () {
    test('collapses a run of consecutive resource samples into one entry', () {
      final records = List.generate(30, (i) => _resource(i, 100 + i));

      final entries = argosBuildListEntries(records);

      expect(entries, hasLength(1));
      expect(entries.single, isA<ArgosResourceRun>());
      expect((entries.single as ArgosResourceRun).count, 30);
    });

    test('a lone sample stays a plain row rather than an expander', () {
      final entries = argosBuildListEntries([
        _network(1),
        _resource(2, 100),
        _network(3),
      ]);

      expect(entries, hasLength(3));
      expect(entries[1], isA<ArgosRecordEntry>());
    });

    test('a network request between two runs breaks the aggregation', () {
      final records = <ArgosPacketRecord>[
        ...List.generate(10, (i) => _resource(i, 100)),
        _network(100),
        ...List.generate(10, (i) => _resource(200 + i, 200)),
      ];

      final entries = argosBuildListEntries(records);

      expect(entries, hasLength(3));
      expect(entries[0], isA<ArgosResourceRun>());
      expect(entries[1], isA<ArgosRecordEntry>());
      expect(entries[2], isA<ArgosResourceRun>());
      // The two runs must not merge, or the memory levels either side of the
      // request would be averaged into one meaningless number.
      expect((entries[0] as ArgosResourceRun).currentRss, 100);
      expect((entries[2] as ArgosResourceRun).currentRss, 200);
    });

    test('a crash between two runs breaks the aggregation', () {
      final records = <ArgosPacketRecord>[
        ...List.generate(5, (i) => _resource(i, 100)),
        _crash(50),
        ...List.generate(5, (i) => _resource(60 + i, 500)),
      ];

      final entries = argosBuildListEntries(records);

      expect(entries, hasLength(3));
      expect(entries[1], isA<ArgosRecordEntry>());
      expect((entries[1] as ArgosRecordEntry).record.kind, 'crash');
    });

    test('peak is reported, not the average or the last value', () {
      // A spike in the middle that a last-value or mean would erase.
      final records = [
        _resource(1, 100),
        _resource(2, 900),
        _resource(3, 120),
      ];

      final run = argosBuildListEntries(records).single as ArgosResourceRun;

      expect(run.peakRss, 900, reason: 'the spike must survive collapsing');
      expect(run.currentRss, 120, reason: 'current is where it settled');
    });

    test('no sample is dropped by aggregation', () {
      final records = <ArgosPacketRecord>[
        ...List.generate(7, (i) => _resource(i, 100 + i)),
        _network(50),
        ...List.generate(3, (i) => _resource(60 + i, 300)),
      ];

      final entries = argosBuildListEntries(records);
      final rendered = entries.fold<int>(
        0,
        (sum, e) => sum + (e is ArgosResourceRun ? e.count : 1),
      );

      expect(rendered, records.length);
    });

    test('an empty record list yields no entries', () {
      expect(argosBuildListEntries(const []), isEmpty);
    });
  });
}
