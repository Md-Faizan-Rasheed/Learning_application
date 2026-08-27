import 'package:flutter/material.dart';

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
    return PopupMenuButton<Locale>(
      icon: const Icon(Icons.language),
      onSelected: onLocaleChange,
      itemBuilder: (context) => const [
        PopupMenuItem(value: Locale('en'), child: Text('English')),
        PopupMenuItem(value: Locale('ur'), child: Text('اردو')),
        PopupMenuItem(value: Locale('ar'), child: Text('العربية')),
      ],
    );
  }
}