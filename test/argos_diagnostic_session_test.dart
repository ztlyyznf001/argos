import 'package:flutter_test/flutter_test.dart';
import 'package:argos_inspector/argos_inspector.dart';

void main() {
  group('ArgosDiagnosticSession', () {
    test('round-trips all fields and ignores unknown fields', () {
      const session = ArgosDiagnosticSession(
        id: 'session-1',
        startedAt: 10,
        endedAt: 20,
        lastEventAt: 18,
        label: 'repro',
        note: 'checkout',
        attributes: <String, String>{'build': '42'},
        endReason: ArgosSessionEndReason.completed,
        truncated: true,
      );

      final json = session.toJson()..['futureField'] = 'ignored';
      final decoded = ArgosDiagnosticSession.fromJson(json);

      expect(decoded.id, session.id);
      expect(decoded.startedAt, session.startedAt);
      expect(decoded.endedAt, session.endedAt);
      expect(decoded.lastEventAt, session.lastEventAt);
      expect(decoded.label, session.label);
      expect(decoded.note, session.note);
      expect(decoded.attributes, session.attributes);
      expect(decoded.endReason, session.endReason);
      expect(decoded.truncated, isTrue);
    });

    test('unknown end reason degrades to null', () {
      final decoded = ArgosDiagnosticSession.fromJson(<String, dynamic>{
        'id': 'future',
        'startedAt': 1,
        'endReason': 'future-reason',
      });

      expect(decoded.endReason, isNull);
    });
  });

  test('event metadata round-trips', () {
    const metadata = ArgosEventMetadata(
      id: 'session-1:3',
      sessionId: 'session-1',
      sequence: 3,
    );
    final decoded = ArgosEventMetadata.fromJson(metadata.toJson());

    expect(decoded.id, metadata.id);
    expect(decoded.sessionId, metadata.sessionId);
    expect(decoded.sequence, metadata.sequence);
  });

  test('legacy packet JSON keeps id and defaults session fields', () {
    final record = ArgosPacketRecord.fromJson(<String, dynamic>{
      'id': 'legacy-id',
      'uri': 'https://example.com',
      'method': 'GET',
      'startTimestamp': 1,
      'endTimestamp': 2,
    });

    expect(record.id, 'legacy-id');
    expect(record.sessionId, isNull);
    expect(record.sequence, 0);
    expect(record.routeName, '');
  });

  test('packet copyWith is immutable and can assign session identity', () {
    final original = _record('legacy', 1);
    final assigned = original.copyWith(
      id: 'session:1',
      sessionId: 'session',
      sequence: 1,
      routeName: '/home',
    );

    expect(original.id, 'legacy');
    expect(original.sessionId, isNull);
    expect(assigned.id, 'session:1');
    expect(assigned.sessionId, 'session');
    expect(assigned.sequence, 1);
    expect(assigned.routeName, '/home');
  });

  test('config exposes backward-compatible session defaults', () {
    final config = ArgosConfig();

    expect(config.sessionMode, ArgosSessionMode.automatic);
    expect(
      config.automaticSessionPolicy.strategy,
      ArgosAutomaticSessionStrategy.process,
    );
    expect(config.automaticSessionPolicy.backgroundTimeout, isNull);
    expect(config.automaticSessionPolicy.maxDuration, isNull);
    expect(config.maxSessions, 5);
    expect(config.maxPacketRecords, 200);
    expect(config.resourceMaxRecords, 50);
  });

  test('config rejects invalid quotas in checked mode', () {
    expect(() => ArgosConfig(maxSessions: 0), throwsAssertionError);
    expect(() => ArgosConfig(maxPacketRecords: 0), throwsAssertionError);
    expect(() => ArgosConfig(resourceMaxRecords: 0), throwsAssertionError);
  });

  test('adaptive policy exposes defaults and supports disabled boundaries', () {
    final defaults = ArgosAutomaticSessionPolicy.adaptive();
    final disabled = ArgosAutomaticSessionPolicy.adaptive(
      backgroundTimeout: null,
      maxDuration: null,
    );

    expect(defaults.strategy, ArgosAutomaticSessionStrategy.adaptive);
    expect(defaults.backgroundTimeout, const Duration(minutes: 2));
    expect(defaults.maxDuration, const Duration(minutes: 30));
    expect(disabled.backgroundTimeout, isNull);
    expect(disabled.maxDuration, isNull);
  });

  test('adaptive policy rejects zero and negative durations', () {
    expect(
      () => ArgosAutomaticSessionPolicy.adaptive(
        backgroundTimeout: Duration.zero,
      ),
      throwsAssertionError,
    );
    expect(
      () => ArgosAutomaticSessionPolicy.adaptive(
        maxDuration: const Duration(seconds: -1),
      ),
      throwsAssertionError,
    );
  });

  test(
      'session context validates fingerprint and defensively copies attributes',
      () {
    final source = <String, String>{'tenant': 'alpha'};
    final context = ArgosSessionContext(
      fingerprint: 'user-1|tenant-alpha',
      attributes: source,
    );
    source['tenant'] = 'beta';

    expect(context.fingerprint, 'user-1|tenant-alpha');
    expect(context.attributes, <String, String>{'tenant': 'alpha'});
    expect(
      () => context.attributes['tenant'] = 'changed',
      throwsUnsupportedError,
    );
    expect(
      () => ArgosSessionContext(fingerprint: ''),
      throwsAssertionError,
    );
  });

  test('all known session end reasons round-trip', () {
    for (final reason in ArgosSessionEndReason.values) {
      final decoded = ArgosDiagnosticSession.fromJson(
        ArgosDiagnosticSession(
          id: reason.name,
          startedAt: 1,
          endedAt: 2,
          endReason: reason,
        ).toJson(),
      );

      expect(decoded.endReason, reason);
    }
  });
}

ArgosPacketRecord _record(String id, int timestamp) => ArgosPacketRecord(
      id: id,
      uri: 'https://example.com',
      method: 'GET',
      startTimestamp: timestamp,
      endTimestamp: timestamp,
      requestHeaders: const <String, String>{},
      requestBody: '',
      responseCode: 200,
      responseBody: '',
      responseHeaders: const <String, String>{},
      responseSize: 0,
    );
