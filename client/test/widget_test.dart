import 'package:flutter_test/flutter_test.dart';

import 'package:islamic_game/main.dart';

void main() {
  testWidgets('App builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const IslamicGameApp());
    await tester.pump();
  });
}
