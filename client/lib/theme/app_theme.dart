import 'package:flutter/material.dart';

/// The app's single visual language: a deep night-world palette shared by
/// every screen (previously scoped to just the auth screen as `AuthPalette`).
class AppPalette {
  const AppPalette._();

  static const nightTop = Color(0xFF0B0F1E);
  static const nightBottom = Color(0xFF15132A);

  static const emerald = Color(0xFF34D399);
  static const teal = Color(0xFF2DD4BF);
  static const gold = Color(0xFFF5C453);
  static const violet = Color(0xFFA78BFA);

  static const portalCore = Color(0xFFFDF6E3);

  static const glassFill = Color(0x1AFFFFFF);
  static const glassBorder = Color(0x33FFFFFF);

  static const textPrimary = Color(0xFFF5F3FF);
  static const textSecondary = Color(0xB3F5F3FF);

  static const List<Color> portalGradient = [emerald, teal, violet];
}

/// Builds the app-wide dark theme. Most screens already read colors via
/// `Theme.of(context).colorScheme.*` rather than hardcoding light-specific
/// literals, so this one swap recolors the large majority of the UI.
ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppPalette.emerald,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppPalette.emerald,
    onPrimary: AppPalette.nightTop,
    primaryContainer: AppPalette.emerald.withValues(alpha: 0.22),
    onPrimaryContainer: AppPalette.textPrimary,
    secondary: AppPalette.teal,
    onSecondary: AppPalette.nightTop,
    tertiary: AppPalette.violet,
    onTertiary: AppPalette.nightTop,
    surface: AppPalette.nightTop,
    onSurface: AppPalette.textPrimary,
    onSurfaceVariant: AppPalette.textSecondary,
    surfaceContainerHighest: AppPalette.nightBottom,
    outline: AppPalette.glassBorder,
    outlineVariant: AppPalette.glassBorder,
    shadow: Colors.black,
  );

  final baseText =
      Typography.material2021(platform: TargetPlatform.android).white;
  final textTheme = baseText.apply(
    bodyColor: AppPalette.textPrimary,
    displayColor: AppPalette.textPrimary,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppPalette.nightTop,
    textTheme: textTheme,
    iconTheme: const IconThemeData(color: AppPalette.textPrimary),
    dividerColor: AppPalette.glassBorder,
    cardTheme: CardThemeData(
      color: AppPalette.glassFill,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppPalette.glassBorder),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppPalette.nightBottom,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppPalette.nightBottom,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppPalette.nightBottom,
      indicatorColor: AppPalette.emerald.withValues(alpha: 0.24),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppPalette.emerald
              : AppPalette.textSecondary,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: states.contains(WidgetState.selected)
              ? AppPalette.emerald
              : AppPalette.textSecondary,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.22),
      labelStyle: const TextStyle(color: AppPalette.textSecondary),
      hintStyle: const TextStyle(color: AppPalette.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppPalette.emerald, width: 2),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppPalette.emerald,
        foregroundColor: AppPalette.nightTop,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppPalette.emerald,
        foregroundColor: AppPalette.nightTop,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppPalette.textPrimary,
        side: const BorderSide(color: AppPalette.glassBorder),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppPalette.emerald),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.22),
        foregroundColor: AppPalette.textSecondary,
        selectedBackgroundColor: AppPalette.emerald.withValues(alpha: 0.24),
        selectedForegroundColor: AppPalette.emerald,
        side: const BorderSide(color: AppPalette.glassBorder),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppPalette.nightBottom,
      contentTextStyle: TextStyle(color: AppPalette.textPrimary),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
