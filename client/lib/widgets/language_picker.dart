import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class _LanguageOption {
  const _LanguageOption(this.code, this.nativeName);
  final String code;
  final String nativeName;
}

const _kLanguages = [
  _LanguageOption('en', 'English'),
  _LanguageOption('ur', 'اردو'),
  _LanguageOption('ar', 'العربية'),
];

class LanguagePicker extends StatelessWidget {
  final String currentLanguage;
  final Function(Locale) onLocaleChange;

  const LanguagePicker({
    Key? key,
    required this.currentLanguage,
    required this.onLocaleChange,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final current = _kLanguages.firstWhere(
      (l) => l.code == currentLanguage,
      orElse: () => _kLanguages.first,
    );

    return PopupMenuButton<Locale>(
      tooltip: AppLocalizations.of(context)!.changeLanguage,
      onSelected: (locale) => onLocaleChange(locale),
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded, size: 18, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              current.nativeName,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        for (final lang in _kLanguages)
          PopupMenuItem(
            value: Locale(lang.code),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: lang.code == currentLanguage
                      ? Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.primary)
                      : null,
                ),
                const SizedBox(width: 6),
                Text(
                  lang.nativeName,
                  style: TextStyle(
                    fontWeight: lang.code == currentLanguage ? FontWeight.w800 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}