import 'package:argos_inspector/argos_inspector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<ArgosTuningProperty> _properties({double max = 100}) {
  return <ArgosTuningProperty>[
    ArgosDoubleTuningProperty(
      id: 'size',
      label: '尺寸',
      initialValue: 20,
      min: 10,
      max: max,
      divisions: 9,
      decimalPlaces: 0,
    ),
    const ArgosColorTuningProperty(
      id: 'color',
      label: '颜色',
      initialValue: Colors.deepPurple,
    ),
    const ArgosColorTuningProperty(
      id: 'textColor',
      label: '字体颜色',
      initialValue: Colors.black,
    ),
  ];
}

Widget _tuningApp({
  required bool enabled,
  required ArgosTuningController controller,
  required List<ArgosTuningProperty> properties,
  int parentRevision = 0,
}) {
  return MaterialApp(
    builder: (context, child) => ArgosWidgetInspector(
      enabled: enabled,
      tuningController: controller,
      child: child!,
    ),
    home: Scaffold(
      body: Center(
        child: ArgosTunable(
          key: const ValueKey<String>('tunable'),
          id: 'sample',
          label: '示例卡片',
          properties: properties,
          builder: (context, values) {
            final size = values.doubleValue('size');
            final color = values.colorValue('color');
            return Container(
              key: const ValueKey<String>('tuned-box'),
              width: size,
              height: size,
              color: color,
              alignment: Alignment.center,
              child: Text('size ${size.toStringAsFixed(0)} / $parentRevision'),
            );
          },
        ),
      ),
    ),
  );
}

