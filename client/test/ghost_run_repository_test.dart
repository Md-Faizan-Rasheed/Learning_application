import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/ghost_run_repository.dart';
import 'package:islamic_game/features/seerah_maze/models/ghost_sample.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_cell.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const repository = GhostRunRepository();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('a level with no saved ghost loads as empty', () async {
    expect(await repository.loadBest(1), isEmpty);
  });

  test('save then load round-trips the exact samples', () async {
    final samples = [
      const GhostSample(elapsed: Duration.zero, cell: MazeCoord(0, 0)),
      const GhostSample(elapsed: Duration(milliseconds: 800), cell: MazeCoord(0, 1)),
    ];

    await repository.save(5, samples);
    final loaded = await repository.loadBest(5);

    expect(loaded, samples);
  });

  test('different levels are stored independently', () async {
    await repository.save(1, [const GhostSample(elapsed: Duration.zero, cell: MazeCoord(0, 0))]);
    await repository.save(2, [const GhostSample(elapsed: Duration.zero, cell: MazeCoord(1, 1))]);

    expect((await repository.loadBest(1)).single.cell, const MazeCoord(0, 0));
    expect((await repository.loadBest(2)).single.cell, const MazeCoord(1, 1));
  });

  test('saving again for the same level overwrites the previous run', () async {
    await repository.save(1, [const GhostSample(elapsed: Duration.zero, cell: MazeCoord(0, 0))]);
    await repository.save(1, [const GhostSample(elapsed: Duration.zero, cell: MazeCoord(9, 9))]);

    final loaded = await repository.loadBest(1);

    expect(loaded, hasLength(1));
    expect(loaded.single.cell, const MazeCoord(9, 9));
  });

  test('corrupted stored data falls back to empty instead of throwing', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('seerah_maze_ghost_level_3', 'not valid json at all {{{');

    expect(await repository.loadBest(3), isEmpty);
  });

  test('a stored run containing one malformed sample is entirely discarded', () async {
    final prefs = await SharedPreferences.getInstance();
    // Valid JSON array, but one entry has the wrong shape.
    await prefs.setString('seerah_maze_ghost_level_4', '[[0,0,0],["bad"]]');

    expect(await repository.loadBest(4), isEmpty);
  });
}
