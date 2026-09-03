import 'package:flutter/material.dart';

/// Wraps a horizontally-scrolling widget (e.g. a `ListView.separated` rail)
/// with a soft fade at the trailing edge, signaling there's more content to
/// scroll to without adding any new interactive control. Fades from the
/// "end" side per the current text direction, so it works correctly in RTL.
class FadeScrollEdge extends StatelessWidget {
  const FadeScrollEdge({super.key, required this.child, this.width = 28});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return ShaderMask(
      shaderCallback: (bounds) {
        final fadeStop = (width / bounds.width).clamp(0.0, 1.0);
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          // Fade the trailing edge (the side with more off-screen content):
          // right/high-x in LTR, left/low-x in RTL.
          colors: rtl
              ? const [Colors.transparent, Colors.white, Colors.white]
              : const [Colors.white, Colors.white, Colors.transparent],
          stops: rtl ? [0.0, fadeStop, 1.0] : [0.0, 1 - fadeStop, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}
