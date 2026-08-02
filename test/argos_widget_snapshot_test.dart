import 'package:argos_inspector/argos_inspector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ArgosWidgetSnapshot', () {
    test('finds the deepest bounded node at a global position', () {
      final frontLeaf = ArgosWidgetNode(
        path: '0/1/0',
        widgetType: 'FrontLeaf',
        depth: 2,
        description: 'front leaf',
        bounds: const Rect.fromLTWH(40, 40, 20, 20),
      );
      final root = ArgosWidgetNode(
        path: '0',
        widgetType: 'Root',
        depth: 0,
        description: 'root',
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        children: <ArgosWidgetNode>[
          ArgosWidgetNode(
            path: '0/0',
            widgetType: 'BackSibling',
            depth: 1,
            description: 'back',
            bounds: const Rect.fromLTWH(20, 20, 60, 60),
          ),
          ArgosWidgetNode(
            path: '0/1',
            widgetType: 'FrontParent',
            depth: 1,
            description: 'front',
            bounds: const Rect.fromLTWH(20, 20, 60, 60),
            children: <ArgosWidgetNode>[frontLeaf],
          ),
        ],
      );
      final snapshot = ArgosWidgetSnapshot(
        capturedAt: DateTime(2026),
        root: root,
        nodeCount: 4,
        maxDepth: 200,
        maxNodes: 5000,
        truncated: false,
      );

      expect(snapshot.deepestNodeAt(const Offset(50, 50)), same(frontLeaf));
      expect(
        snapshot.widgetBreadcrumbFor(frontLeaf),
        'Root › FrontParent › FrontLeaf',
      );
      expect(
        snapshot.widgetBreadcrumbFor(frontLeaf, maxSegments: 2),
        '… › FrontParent › FrontLeaf',
      );
      expect(
        snapshot.deepestNodeAt(const Offset(30, 30))?.widgetType,
        'FrontParent',
      );
      expect(snapshot.deepestNodeAt(const Offset(120, 120)), isNull);
    });

    testWidgets('captures immutable hierarchy metadata and render bounds',
        (tester) async {
      final captureKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              key: captureKey,
              children: const <Widget>[
                Text('captured label', key: ValueKey<String>('label-key')),
                SizedBox(width: 40, height: 20),
              ],
            ),
          ),
        ),
      );

      final snapshot = ArgosWidgetSnapshot.capture(
        captureKey.currentContext! as Element,
      );
      final bindingSnapshot = ArgosWidgetSnapshot.captureBindingRoot();
      final root = snapshot.root!;
      final textNode = root.depthFirst.firstWhere(
        (node) => node.widgetType == 'Text',
      );

      expect(snapshot.nodeCount, greaterThanOrEqualTo(3));
      expect(bindingSnapshot, isNotNull);
      expect(bindingSnapshot!.nodeCount, greaterThan(snapshot.nodeCount));
      expect(snapshot.truncated, isFalse);
      expect(root.widgetType, 'Column');
      expect(root.path, '0');
      expect(root.depth, 0);
      expect(root.bounds, isNotNull);
      expect(root.bounds!.width, greaterThan(0));
      expect(textNode.path, startsWith('0/'));
      expect(textNode.depth, greaterThan(0));
      expect(textNode.key, contains('label-key'));
      expect(textNode.matches('CAPTURED LABEL'), isTrue);

      expect(
        () => root.children.add(
          ArgosWidgetNode(
            path: 'x',
            widgetType: 'NeverAdded',
            depth: 1,
            description: '',
          ),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => textNode.properties.add(
          const ArgosWidgetProperty(name: 'x', value: 'y'),
        ),
        throwsUnsupportedError,
      );
    });

    testWidgets('reports depth and node count truncation', (tester) async {
      final captureKey = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            key: captureKey,
            children: const <Widget>[
              Padding(
                padding: EdgeInsets.all(4),
                child: Text('one'),
              ),
              Text('two'),
              Text('three'),
            ],
          ),
        ),
      );
      final element = captureKey.currentContext! as Element;

      final depthLimited = ArgosWidgetSnapshot.capture(element, maxDepth: 0);
      expect(depthLimited.nodeCount, 1);
      expect(depthLimited.root!.children, isEmpty);
      expect(depthLimited.truncated, isTrue);

      final countLimited = ArgosWidgetSnapshot.capture(element, maxNodes: 2);
      expect(countLimited.nodeCount, 2);
      expect(countLimited.truncated, isTrue);
    });

    testWidgets('excludes requested subtrees without aborting siblings',
        (tester) async {
      final captureKey = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            key: captureKey,
            children: const <Widget>[
              Text('keep me', key: ValueKey<String>('keep-one')),
              Column(
                key: ValueKey<String>('excluded'),
                children: <Widget>[Text('secret descendant')],
              ),
              Text('keep me too', key: ValueKey<String>('keep-two')),
            ],
          ),
        ),
      );

      final snapshot = ArgosWidgetSnapshot.capture(
        captureKey.currentContext! as Element,
        excludeElement: (element) =>
            element.widget.key == const ValueKey<String>('excluded'),
      );
      final nodes = snapshot.root!.depthFirst.toList();

      expect(
          nodes.any((node) => node.key?.contains('keep-one') ?? false), isTrue);
      expect(
          nodes.any((node) => node.key?.contains('keep-two') ?? false), isTrue);
      expect(nodes.any((node) => node.matches('secret descendant')), isFalse);
    });
  });
}
