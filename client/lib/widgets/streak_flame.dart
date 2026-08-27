import 'package:flutter/material.dart';

class StreakFlame extends StatelessWidget {
  final int streak;

  const StreakFlame({Key? key, required this.streak}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final iconSize = (36 + streak * 4).clamp(36, 72).toDouble();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.local_fire_department,
          color: Colors.orange,
          size: iconSize,
        ),
        SizedBox(width: 8),
        Text(
          '$streak Day Streak',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}