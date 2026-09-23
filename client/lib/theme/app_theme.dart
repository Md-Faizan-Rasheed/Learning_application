import 'package:flutter/material.dart';

/// The app's single visual language: a warm parchment/manuscript palette
/// shared by every screen. Named by role, not hue, so the palette can't
/// silently drift back into per-screen accent colors — every screen pulls
/// from these same roles via `Theme.of(context).colorScheme`.
class AppPalette {
  const AppPalette._();

  static const parchment = Color(0xFFF5EDE0);
  static const parchmentDeep = Color(0xFFEBE0CC);
  static const cardStock = Color(0xFFFBF6EC);

  static const deepTeal = Color(0xFF1B4B4A);
  static const mutedGold = Color(0xFFC9A24B);

  static const ink = Color(0xFF2B2320);
  static const borderTaupe = Color(0xFFD9CBB3);

  static const incorrectRed = Color(0xFFB3452F);
  // "Correct" reads as gold, not green, in this palette.
  static const correctGold = mutedGold;

  // Illustration-only tone for the "Find My Ayah" tree's bark/branches —
  // not a UI-chrome color, so it's exempt from the "pull from these same
  // roles" rule above; every other visual property of that screen still
  // reuses deepTeal/mutedGold/parchment like everywhere else.
  static const barkGreen = Color(0xFFB7CBB0);

  static Color get deepTealMuted => deepTeal.withValues(alpha: 0.15);
  static Color get mutedGoldMuted => mutedGold.withValues(alpha: 0.18);
  static Color get inkMuted => ink.withValues(alpha: 0.62);
  static Color get shadowInk => ink.withValues(alpha: 0.18);
}

/// Builds the app-wide light theme. Most screens already read colors via
/// `Theme.of(context).colorScheme.*` rather than hardcoding literals, so
/// this one function recolors the large majority of the UI.
///
/// [locale] picks the active font pairing: Noto Naskh Arabic (covers both
/// Arabic and Urdu script) for `ar`/`ur`, or Playfair Display for display
/// text + the platform default (Roboto) for body text otherwise.
ThemeData buildAppTheme({required Locale locale}) {
  final isArabicScript = locale.languageCode == 'ar' || locale.languageCode == 'ur';
  final displayFontFamily = isArabicScript ? 'NotoNaskhArabic' : 'PlayfairDisplay';
  final bodyFontFamily = isArabicScript ? 'NotoNaskhArabic' : null;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppPalette.deepTeal,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppPalette.deepTeal,
    onPrimary: AppPalette.cardStock,
    primaryContainer: AppPalette.deepTealMuted,
    onPrimaryContainer: AppPalette.ink,
    secondary: AppPalette.mutedGold,
    onSecondary: AppPalette.ink,
    secondaryContainer: AppPalette.mutedGoldMuted,
    onSecondaryContainer: AppPalette.ink,
    // No third accent hue in this palette — tertiary collapses onto primary
    // rather than reintroducing a violet/blue/purple note.
    tertiary: AppPalette.deepTeal,
    onTertiary: AppPalette.cardStock,
    surface: AppPalette.parchment,
    onSurface: AppPalette.ink,
    onSurfaceVariant: AppPalette.inkMuted,
    surfaceContainerHighest: AppPalette.parchmentDeep,
    outline: AppPalette.borderTaupe,
    outlineVariant: AppPalette.borderTaupe,
    shadow: AppPalette.ink,
    error: AppPalette.incorrectRed,
    onError: AppPalette.cardStock,
  );

  final baseText = Typography.material2021(platform: TargetPlatform.android).black;
  final textTheme = baseText
      .apply(
        bodyColor: AppPalette.ink,
        displayColor: AppPalette.ink,
        fontFamily: bodyFontFamily,
      )
      .copyWith(
        displayLarge: baseText.displayLarge?.copyWith(
            fontFamily: displayFontFamily, fontWeight: FontWeight.w700, color: AppPalette.ink),
        displayMedium: baseText.displayMedium?.copyWith(
            fontFamily: displayFontFamily, fontWeight: FontWeight.w700, color: AppPalette.ink),
        displaySmall: baseText.displaySmall?.copyWith(
            fontFamily: displayFontFamily, fontWeight: FontWeight.w700, color: AppPalette.ink),
        headlineLarge: baseText.headlineLarge?.copyWith(
            fontFamily: displayFontFamily, fontWeight: FontWeight.w700, color: AppPalette.ink),
        headlineMedium: baseText.headlineMedium?.copyWith(
            fontFamily: displayFontFamily, fontWeight: FontWeight.w700, color: AppPalette.ink),
        headlineSmall: baseText.headlineSmall?.copyWith(
            fontFamily: displayFontFamily, fontWeight: FontWeight.w700, color: AppPalette.ink),
        titleLarge: baseText.titleLarge?.copyWith(
            fontFamily: displayFontFamily, fontWeight: FontWeight.w600, color: AppPalette.ink),
      );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppPalette.parchment,
    textTheme: textTheme,
    fontFamily: bodyFontFamily,
    iconTheme: const IconThemeData(color: AppPalette.ink),
    dividerColor: AppPalette.borderTaupe,
    cardTheme: CardThemeData(
      color: AppPalette.cardStock,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppPalette.borderTaupe),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppPalette.parchmentDeep,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppPalette.parchmentDeep,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppPalette.parchmentDeep,
      indicatorColor: AppPalette.deepTealMuted,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppPalette.deepTeal
              : AppPalette.inkMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: states.contains(WidgetState.selected)
              ? AppPalette.deepTeal
              : AppPalette.inkMuted,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppPalette.cardStock,
      labelStyle: TextStyle(color: AppPalette.inkMuted),
      hintStyle: TextStyle(color: AppPalette.inkMuted.withValues(alpha: 0.7)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppPalette.borderTaupe),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppPalette.borderTaupe),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppPalette.deepTeal, width: 2),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppPalette.ink,
      elevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppPalette.deepTeal,
        foregroundColor: AppPalette.cardStock,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppPalette.deepTeal,
        foregroundColor: AppPalette.cardStock,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppPalette.ink,
        side: const BorderSide(color: AppPalette.borderTaupe),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppPalette.deepTeal),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: AppPalette.cardStock,
        foregroundColor: AppPalette.inkMuted,
        selectedBackgroundColor: AppPalette.deepTealMuted,
        selectedForegroundColor: AppPalette.deepTeal,
        side: const BorderSide(color: AppPalette.borderTaupe),
        // Material's default segmented-button shape is a stadium/pill —
        // override it so it matches the card-stock 12px radius everywhere.
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppPalette.parchmentDeep,
      contentTextStyle: TextStyle(color: AppPalette.ink),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
