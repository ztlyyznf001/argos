import 'package:argos_inspector/argos_inspector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ArgosWidgetNode _node({
  required String path,
  required String type,
  required int depth,
  String? key,
  Rect? bounds,
  String description = '',
  List<ArgosWidgetProperty> properties = const <ArgosWidgetProperty>[],
  List<ArgosWidgetNode> children = const <ArgosWidgetNode>[],
}) {
  return ArgosWidgetNode(
    path: path,
    widgetType: type,
    key: key,
    depth: depth,
    description: description.isEmpty ? type : description,
    bounds: bounds,
    properties: properties,
    children: children,
  );
}

ArgosWidgetSnapshot _snapshot({
  String rootType = 'AppRoot',
  bool truncated = false,
}) {
  final root = _node(
    path: '0',
    type: rootType,
    depth: 0,
    key: '[root-key]',
    children: <ArgosWidgetNode>[
      _node(
        path: '0/0',
        type: 'CollapsedParent',
        depth: 1,
        children: <ArgosWidgetNode>[
          _node(
            path: '0/0/0',
            type: 'DeepLeaf',
            depth: 2,
            key: '[deep-key]',
            bounds: const Rect.fromLTWH(12, 24, 100, 40),
            properties: const <ArgosWidgetProperty>[
              ArgosWidgetProperty(name: 'label', value: 'Needle Value'),
            ],
          ),
        ],
      ),
      _node(path: '0/1', type: 'SiblingLeaf', depth: 1),
    ],
  );
  return ArgosWidgetSnapshot(
    capturedAt: DateTime(2026, 7, 22, 12, 34, 56),
    root: root,
    nodeCount: root.depthFirst.length,
    maxDepth: 80,
    maxNodes: 5000,
    truncated: truncated,
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  ArgosWidgetSnapshot? snapshot,
  ArgosWidgetSnapshotLoader? loader,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? ThemeData(splashFactory: InkRipple.splashFactory),
      home: ArgosWidgetInspectorPage(
        initialSnapshot: snapshot ?? _snapshot(),
        snapshotLoader: loader,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('ArgosWidgetInspectorPage', () {
    testWidgets('expands and collapses hierarchy rows', (tester) async {
      await _pumpPage(tester);

      expect(find.text('AppRoot'), findsOneWidget);
      expect(find.text('CollapsedParent'), findsOneWidget);
      expect(find.text('DeepLeaf'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('argos-widget-toggle-0/0')),
      );
      await tester.pump();
      expect(find.text('DeepLeaf'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('argos-widget-toggle-0/0')),
      );
      await tester.pump();
      expect(find.text('DeepLeaf'), findsNothing);
    });

    testWidgets('searches diagnostics case-insensitively and keeps ancestors',
        (tester) async {
      await _pumpPage(tester);

      await tester.enterText(
        find.byKey(const ValueKey<String>('argos-widget-search')),
        'nEeDlE vAlUe',
      );
      await tester.pump();

      expect(find.text('AppRoot'), findsOneWidget);
      expect(find.text('CollapsedParent'), findsOneWidget);
      expect(find.text('DeepLeaf'), findsOneWidget);
      expect(find.text('SiblingLeaf'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey<String>('argos-widget-search')),
        'not-present',
      );
      await tester.pump();
      expect(find.textContaining('没有匹配'), findsOneWidget);
      expect(find.byTooltip('刷新 Widget 快照'), findsOneWidget);
    });

    testWidgets('shows and closes complete node details', (tester) async {
      await _pumpPage(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('argos-widget-search')),
        'deep-key',
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey<String>('argos-widget-row-0/0/0')),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('argos-widget-detail')),
        findsOneWidget,
      );
      expect(
        find.text('AppRoot › CollapsedParent › DeepLeaf'),
        findsOneWidget,
      );
      expect(find.text('0/0/0'), findsNothing);
      expect(find.text('[deep-key]'), findsWidgets);
      expect(find.textContaining('100.0 × 40.0'), findsOneWidget);
      expect(find.text('Needle Value'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('argos-widget-detail-close')),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('argos-widget-detail')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('argos-widget-row-0')),
      );
      await tester.pump();
      expect(find.text('不可用'), findsOneWidget);
    });

    testWidgets('refresh replaces snapshot, clears detail, and keeps query',
        (tester) async {
      var refreshCount = 0;
      await _pumpPage(
        tester,
        snapshot: _snapshot(rootType: 'BeforeRoot'),
        loader: () {
          refreshCount++;
          return _snapshot(rootType: 'AfterRoot');
        },
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('argos-widget-search')),
        'root',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('argos-widget-row-0')),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('argos-widget-detail')),
        findsOneWidget,
      );

      tester
          .widget<IconButton>(
            find.byKey(
              const ValueKey<String>('argos-widget-inspector-refresh'),
            ),
          )
          .onPressed!();
      await tester.pump();

      expect(refreshCount, 1);
      expect(find.text('BeforeRoot'), findsNothing);
      expect(find.text('AfterRoot'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('argos-widget-detail')),
        findsNothing,
      );
      final search = tester.widget<TextField>(
        find.byKey(const ValueKey<String>('argos-widget-search')),
      );
      expect(search.controller!.text, 'root');
    });

    testWidgets('fits a narrow dark phone and reports truncation',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpPage(
        tester,
        snapshot: _snapshot(truncated: true),
        theme: ThemeData.dark(useMaterial3: true),
      );

      expect(
        find.byKey(const ValueKey<String>('argos-widget-truncation-notice')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
