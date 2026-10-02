import '../../../l10n/app_localizations.dart';
import '../models/maze_level.dart';
import '../models/maze_mechanics.dart';

/// The 10 levels' structural/gameplay data — grid size, generation seed,
/// loop count, star-time threshold, and destination presentation. Pure
/// `const` data with no display text at all (see models/maze_level.dart);
/// every level's character/destination names and story/win lines are
/// looked up live via [mazeLevelTextFor] instead.
const List<MazeLevel> kMazeLevels = [
  MazeLevel(
    id: 1,
    gridSize: 6,
    seed: 1,
    extraLoopCount: 0,
    starTimeThreshold: Duration(seconds: 45),
    destinationKind: MazeDestinationKind.kaaba,
    usesLightMarker: false,
  ),
  MazeLevel(
    id: 2,
    gridSize: 7,
    seed: 2,
    extraLoopCount: 0,
    starTimeThreshold: Duration(seconds: 55),
    destinationKind: MazeDestinationKind.town,
    usesLightMarker: false,
  ),
  MazeLevel(
    id: 3,
    gridSize: 8,
    seed: 3,
    extraLoopCount: 0,
    starTimeThreshold: Duration(seconds: 70),
    destinationKind: MazeDestinationKind.caravan,
    usesLightMarker: false,
  ),
  MazeLevel(
    id: 4,
    gridSize: 8,
    seed: 4,
    extraLoopCount: 0,
    // Raised from 70s: a caravan in the way costs some re-walking.
    starTimeThreshold: Duration(seconds: 95),
    destinationKind: MazeDestinationKind.caravan,
    usesLightMarker: false,
    // A6 — the caravan level is where a patrolling caravan belongs.
    mechanics: MazeMechanics(caravans: CaravanConfig()),
  ),
  MazeLevel(
    id: 5,
    gridSize: 9,
    seed: 5,
    extraLoopCount: 0,
    // Raised from 85s: A2's cave darkness means more feeling-around than
    // the original lit version needed. This is an estimate, not a
    // playtested figure — worth re-tuning on a real device.
    starTimeThreshold: Duration(seconds: 120),
    destinationKind: MazeDestinationKind.cave,
    usesLightMarker: true,
    // A2 — Cave Hira is a dark cave, so it's lit by lantern only.
    mechanics: MazeMechanics(cave: CaveConfig()),
  ),
  MazeLevel(
    id: 6,
    gridSize: 10,
    seed: 6,
    extraLoopCount: 2,
    // Raised from 100s to allow for the key detour A3 adds. An estimate,
    // like the cave levels' — worth a playtest.
    starTimeThreshold: Duration(seconds: 130),
    destinationKind: MazeDestinationKind.house,
    usesLightMarker: false,
    // A3 — the gentle introduction to doors: exactly one.
    mechanics: MazeMechanics(doors: DoorConfig()),
  ),
  MazeLevel(
    id: 7,
    gridSize: 11,
    seed: 7,
    extraLoopCount: 2,
    // Raised from 115s for the same reason as level 5 — also an estimate.
    starTimeThreshold: Duration(seconds: 165),
    destinationKind: MazeDestinationKind.cave,
    usesLightMarker: false,
    // A2 — Cave Thawr. Slightly tighter lantern than Hira, since this is
    // the later of the two cave levels.
    mechanics: MazeMechanics(cave: CaveConfig(lanternRadius: 1.6)),
  ),
  MazeLevel(
    id: 8,
    gridSize: 12,
    seed: 8,
    extraLoopCount: 3,
    // Raised from 130s: sand slides overshoot, so expect some re-walking.
    starTimeThreshold: Duration(seconds: 165),
    destinationKind: MazeDestinationKind.town,
    usesLightMarker: true,
    // A4 — the desert crossing is where slippery sand is introduced.
    // A6 — and where a sandstorm fits the setting.
    mechanics: MazeMechanics(sand: SandConfig(), sandstorm: SandstormConfig()),
  ),
  MazeLevel(
    id: 9,
    gridSize: 14,
    seed: 9,
    extraLoopCount: 4,
    // Raised from 160s for two key detours instead of one.
    starTimeThreshold: Duration(seconds: 220),
    destinationKind: MazeDestinationKind.gathering,
    usesLightMarker: false,
    // A3 — two doors now that the mechanic has been met on level 6.
    // A5 — plus one tent pair, as a shortcut worth finding on a 14x14.
    // A7 — and one shifting passage, introduced here before the finale.
    mechanics: MazeMechanics(
      doors: DoorConfig(doorCount: 2),
      teleports: TeleportConfig(),
      shiftingWalls: ShiftingWallsConfig(),
    ),
  ),
  MazeLevel(
    id: 10,
    gridSize: 16,
    seed: 10,
    extraLoopCount: 5,
    // Raised from 190s: the finale combines sand and one-way tiles.
    starTimeThreshold: Duration(seconds: 260),
    destinationKind: MazeDestinationKind.kaaba,
    usesLightMarker: false,
    // A4 — the final level is the only one that combines both movement
    // mechanics, as a send-off rather than a new idea.
    mechanics: MazeMechanics(
      sand: SandConfig(patchCount: 2, patchLength: 2),
      oneWay: OneWayConfig(tileCount: 2),
      shiftingWalls: ShiftingWallsConfig(toggleCount: 2),
    ),
  ),
];

