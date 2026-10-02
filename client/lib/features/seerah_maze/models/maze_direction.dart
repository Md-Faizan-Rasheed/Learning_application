/// The four cardinal moves a player (or a generated passage) can make.
/// Deliberately a fixed, ordered enum (not a free-form offset pair) so
/// generation, solving and rendering all agree on "which wall is this."
enum MazeDirection { north, east, south, west }

extension MazeDirectionGeometry on MazeDirection {
  /// Row delta for one step in this direction (north = up = row - 1).
  int get deltaRow => switch (this) {
        MazeDirection.north => -1,
        MazeDirection.south => 1,
        MazeDirection.east => 0,
        MazeDirection.west => 0,
      };

  /// Column delta for one step in this direction (east = right = col + 1).
  int get deltaCol => switch (this) {
        MazeDirection.east => 1,
        MazeDirection.west => -1,
        MazeDirection.north => 0,
        MazeDirection.south => 0,
      };

  MazeDirection get opposite => switch (this) {
        MazeDirection.north => MazeDirection.south,
        MazeDirection.south => MazeDirection.north,
        MazeDirection.east => MazeDirection.west,
        MazeDirection.west => MazeDirection.east,
      };
}
