import 'package:argos_inspector/argos_inspector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:argos_example/main.dart';

void main() {
  testWidgets('example exposes the debug widget inspector launcher',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Plugin example app'), findsOneWidget);
    expect(find.text('长按我实时调参'), findsOneWidget);
    final tunable = tester.widget<ArgosTunable>(find.byType(ArgosTunable));
    final colorIds = tunable.properties
        .whereType<ArgosColorTuningProperty>()
        .map((property) => property.id);
    expect(colorIds, containsAll(<String>['color', 'textColor']));
    expect(find.byKey(const ValueKey('argos-widget-inspector-launcher')),
        findsOneWidget);
  });
}
