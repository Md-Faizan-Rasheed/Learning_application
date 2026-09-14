import 'package:flutter/material.dart';

import '../services/arabic_tts_service.dart';
import '../theme/app_theme.dart';

/// The real Arabic spelling of a found Word Search word, plus a tap-to-hear
/// button — used wherever a found word's fact is shown (the sidebar chip
/// and the post-puzzle recap). Explicitly forces RTL direction and the
/// Noto Naskh Arabic font regardless of the app's current UI language, so
/// the script renders correctly even when the interface itself is in
/// English.
class ArabicWordRow extends StatelessWidget {
  const ArabicWordRow({super.key, required this.arabicScript, this.fontSize = 15});

  final String arabicScript;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            arabicScript,
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: AppPalette.ink,
            ),
          ),
        ),
        const SizedBox(width: 2),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => ArabicTtsService.instance.speak(arabicScript),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.volume_up_rounded, size: fontSize, color: AppPalette.deepTeal),
          ),
        ),
      ],
    );
  }
}