void main() {
  group('runtime widget tuning', () {
    testWidgets('uses defaults and does not register without an enabled scope',
        (tester) async {
      final controller = ArgosTuningController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _tuningApp(
          enabled: false,
          controller: controller,
          properties: _properties(),
        ),
      );

      expect(find.text('size 20 / 0'), findsOneWidget);
      expect(controller.target('sample'), isNull);
      expect(controller.updateValue('sample', 'size', 50.0), isFalse);
    });

    testWidgets(
        'updates, clamps, accepts custom colors, and resets live values',
        (tester) async {
      final controller = ArgosTuningController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _tuningApp(
          enabled: true,
          controller: controller,
          properties: _properties(),
        ),
      );

      expect(controller.target('sample'), isNotNull);
      expect(controller.updateValue('sample', 'size', 500.0), isTrue);
      await tester.pump();
      expect(find.text('size 100 / 0'), findsOneWidget);

      expect(
        controller.updateValue('sample', 'color', Colors.orange),
        isTrue,
      );
      expect(
        controller.updateValue('sample', 'color', Colors.green),
        isTrue,
      );
      expect(controller.updateValue('sample', 'color', '#00ff00'), isFalse);
      expect(controller.updateValue('sample', 'missing', 1.0), isFalse);
      await tester.pump();
      final box = tester.widget<Container>(
        find.byKey(const ValueKey<String>('tuned-box')),
      );
      expect(box.color, Colors.green);

      expect(controller.resetTarget('sample'), isTrue);
      await tester.pump();
      expect(find.text('size 20 / 0'), findsOneWidget);
      final resetBox = tester.widget<Container>(
        find.byKey(const ValueKey<String>('tuned-box')),
      );
      expect(resetBox.color, Colors.deepPurple);
    });

    testWidgets('keeps overrides across parent rebuilds and reconciles schema',
        (tester) async {
      final controller = ArgosTuningController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _tuningApp(
          enabled: true,
          controller: controller,
          properties: _properties(),
        ),
      );
      controller.updateValue('sample', 'size', 90.0);
      await tester.pump();

      await tester.pumpWidget(
        _tuningApp(
          enabled: true,
          controller: controller,
          properties: _properties(),
          parentRevision: 1,
        ),
      );
      await tester.pump();
      expect(find.text('size 90 / 1'), findsOneWidget);

      await tester.pumpWidget(
        _tuningApp(
          enabled: true,
          controller: controller,
          properties: _properties(max: 50),
          parentRevision: 2,
        ),
      );
      await tester.pump();
      expect(find.text('size 50 / 2'), findsOneWidget);
      expect(
        controller.target('sample')!.values.doubleValue('size'),
        50,
      );
    });

    testWidgets('discovers the smallest nested mounted target', (tester) async {
      final controller = ArgosTuningController();
      addTearDown(controller.dispose);
      const property = ArgosDoubleTuningProperty(
        id: 'size',
        label: '尺寸',
        initialValue: 20,
        min: 10,
        max: 100,
      );

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => ArgosWidgetInspector(
            enabled: true,
            tuningController: controller,
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: ArgosTunable(
                id: 'outer',
                label: '外层',
                properties: const <ArgosTuningProperty>[property],
                builder: (context, values) => SizedBox(
                  key: const ValueKey<String>('outer-box'),
                  width: 300,
                  height: 300,
                  child: Center(
                    child: ArgosTunable(
                      id: 'inner',
                      label: '内层',
                      properties: const <ArgosTuningProperty>[property],
                      builder: (context, values) => const SizedBox(
                        key: ValueKey<String>('inner-box'),
                        width: 80,
                        height: 80,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final innerPoint = tester.getCenter(
        find.byKey(const ValueKey<String>('inner-box')),
      );
      expect(controller.targetAt(innerPoint)?.id, 'inner');

      final outerRect = tester.getRect(
        find.byKey(const ValueKey<String>('outer-box')),
      );
      expect(
        controller.targetAt(outerRect.topLeft + const Offset(20, 20))?.id,
        'outer',
      );
    });

    testWidgets('switching controllers drops the previous runtime overrides',
        (tester) async {
      final first = ArgosTuningController();
      final second = ArgosTuningController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await tester.pumpWidget(
        _tuningApp(
          enabled: true,
          controller: first,
          properties: _properties(),
        ),
      );
      first.updateValue('sample', 'size', 80.0);
      await tester.pump();
      expect(find.text('size 80 / 0'), findsOneWidget);

      await tester.pumpWidget(
        _tuningApp(
          enabled: true,
          controller: second,
          properties: _properties(),
        ),
      );
      await tester.pump();

      expect(first.target('sample'), isNull);
      expect(second.target('sample'), isNotNull);
      expect(find.text('size 20 / 0'), findsOneWidget);
    });

    testWidgets('long-press details edit arbitrary colors and reset target',
        (tester) async {
      final controller = ArgosTuningController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => ArgosWidgetInspector(
            enabled: true,
            longPressInitiallyEnabled: true,
            tuningController: controller,
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: ArgosTunable(
                id: 'editable',
                label: '可调卡片',
                properties: _properties(),
                builder: (context, values) => Container(
                  key: const ValueKey<String>('editable-box'),
                  width: 180,
                  height: 120,
                  color: values.colorValue('color'),
                  alignment: Alignment.center,
                  child: Text(
                    'editable ${values.doubleValue('size').toStringAsFixed(0)}',
                    key: const ValueKey<String>('editable-text'),
                    style: TextStyle(
                      color: values.colorValue('textColor'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.longPress(
        find.byKey(const ValueKey<String>('editable-box')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('argos-widget-tuning-editor')),
        findsOneWidget,
      );
      expect(find.text('可调卡片'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('argos-widget-tuning-color-tabs-editable'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>(
            'argos-widget-tuning-color-editable-textColor-hex',
          ),
        ),
        findsNothing,
      );
      final sliderFinder = find.byKey(
        const ValueKey<String>(
          'argos-widget-tuning-slider-editable-size',
        ),
      );
      final slider = tester.widget<Slider>(sliderFinder);
      slider.onChanged!(70);
      await tester.pump();
      expect(find.text('editable 70'), findsOneWidget);
      expect(find.text('70'), findsOneWidget);

      final hexFinder = find.byKey(
        const ValueKey<String>(
          'argos-widget-tuning-color-editable-color-hex',
        ),
      );
      await tester.ensureVisible(hexFinder);
      await tester.enterText(hexFinder, '#FF123456');
      await tester.pump();
      final editedBox = tester.widget<Container>(
        find.byKey(const ValueKey<String>('editable-box')),
      );
      expect(editedBox.color, const Color(0xFF123456));

      final hueFinder = find.byKey(
        const ValueKey<String>(
          'argos-widget-tuning-color-editable-color-hue',
        ),
      );
      await tester.ensureVisible(hueFinder);
      final hue = tester.widget<Slider>(hueFinder);
      hue.onChanged!(120);
      await tester.pump();
      expect(
        controller.target('editable')!.values.colorValue('color'),
        isNot(const Color(0xFF123456)),
      );

      final backgroundBlueFinder = find.byKey(
        const ValueKey<String>(
          'argos-widget-tuning-color-editable-color-quick-FF2196F3',
        ),
      );
      tester.widget<InkWell>(backgroundBlueFinder).onTap!();
      await tester.pump();
      expect(
        controller.target('editable')!.values.colorValue('color'),
        const Color(0xFF2196F3),
      );

      final textColorTabFinder = find.byKey(
        const ValueKey<String>(
          'argos-widget-tuning-color-tabs-editable-textColor',
        ),
      );
      expect(textColorTabFinder, findsOneWidget);
      final colorTabs = tester.widget<TabBar>(
        find.byKey(
          const ValueKey<String>('argos-widget-tuning-color-tabs-editable'),
        ),
      );
      colorTabs.controller!.animateTo(1);
      await tester.pumpAndSettle();
      expect(hexFinder, findsNothing);
      expect(
        controller.target('editable')!.values.colorValue('color'),
        const Color(0xFF2196F3),
      );
      expect(
        controller.target('editable')!.values.colorValue('textColor'),
        Colors.black,
      );

      final textWhiteFinder = find.byKey(
        const ValueKey<String>(
          'argos-widget-tuning-color-editable-textColor-quick-FFFFFFFF',
        ),
      );
      tester.widget<InkWell>(textWhiteFinder).onTap!();
      await tester.pump();
      final editedText = tester.widget<Text>(
        find.byKey(const ValueKey<String>('editable-text')),
      );
      expect(editedText.style?.color, Colors.white);
      expect(
        controller.target('editable')!.values.colorValue('color'),
        const Color(0xFF2196F3),
      );

      final resetFinder = find.byKey(
        const ValueKey<String>('argos-widget-tuning-reset'),
      );
      final reset = tester.widget<TextButton>(resetFinder);
      reset.onPressed!();
      await tester.pump();
      expect(find.text('editable 20'), findsOneWidget);
      final resetBox = tester.widget<Container>(
        find.byKey(const ValueKey<String>('editable-box')),
      );
      expect(resetBox.color, Colors.deepPurple);
      final resetText = tester.widget<Text>(
        find.byKey(const ValueKey<String>('editable-text')),
      );
      expect(resetText.style?.color, Colors.black);
    });
  });
}
