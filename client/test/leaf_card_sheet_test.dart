import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/l10n/app_localizations.dart';
import 'package:islamic_game/utils/situation_data.dart';
import 'package:islamic_game/widgets/leaf_card_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const category = Category(id: 'emotions', label: 'Emotions', situations: [
    Situation(
      id: 'anxiety',
      label: 'Anxious',
      refs: [Reference(type: 'ayah', arabic: 'أ', gloss: 'g1', citation: 'c1')],
    ),
    Situation(
      id: 'fear',
      label: 'Afraid',
      refs: [Reference(type: 'ayah', arabic: 'أ', gloss: 'g2', citation: 'c2')],
    ),
    Situation(
      id: 'grief',
      label: 'Grieving',
      refs: [Reference(type: 'ayah', arabic: 'أ', gloss: 'g3', citation: 'c3')],
    ),
  ]);

  Future<void> pumpCard(WidgetTester tester, Situation situation) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showLeafCardSheet(context, category: category, situation: situation),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders without overflowing even with the continuation row present',
      (tester) async {
    await pumpCard(tester, category.situations[0]);

    // A RenderFlex overflow surfaces as a FlutterError during the test;
    // reaching this point with tester.takeException() clean is the actual
    // assertion — the card used to overflow once the continuation row was
    // added below a fixed, non-scrolling column.
    expect(tester.takeException(), isNull);
    expect(find.text('Emotions → Anxious'), findsOneWidget);
  });

  testWidgets('offers up to 3 sibling situations, excluding the current one', (tester) async {
    await pumpCard(tester, category.situations[0]);

    expect(find.widgetWithText(ActionChip, 'Afraid'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Grieving'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Anxious'), findsNothing);
  });

  testWidgets('tapping a sibling chip reopens the sheet for that situation', (tester) async {
    await pumpCard(tester, category.situations[0]);

    final chip = find.widgetWithText(ActionChip, 'Afraid');
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(find.text('Emotions → Afraid'), findsOneWidget);
    expect(find.text('Emotions → Anxious'), findsNothing);
  });
}
