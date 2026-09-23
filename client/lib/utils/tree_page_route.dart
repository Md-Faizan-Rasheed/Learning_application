import 'package:flutter/material.dart';

/// Consistent "going deeper into the tree" transition, shared by every push
/// in the Find My Ayah flow (root -> sub-tree, and root -> sub-tree when
/// jumping there from search/saved) so the direction and easing never vary.
///
/// A genuine zoom, not a slide: the entering screen grows from 0.78x up to
/// full size while fading in (driven by [animation]), and the screen
/// underneath keeps growing past full size up to 1.3x while fading out
/// (driven by [secondaryAnimation]) — reading as the camera pushing through
/// the tapped leaf into the new screen. Popping the route reverses every
/// part of this automatically: the covering screen shrinks back down and
/// fades out, the one underneath shrinks back to 1.0x and fades back in —
/// a real "zoom out" back to where you were, not just an undo of the slide.
///
/// Every screen in this flow must be pushed with this helper (not a plain
/// `MaterialPageRoute`) for the "zoom out" half to work — a route pushed
/// the normal way never reacts to `secondaryAnimation` at all.
// Kept generous/slow on purpose: a zoom this small a delta or this fast a
// duration reads as "nothing happened" rather than a deliberate transition
// (confirmed by sampling the previous, subtler version mid-flight in a
// widget test — it *was* interpolating correctly, just too small/fast to
// register at a glance). Bigger scale swing + longer duration removes any
// ambiguity about whether it's actually running.
const Duration _kTreeTransitionDuration = Duration(milliseconds: 420);

Route<T> buildTreeRoute<T>(WidgetBuilder builder) {
  return PageRouteBuilder<T>(
    transitionDuration: _kTreeTransitionDuration,
    reverseTransitionDuration: _kTreeTransitionDuration,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final incoming = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final receding = CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return FadeTransition(
        opacity: Tween<double>(begin: 1.0, end: 0.0).animate(receding),
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 1.6).animate(receding),
          child: FadeTransition(
            opacity: incoming,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.55, end: 1.0).animate(incoming),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}
