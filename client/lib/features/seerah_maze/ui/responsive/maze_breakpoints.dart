import 'package:flutter/widgets.dart';

import '../../constants/maze_constants.dart';

/// Width-based size class for Seerah Maze's adaptive screens. Mirrors the
/// breakpoints Phase 2's spec calls for (compact <600, medium 600-1024,
/// expanded >1024) — the single source every screen in this feature reads
/// instead of each inventing its own thresholds.
enum MazeScreenSize { compact, medium, expanded }

class MazeBreakpoints {
  const MazeBreakpoints._();

  static const double medium = 600;
  static const double expanded = 1024;

  static MazeScreenSize sizeForWidth(double width) {
    if (width >= expanded) return MazeScreenSize.expanded;
    if (width >= medium) return MazeScreenSize.medium;
    return MazeScreenSize.compact;
  }

  /// Landscape here means "wider than tall", independent of the device's
  /// own orientation API — what actually matters for layout is the shape
  /// of the available box, which can disagree with device orientation in
  /// a split-screen or resizable desktop window.
  static Orientation orientationFor(Size size) =>
      size.width >= size.height ? Orientation.landscape : Orientation.portrait;
}

/// Reads the current [MazeScreenSize] and [Orientation] from the nearest
/// [LayoutBuilder] constraints (not `MediaQuery.of(context).size`, which
/// reports the whole window rather than this widget's own box — the two
/// differ inside a split-screen panel, a dialog, or a resizable desktop
/// pane) and rebuilds [builder] whenever either changes.
class MazeResponsive extends StatelessWidget {
  const MazeResponsive({super.key, required this.builder});

  final Widget Function(BuildContext context, MazeScreenSize size, Orientation orientation) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return builder(
          context,
          MazeBreakpoints.sizeForWidth(size.width),
          MazeBreakpoints.orientationFor(size),
        );
      },
    );
  }
}

/// Wraps [child] in a [MediaQuery] whose text scaler is clamped to
/// [minScale]..[maxScale], so HUD chrome never overflows or clips under an
/// aggressive system font-size setting while still honoring smaller/larger
/// user preferences within that band. Scope this around HUD-type chrome
/// only, not full reading content, which should keep scaling freely.
class MazeClampedTextScale extends StatelessWidget {
  const MazeClampedTextScale({
    super.key,
    required this.child,
    this.minScale = 0.9,
    this.maxScale = 1.4,
  });

  final Widget child;
  final double minScale;
  final double maxScale;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final clamped = mediaQuery.textScaler.clamp(minScaleFactor: minScale, maxScaleFactor: maxScale);
    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clamped),
      child: child,
    );
  }
}

/// Centers and width-caps a bottom sheet / dialog body so it stays a
/// readable card on a tablet or desktop window instead of stretching the
/// full width, and clamps its text scaling like the rest of this feature's
/// chrome. On a phone the cap is simply never reached, so compact layouts
/// render exactly as they did before.
class MazeResponsiveSheet extends StatelessWidget {
  const MazeResponsiveSheet({
    super.key,
    required this.child,
    this.maxWidth = MazeConstants.maxSheetContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return MazeClampedTextScale(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

/// The full-screen counterpart of [MazeResponsiveSheet]: centers a
/// width-capped column for a Scaffold body, so list content doesn't run
/// edge-to-edge on a wide window.
class MazeResponsiveBody extends StatelessWidget {
  const MazeResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = MazeConstants.maxScreenContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
