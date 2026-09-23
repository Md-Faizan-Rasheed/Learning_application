import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class LanguageOption {
  const LanguageOption(this.code, this.nativeName);
  final String code;
  final String nativeName;
}

/// Shared with anywhere else that needs to offer the same language choices
/// outside a [LanguagePicker] itself — e.g. a collapsed overflow menu.
const kSupportedLanguages = [
  LanguageOption('en', 'English'),
  LanguageOption('ur', 'اردو'),
  LanguageOption('ar', 'العربية'),
];

class LanguagePicker extends StatelessWidget {
  final String currentLanguage;
  final Function(Locale) onLocaleChange;

  /// When true, renders as a small icon-only button (no language name label)
  /// — for tight spaces like the mobile home header, where the full pill
  /// crowds out the neighboring avatar/logout button.
  final bool compact;

  const LanguagePicker({
    Key? key,
    required this.currentLanguage,
    required this.onLocaleChange,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final current = kSupportedLanguages.firstWhere(
      (l) => l.code == currentLanguage,
      orElse: () => kSupportedLanguages.first,
    );

    return PopupMenuButton<Locale>(
      tooltip: AppLocalizations.of(context)!.changeLanguage,
      onSelected: (locale) => onLocaleChange(locale),
      icon: compact
          ? Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: const Icon(Icons.language_rounded,
                  size: 16, color: Colors.white),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language_rounded,
                      size: 18, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    current.nativeName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.white),
                  ),
                ],
              ),
            ),
      itemBuilder: (context) => [
        for (final lang in kSupportedLanguages)
          PopupMenuItem(
            value: Locale(lang.code),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: lang.code == currentLanguage
                      ? Icon(Icons.check,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                ),
                const SizedBox(width: 6),
                Text(
                  lang.nativeName,
                  style: TextStyle(
                    fontWeight: lang.code == currentLanguage
                        ? FontWeight.w800
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
