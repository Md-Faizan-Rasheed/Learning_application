import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum StatusTone { neutral, info, success, warning }

/// Small colored pill for a status word (quiz draft/published/closed, an
/// attempt's not-started/in-progress/completed, …) — used wherever a screen
/// currently just prints the status as plain text.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.tone, this.icon});

  final String label;
  final StatusTone tone;
  final IconData? icon;

  Color _colorFor(StatusTone tone, ColorScheme colors) {
    switch (tone) {
      case StatusTone.success:
        return colors.primary;
      case StatusTone.warning:
        return AppPalette.mutedGold;
      case StatusTone.info:
        return colors.primary;
      case StatusTone.neutral:
        return colors.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(tone, Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
