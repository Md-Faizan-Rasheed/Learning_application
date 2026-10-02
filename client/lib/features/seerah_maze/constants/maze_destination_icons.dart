import 'package:flutter/material.dart';

import '../models/maze_level.dart';

/// Simple Material-icon stand-ins for small UI previews (level-select
/// nodes, the story intro card) — the real in-board destination glyph is
/// hand-drawn by MazeDecorationsPainter (a proper Kaaba shape for
/// [MazeDestinationKind.kaaba] rather than a generic icon); this mapping
/// covers every other kind for both that painter and these smaller
/// previews, so the icon choice per kind lives in exactly one place.
IconData mazeDestinationIconFor(MazeDestinationKind kind) => switch (kind) {
      MazeDestinationKind.kaaba => Icons.square_rounded,
      MazeDestinationKind.town => Icons.location_city_rounded,
      MazeDestinationKind.cave => Icons.terrain_rounded,
      MazeDestinationKind.caravan => Icons.route_rounded,
      MazeDestinationKind.house => Icons.home_rounded,
      MazeDestinationKind.gathering => Icons.groups_rounded,
    };
