import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/auth/auth_service.dart';
import 'package:islamic_game/l10n/app_localizations.dart';
import 'package:islamic_game/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('signed-out Home shows login/signup and opens role selection',
      (tester) async {
    await pumpAnonymousHome(tester);

    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);

    await tester.tap(find.text('Sign up'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Display name'), findsOneWidget);
    await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('step0')),
          matching: find.byType(TextField),
        ),
        'Test Student');
    await tester.pump();
    final next = find.widgetWithText(FilledButton, 'Next');
    await tester.ensureVisible(next);
    expect(tester.widget<FilledButton>(next).onPressed, isNotNull);
    await tester.tap(next);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('step1')), findsOneWidget);
    expect(find.text('Choose your role'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Teacher'), findsOneWidget);
  });

  testWidgets('account-only Home actions show sign-in choices', (tester) async {
    await pumpAnonymousHome(tester);

    await tester.tap(find.text('Campaign'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.text('Create an account or sign in to use this feature.'),
        findsOneWidget);

    final signupAction = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Sign up'),
    );
    await tester.tap(signupAction);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Display name'), findsOneWidget);
  });
}

Future<void> pumpAnonymousHome(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: HomeScreen(
        auth: AuthService(),
        currentLang: 'en',
        onLocaleChange: (_) {},
        onSignOut: () async {},
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}
