import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

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
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF97316), Color(0xFFEF4444)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF97316).withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.local_fire_department_rounded,
            color: Colors.white,
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
