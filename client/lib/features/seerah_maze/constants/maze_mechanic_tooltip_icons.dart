import 'package:flutter/material.dart';

import '../models/maze_mechanics.dart';

/// A small icon badge per mechanic for its A8 introduction tooltip —
/// distinct from (and simpler than) the hand-drawn in-board glyph each
/// mechanic's own painter uses, since this one sits next to one line of
/// text rather than on the board itself.
IconData mazeMechanicTooltipIconFor(MazeMechanicTooltip tooltip) => switch (tooltip) {
      MazeMechanicTooltip.caravan => Icons.swap_horiz_rounded,
      MazeMechanicTooltip.cave => Icons.nights_stay_rounded,
      MazeMechanicTooltip.doors => Icons.key_rounded,
      MazeMechanicTooltip.sand => Icons.waves_rounded,
      MazeMechanicTooltip.sandstorm => Icons.air_rounded,
      MazeMechanicTooltip.teleport => Icons.auto_awesome_rounded,
      MazeMechanicTooltip.shiftingWalls => Icons.sync_alt_rounded,
      MazeMechanicTooltip.oneWay => Icons.arrow_forward_rounded,
    };
