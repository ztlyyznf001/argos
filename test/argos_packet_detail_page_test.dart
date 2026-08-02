import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:argos_inspector/model/argos_http_info_model.dart';
import 'package:argos_inspector/ui/argos_packet_detail_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ArgosPacketDetailPage', () {
    testWidgets('shows and copies the full formatted response body',
        (tester) async {
      String? clipboardText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform,
              (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          clipboardText = (methodCall.arguments as Map)['text'] as String?;
        }
        return null;
      });

      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      final payload = 'value-' * (18 * 1024);
      final responseBody = jsonEncode(<String, String>{'payload': payload});
      final expectedFormatted =
          const JsonEncoder.withIndent('  ').convert(jsonDecode(responseBody));
      final record = ArgosPacketRecord(
        id: '1',
        uri: 'https://example.com/large-response',
        method: 'GET',
        startTimestamp: 1,
        endTimestamp: 2,
        requestHeaders: const <String, String>{},
        requestBody: '',
        responseCode: 200,
        responseBody: responseBody,
        responseHeaders: const <String, String>{
          'content-type': 'application/json',
        },
        responseSize: responseBody.length,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(useMaterial3: true)
              .copyWith(splashFactory: NoSplash.splashFactory),
          home: ArgosPacketDetailPage(record: record),
        ),
      );

      await tester.tap(find.text('响应'));
      await tester.pumpAndSettle();

      expect(find.text(expectedFormatted), findsOneWidget);
      expect(find.textContaining('[TRUNCATED]'), findsNothing);

      await tester.tap(find.byTooltip('复制响应体'));
      await tester.pump();

      expect(clipboardText, expectedFormatted);
    });
  });
}
