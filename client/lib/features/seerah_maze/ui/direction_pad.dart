import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../constants/maze_colors.dart';
import '../constants/maze_constants.dart';
import '../models/maze_direction.dart';

/// C6 — an on-screen D-pad: four tappable arrows arranged in a plus
/// shape, each repeating [onDirection] on a timer while held (same
/// cadence as holding down a keyboard key — see
/// [MazeConstants.keyRepeatInterval]) rather than firing once per tap.
/// Built for the 2-player race screen, where neither player can rely on
/// owning keyboard focus — see MazeBoardWidget.onMoveRequesterReady.
class MazeDirectionPad extends StatefulWidget {
  const MazeDirectionPad({super.key, required this.onDirection});

  final ValueChanged<MazeDirection> onDirection;

  @override
  State<MazeDirectionPad> createState() => _MazeDirectionPadState();
}

class _MazeDirectionPadState extends State<MazeDirectionPad> {
  Timer? _repeatTimer;

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

  void _startRepeating(MazeDirection direction) {
    widget.onDirection(direction);
    _repeatTimer?.cancel();
    _repeatTimer = Timer.periodic(MazeConstants.keyRepeatInterval, (_) {
      widget.onDirection(direction);
    });
  }

  void _stopRepeating() => _repeatTimer?.cancel();

  String _semanticsLabelFor(AppLocalizations t, MazeDirection direction) => switch (direction) {
        MazeDirection.north => t.mazeDirectionUp,
        MazeDirection.south => t.mazeDirectionDown,
        MazeDirection.east => t.mazeDirectionRight,
        MazeDirection.west => t.mazeDirectionLeft,
      };

  IconData _iconFor(MazeDirection direction) => switch (direction) {
        MazeDirection.north => Icons.keyboard_arrow_up_rounded,
        MazeDirection.south => Icons.keyboard_arrow_down_rounded,
        MazeDirection.east => Icons.keyboard_arrow_right_rounded,
        MazeDirection.west => Icons.keyboard_arrow_left_rounded,
      };

  Widget _button(MazeDirection direction) {
    final t = AppLocalizations.of(context)!;
    return Semantics(
      button: true,
      label: _semanticsLabelFor(t, direction),
      child: GestureDetector(
        onTapDown: (_) => _startRepeating(direction),
        onTapUp: (_) => _stopRepeating(),
        onTapCancel: _stopRepeating,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: MazeColors.boardPanel,
            shape: BoxShape.circle,
            border: Border.all(color: MazeColors.boardBorder),
          ),
          child: Icon(_iconFor(direction), color: Colors.white, size: 28),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button(MazeDirection.north),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _button(MazeDirection.west),
            const SizedBox(width: 56),
            _button(MazeDirection.east),
          ],
        ),
        const SizedBox(height: 6),
        _button(MazeDirection.south),
      ],
    );
  }
}
