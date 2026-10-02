import 'maze_passage_edge.dart';

/// Which key opens which door. Three is plenty for one level, and each
/// kind carries a distinct *shape* as well as a distinct color (see
/// constants/maze_door_styles.dart) so a player who can't separate the
/// colors can still match key to door — the spec's "color is never the
/// only signal" rule.
enum MazeKeyKind { brass, copper, silver }

/// One locked door: a passage plus the key kind that opens it.
class MazeDoor {
  const MazeDoor({required this.edge, required this.keyKind});

  final MazePassageEdge edge;
  final MazeKeyKind keyKind;

  @override
  bool operator ==(Object other) =>
      other is MazeDoor && other.edge == edge && other.keyKind == keyKind;

  @override
  int get hashCode => Object.hash(edge, keyKind);

  @override
  String toString() => 'MazeDoor(${edge.toString()}, ${keyKind.name})';
}
