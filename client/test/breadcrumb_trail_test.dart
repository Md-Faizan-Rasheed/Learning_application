import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/widgets/breadcrumb_trail.dart';

void main() {
  testWidgets('renders every item, separated by chevrons', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: BreadcrumbTrail(items: [
          BreadcrumbItem(label: 'Home'),
          BreadcrumbItem(label: 'Faith'),
        ]),
      ),
    ));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Faith'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
  });

  testWidgets('tapping an ancestor crumb fires its onTap; the current crumb has none', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BreadcrumbTrail(items: [
          BreadcrumbItem(label: 'Home', onTap: () => tapped = true),
          const BreadcrumbItem(label: 'Faith'),
        ]),
      ),
    ));

    await tester.tap(find.text('Home'));
    expect(tapped, isTrue);

    // The current (last) crumb has no onTap — tapping it is a no-op, not
    // an error.
    await tester.tap(find.text('Faith'));
    await tester.pump();
  });
}
