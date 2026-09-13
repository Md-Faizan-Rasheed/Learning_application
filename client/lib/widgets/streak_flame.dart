import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class StreakFlame extends StatelessWidget {
  const StreakFlame({super.key, required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final badgeSize = (36 + streak * 4).clamp(36, 72).toDouble();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: badgeSize,
          height: badgeSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppPalette.cardStock,
            border: Border.all(color: AppPalette.mutedGold, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: AppPalette.shadowInk,
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            Icons.local_fire_department_rounded,
            color: AppPalette.mutedGold,
            size: badgeSize * 0.6,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          AppLocalizations.of(context)!.rewardStreakDays(streak),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
