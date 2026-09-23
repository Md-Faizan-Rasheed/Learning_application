import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/utils/tree_page_route.dart';

void main() {
  testWidgets('the zoom transition genuinely interpolates mid-flight, not an instant snap',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => Navigator.of(context).push(
            buildTreeRoute((_) => const Scaffold(body: Text('destination'))),
          ),
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    // Sample partway through the transition (well short of its ~420ms
    // duration) — if this ever regresses to an instant cut, the scale
    // value here will be exactly 1.0 instead of strictly between bounds.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final scales = tester
        .widgetList<ScaleTransition>(find.byType(ScaleTransition))
        .map((w) => w.scale.value)
        .toList();

    expect(
      scales.any((v) => v > 0.55 && v < 1.0),
      isTrue,
      reason: 'the entering screen should be strictly between 0.55 and 1.0 mid-flight, '
          'not already settled — got: $scales',
    );

    await tester.pumpAndSettle();
    expect(find.text('destination'), findsOneWidget);
  });
}
