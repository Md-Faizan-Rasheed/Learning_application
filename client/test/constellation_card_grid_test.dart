import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/utils/radial_layout.dart';
import 'package:islamic_game/widgets/constellation_card_grid.dart';

void main() {
  Future<void> pumpGrid(WidgetTester tester, List<RadialNode> nodes) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SizedBox(width: 360, height: 640, child: ConstellationCardGrid(nodes: nodes))),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('the ring-0 anchor is not rendered as a card', (tester) async {
    await pumpGrid(tester, const [
      RadialNode(label: 'Find My Ayah', ring: 0),
      RadialNode(label: 'Faith', ring: 1),
    ]);

    expect(find.text('Find My Ayah'), findsNothing);
    expect(find.text('Faith'), findsOneWidget);
  });

  testWidgets('tapping a card fires its onTap', (tester) async {
    var tapped = false;
    await pumpGrid(tester, [
      const RadialNode(label: 'Anchor', ring: 0),
      RadialNode(label: 'Faith', ring: 1, onTap: () => tapped = true),
    ]);

    await tester.tap(find.text('Faith'));
    expect(tapped, isTrue);
  });

  testWidgets('a visited card shows a check badge, an unvisited one does not', (tester) async {
    await pumpGrid(tester, [
      const RadialNode(label: 'Anchor', ring: 0),
      RadialNode(label: 'Seen', ring: 1, onTap: () {}, visited: true),
      RadialNode(label: 'Unseen', ring: 1, onTap: () {}, visited: false),
    ]);

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });
}
