import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:argos/model/argos_http_info_model.dart';

class _FakeHttpHeaders implements HttpHeaders {
  @override
  void forEach(void Function(String name, List<String> values) action) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ArgosPacketRecord routeName serialization', () {
    test('routeName is serialized to JSON', () {
      final record = ArgosPacketRecord(
        id: '1',
        uri: 'https://example.com',
        method: 'GET',
        startTimestamp: 0,
        endTimestamp: 0,
        requestHeaders: {},
        requestBody: '',
        responseCode: 200,
        responseBody: '',
        responseHeaders: {},
        responseSize: 0,
        routeName: '/home',
      );
      final json = record.toJson();
      expect(json['routeName'], '/home');
    });

    test('routeName defaults to empty string when absent in JSON', () {
      final json = <String, dynamic>{
        'id': '1',
        'uri': 'https://example.com',
        'method': 'GET',
        'startTimestamp': 0,
        'endTimestamp': 0,
        'requestHeaders': {},
        'requestBody': '',
        'responseCode': 200,
        'responseBody': '',
        'responseHeaders': {},
        'responseSize': 0,
        // 'routeName' intentionally absent (old record format)
      };
      final record = ArgosPacketRecord.fromJson(json);
      expect(record.routeName, '');
    });

    test('routeName round-trips through toJson/fromJson', () {
      final record = ArgosPacketRecord(
        id: '2',
        uri: 'https://example.com/detail',
        method: 'POST',
        startTimestamp: 1000,
        endTimestamp: 1500,
        requestHeaders: {},
        requestBody: '{}',
        responseCode: 201,
        responseBody: '{"ok":true}',
        responseHeaders: {},
        responseSize: 11,
        routeName: '/detail/123',
      );
      final restored = ArgosPacketRecord.fromJson(record.toJson());
      expect(restored.routeName, '/detail/123');
    });
  });

  group('ArgosHttpInfo.toJson', () {
    test('keeps large text responses intact', () {
      final info = ArgosHttpInfo(Uri.parse('https://example.com/large'), 'GET');
      final responseBody = 'x' * (120 * 1024);

      info.response
          .update(200, responseBody, _FakeHttpHeaders(), responseBody.length);

      final json = info.toJson();

      expect(json['responseBody'], responseBody);
      expect((json['responseBody'] as String).endsWith('[TRUNCATED]'), isFalse);
    });

    test('still truncates large request bodies', () {
      final info =
          ArgosHttpInfo(Uri.parse('https://example.com/request'), 'POST');
      final requestBody = 'r' * (120 * 1024);

      info.request.add(requestBody);

      final json = info.toJson();
      final storedRequestBody = json['requestBody'] as String;

      expect(storedRequestBody, endsWith('[TRUNCATED]'));
      expect(storedRequestBody.length, (100 * 1024) + '[TRUNCATED]'.length);
      expect(storedRequestBody.startsWith('r' * 32), isTrue);
    });
  });
}
