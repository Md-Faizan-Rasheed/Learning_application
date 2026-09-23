import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/l10n/app_localizations.dart';
import 'package:islamic_game/utils/situation_data.dart';
import 'package:islamic_game/widgets/situation_search_sheet.dart';

void main() {
  const categories = [
    Category(id: 'trials', label: 'Trials', situations: [
      Situation(
        id: 'losing_a_job',
        label: 'Losing a job',
        keywords: ['unemployed', 'fired', 'career', 'income'],
        refs: [Reference(type: 'ayah', arabic: '', gloss: 'g', citation: 'c')],
      ),
      Situation(
        id: 'illness',
        label: 'Illness',
        keywords: ['sick', 'disease'],
        refs: [Reference(type: 'ayah', arabic: '', gloss: 'g', citation: 'c')],
      ),
    ]),
  ];

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showSituationSearchSheet(context, categories: categories),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('typing a keyword (not the label) still surfaces the matching situation',
      (tester) async {
    await pumpSheet(tester);

    await tester.enterText(find.byType(TextField), 'unemployed');
    await tester.pumpAndSettle();

    expect(find.text('Losing a job'), findsOneWidget);
    expect(find.text('Illness'), findsNothing);
  });

  testWidgets('typing the exact label still works as before', (tester) async {
    await pumpSheet(tester);

    await tester.enterText(find.byType(TextField), 'Illness');
    await tester.pumpAndSettle();

    // Two matches for the literal text "Illness" now: the TextField's own
    // typed value, and the result ListTile — scope to the result list.
    expect(find.widgetWithText(ListTile, 'Illness'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Losing a job'), findsNothing);
  });

  testWidgets('a term matching nothing shows the no-results state', (tester) async {
    await pumpSheet(tester);

    await tester.enterText(find.byType(TextField), 'zzz_no_match');
    await tester.pumpAndSettle();

    expect(find.text('Illness'), findsNothing);
    expect(find.text('Losing a job'), findsNothing);
  });
}
