import 'package:argos_inspector/argos_inspector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _HostCounter extends StatefulWidget {
  const _HostCounter();

  @override
  State<_HostCounter> createState() => _HostCounterState();
}

class _HostCounterState extends State<_HostCounter> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const ValueKey<String>('host-counter'),
          onPressed: () => setState(() => count++),
          child: Text('host count $count'),
        ),
      ),
    );
  }
}

Widget _app({
  required bool enabled,
  bool longPressInitiallyEnabled = false,
}) {
  return MaterialApp(
    theme: ThemeData(splashFactory: InkRipple.splashFactory),
    builder: (context, child) => ArgosWidgetInspector(
      enabled: enabled,
      longPressInitiallyEnabled: longPressInitiallyEnabled,
      child: child!,
    ),
    home: const _HostCounter(),
  );
}

void main() {
  group('ArgosWidgetInspector', () {
    testWidgets('disabled wrapper has no launcher and leaves host interactive',
        (tester) async {
      await tester.pumpWidget(_app(enabled: false));

      expect(
        find.byKey(const ValueKey<String>('argos-widget-inspector-launcher')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('argos-widget-long-press-area')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('argos-widget-long-press-switch')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey<String>('host-counter')));
      await tester.pump();
      expect(find.text('host count 1'), findsOneWidget);
    });

    testWidgets(
        'launcher opens without route registration and close keeps state',
        (tester) async {
      await tester.pumpWidget(_app(enabled: true));
      await tester.tap(find.byKey(const ValueKey<String>('host-counter')));
      await tester.pump();
      expect(find.text('host count 1'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('argos-widget-inspector-launcher')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Widget Inspector'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('argos-widget-inspector-launcher')),
        findsNothing,
      );
      expect(find.textContaining('个节点 ·'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('argos-widget-inspector-close')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Widget Inspector'), findsNothing);
      expect(find.text('host count 1'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('argos-widget-inspector-launcher')),
        findsOneWidget,
      );
    });

    testWidgets('disabled wrapper preserves the host long-press gesture',
        (tester) async {
      var longPressCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => ArgosWidgetInspector(
            enabled: false,
            child: child!,
          ),
          home: Scaffold(
            body: GestureDetector(
              key: const ValueKey<String>('host-long-press'),
              behavior: HitTestBehavior.opaque,
              onLongPress: () => longPressCount++,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );

      await tester.longPress(
        find.byKey(const ValueKey<String>('host-long-press')),
      );
      await tester.pump();

      expect(longPressCount, 1);
      expect(
        find.byKey(const ValueKey<String>('argos-widget-detail')),
        findsNothing,
      );
    });

    testWidgets('switch gates direct details and preserves host state',
        (tester) async {
      await tester.pumpWidget(_app(enabled: true));

      var modeSwitch = tester.widget<Switch>(
        find.byKey(const ValueKey<String>('argos-widget-long-press-switch')),
      );
      expect(modeSwitch.value, isFalse);
      await tester.tap(find.byKey(const ValueKey<String>('host-counter')));
      await tester.pump();
      expect(find.text('host count 1'), findsOneWidget);

      await tester.longPress(
        find.byKey(const ValueKey<String>('host-counter')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('argos-widget-detail')),
        findsNothing,
      );
      expect(find.text('host count 2'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('argos-widget-long-press-switch')),
      );
      await tester.pump();
      modeSwitch = tester.widget<Switch>(
        find.byKey(const ValueKey<String>('argos-widget-long-press-switch')),
      );
      expect(modeSwitch.value, isTrue);

      await tester.longPress(
        find.byKey(const ValueKey<String>('host-counter')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Widget Inspector'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('argos-widget-detail')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('argos-widget-highlight')),
        findsOneWidget,
      );
      expect(find.text('组件层级'), findsOneWidget);
      expect(find.textContaining('RichText'), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('argos-widget-tuning-editor')),
        findsNothing,
      );
      final highlightRect = tester.getRect(
        find.byKey(const ValueKey<String>('argos-widget-highlight')),
      );
      final detailRect = tester.getRect(
        find.byKey(const ValueKey<String>('argos-widget-detail')),
      );
      expect(highlightRect.overlaps(detailRect), isFalse);
      expect(
        find.byKey(const ValueKey<String>('argos-widget-inspector-launcher')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('argos-widget-detail-close')),
      );
      await tester.pumpAndSettle();
      final hostText = tester.widget<Text>(find.textContaining('host count'));
      expect(hostText.data, 'host count 2');
      await tester.tap(find.byKey(const ValueKey<String>('host-counter')));
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('argos-widget-detail')),
        findsNothing,
      );
      expect(find.text('host count 3'), findsOneWidget);
    });

    testWidgets('system back closes direct details before the host route',
        (tester) async {
      await tester.pumpWidget(
        _app(enabled: true, longPressInitiallyEnabled: true),
      );
      final modeSwitch = tester.widget<Switch>(
        find.byKey(const ValueKey<String>('argos-widget-long-press-switch')),
      );
      expect(modeSwitch.value, isTrue);
      await tester.longPress(
        find.byKey(const ValueKey<String>('host-counter')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('argos-widget-detail')),
        findsOneWidget,
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('argos-widget-detail')),
        findsNothing,
      );
      expect(find.text('host count 0'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('argos-widget-inspector-launcher')),
        findsOneWidget,
      );
    });

    testWidgets('system back closes inspector before changing the host route',
        (tester) async {
      await tester.pumpWidget(_app(enabled: true));
      await tester.tap(find.byKey(const ValueKey<String>('host-counter')));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('argos-widget-inspector-launcher')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Widget Inspector'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Widget Inspector'), findsNothing);
      expect(find.text('host count 1'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('argos-widget-inspector-launcher')),
        findsOneWidget,
      );
    });
  });
}