/// One level's localized display text.
///
/// REVIEW WITH A SCHOLAR/TEACHER BEFORE RELEASE: every `story`/`winLine`
/// string these come from (in every language — see the ARB files'
/// `mazeLevel*Story`/`mazeLevel*WinLine` keys) is a first draft, written
/// to be short, simple, and to avoid anything historically uncertain or
/// sensitive, but it still needs a real review pass before shipping.
class MazeLevelText {
  const MazeLevelText({
    required this.character,
    required this.destination,
    required this.story,
    required this.winLine,
  });

  final String character;
  final String destination;
  final String story;
  final String winLine;
}

MazeLevelText mazeLevelTextFor(AppLocalizations t, int id) {
  switch (id) {
    case 1:
      return MazeLevelText(
        character: t.mazeLevel1Character,
        destination: t.mazeLevel1Destination,
        story: t.mazeLevel1Story,
        winLine: t.mazeLevel1WinLine,
      );
    case 2:
      return MazeLevelText(
        character: t.mazeLevel2Character,
        destination: t.mazeLevel2Destination,
        story: t.mazeLevel2Story,
        winLine: t.mazeLevel2WinLine,
      );
    case 3:
      return MazeLevelText(
        character: t.mazeLevel3Character,
        destination: t.mazeLevel3Destination,
        story: t.mazeLevel3Story,
        winLine: t.mazeLevel3WinLine,
      );
    case 4:
      return MazeLevelText(
        character: t.mazeLevel4Character,
        destination: t.mazeLevel4Destination,
        story: t.mazeLevel4Story,
        winLine: t.mazeLevel4WinLine,
      );
    case 5:
      return MazeLevelText(
        character: t.mazeLevel5Character,
        destination: t.mazeLevel5Destination,
        story: t.mazeLevel5Story,
        winLine: t.mazeLevel5WinLine,
      );
    case 6:
      return MazeLevelText(
        character: t.mazeLevel6Character,
        destination: t.mazeLevel6Destination,
        story: t.mazeLevel6Story,
        winLine: t.mazeLevel6WinLine,
      );
    case 7:
      return MazeLevelText(
        character: t.mazeLevel7Character,
        destination: t.mazeLevel7Destination,
        story: t.mazeLevel7Story,
        winLine: t.mazeLevel7WinLine,
      );
    case 8:
      return MazeLevelText(
        character: t.mazeLevel8Character,
        destination: t.mazeLevel8Destination,
        story: t.mazeLevel8Story,
        winLine: t.mazeLevel8WinLine,
      );
    case 9:
      return MazeLevelText(
        character: t.mazeLevel9Character,
        destination: t.mazeLevel9Destination,
        story: t.mazeLevel9Story,
        winLine: t.mazeLevel9WinLine,
      );
    case 10:
      return MazeLevelText(
        character: t.mazeLevel10Character,
        destination: t.mazeLevel10Destination,
        story: t.mazeLevel10Story,
        winLine: t.mazeLevel10WinLine,
      );
    default:
      throw ArgumentError('no such Seerah Maze level: $id');
  }
}
