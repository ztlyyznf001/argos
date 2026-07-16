import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:argos/model/argos_http_info_model.dart';
import 'package:argos/ui/argos_packet_detail_page.dart';

ArgosPacketRecord _record({
  required String kind,
  String uri = 'event',
  String method = '-',
  int responseCode = 0,
  String responseBody = '',
  Map<String, String> responseHeaders = const {},
  String? error,
}) {
  return ArgosPacketRecord(
    id: '1',
    uri: uri,
    method: method,
    startTimestamp: 1000,
    endTimestamp: 1000,
    requestHeaders: const {},
    requestBody: '',
    responseCode: responseCode,
    responseBody: responseBody,
    responseHeaders: responseHeaders,
    responseSize: 0,
    error: error,
    kind: kind,
  );
}

Future<void> _pump(WidgetTester tester, ArgosPacketRecord record) async {
  await tester.pumpWidget(
    MaterialApp(home: ArgosPacketDetailPage(record: record)),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ArgosPacketDetailPage dispatches on kind', () {
    testWidgets('network records keep the request/response tabs',
        (tester) async {
      await _pump(
        tester,
        _record(
          kind: 'network',
          uri: 'https://example.com/a',
          method: 'GET',
          responseCode: 200,
        ),
      );

      expect(find.text('请求'), findsOneWidget);
      expect(find.text('响应'), findsOneWidget);
      expect(find.byTooltip('复制 cURL'), findsOneWidget);
    });

    testWidgets('crash shows message and stack, and no request/response tabs',
        (tester) async {
      await _pump(
        tester,
        _record(
          kind: 'crash',
          uri: 'Null check operator used on a null value',
          error: 'Null check operator used on a null value',
          responseBody: '#0 main (file:///app/main.dart:1:1)',
        ),
      );

      // The tabs were empty for a crash — their absence is the point.
      expect(find.text('请求'), findsNothing);
      expect(find.text('响应'), findsNothing);

      expect(find.text('崩溃'), findsOneWidget);
      expect(find.text('堆栈'), findsOneWidget);
      expect(find.byTooltip('复制堆栈'), findsOneWidget);
      expect(find.textContaining('#0 main'), findsOneWidget);
      // cURL is meaningless for a crash.
      expect(find.byTooltip('复制 cURL'), findsNothing);
    });

    testWidgets('jank shows the build/raster split', (tester) async {
      await _pump(
        tester,
        _record(
          kind: 'jank',
          uri: '丢帧 4，最大 48.0 ms',
          responseCode: 4,
          responseBody: 'build=30.0ms\n'
              'raster=12.0ms\n'
              'maxFrame=48.0ms\n'
              'total=90.0ms\n'
              'droppedFrames=4',
        ),
      );

      expect(find.text('请求'), findsNothing);
      expect(find.text('响应'), findsNothing);

      expect(find.text('卡顿'), findsOneWidget);
      expect(find.text('4 帧'), findsOneWidget);
      expect(find.textContaining('30.0 ms'), findsOneWidget);
      expect(find.textContaining('12.0 ms'), findsOneWidget);
      // build (30ms) dominates raster (12ms), so the UI thread is the culprit.
      expect(find.text('瓶颈偏向 UI 线程'), findsOneWidget);
    });

    testWidgets('resource shows RSS and leaves CPU blank when unavailable',
        (tester) async {
      await _pump(
        tester,
        _record(
          kind: 'resource',
          uri: 'RSS 120.0 MB',
          responseHeaders: const {
            'currentRss': '125829120', // 120 MB
            'maxRss': '157286400', // 150 MB
          },
        ),
      );

      expect(find.text('请求'), findsNothing);
      expect(find.text('响应'), findsNothing);

      expect(find.text('资源'), findsOneWidget);
      expect(find.text('120.0 MB'), findsOneWidget);
      expect(find.text('150.0 MB'), findsOneWidget);
      // The monitor reports nothing rather than guessing; the UI must not
      // invent a placeholder number.
      expect(find.text('不可用'), findsOneWidget);
    });
  });
}
