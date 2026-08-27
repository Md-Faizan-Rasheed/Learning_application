import 'package:flutter/material.dart';

class CountdownTimer extends StatelessWidget {
  final int remainingTime;
  final int totalTime;

  const CountdownTimer({
    Key? key,
    required this.remainingTime,
    required this.totalTime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ratio = totalTime > 0 ? (remainingTime / totalTime).clamp(0.0, 1.0) : 0.0;
    final secondsLeft = (remainingTime / 1000).ceil().clamp(0, 999);

    final Color color = ratio <= 0.2
        ? Colors.red
        : (ratio <= 0.5 ? Colors.orange : Colors.green);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Time left',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            Text(
              '${secondsLeft}s',
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 10,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
