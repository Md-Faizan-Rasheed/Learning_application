import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/utils/radial_layout.dart';
import 'package:islamic_game/widgets/constellation_map.dart';

void main() {
  Future<void> pumpMap(WidgetTester tester, List<RadialNode> nodes) async {
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true, size: Size(400, 400)),
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 320,
            child: ConstellationMap(nodes: nodes, twinklePhase: 0),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping a node with onTap fires it', (tester) async {
    var tapped = false;
    await pumpMap(tester, [
      const RadialNode(label: 'Anchor', ring: 0),
      RadialNode(label: 'Category', ring: 1, onTap: () => tapped = true),
    ]);

    await tester.tap(find.text('Category'));
    expect(tapped, isTrue);
  });

  testWidgets('the ring-0 anchor renders without a tap handler', (tester) async {
    await pumpMap(tester, const [RadialNode(label: 'Anchor', ring: 0)]);

    final gestureDetector = tester.widget<GestureDetector>(
      find.ancestor(of: find.text('Anchor'), matching: find.byType(GestureDetector)).first,
    );
    expect(gestureDetector.onTap, isNull);
    expect(gestureDetector.onTapDown, isNull);
  });

  testWidgets('a visited non-anchor node shows a check badge, an unvisited one does not',
      (tester) async {
    await pumpMap(tester, [
      const RadialNode(label: 'Anchor', ring: 0),
      RadialNode(label: 'Seen', ring: 1, onTap: () {}, visited: true),
      RadialNode(label: 'Unseen', ring: 1, onTap: () {}, visited: false),
    ]);

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });
}
