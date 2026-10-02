import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/maze_chapters.dart';
import 'package:islamic_game/features/seerah_maze/data/maze_levels.dart';

void main() {
  test('every level 1-10 is covered by exactly one chapter', () {
    for (final level in kMazeLevels) {
      final matches = kMazeChapters.where((c) => c.contains(level.id));
      expect(matches, hasLength(1), reason: 'level ${level.id}');
    }
  });

  test('chapters are contiguous and in order, with no gaps or overlaps', () {
    final sorted = [...kMazeChapters]..sort((a, b) => a.firstLevelId.compareTo(b.firstLevelId));
    expect(sorted.first.firstLevelId, 1);
    expect(sorted.last.lastLevelId, kMazeLevels.length);
    for (var i = 1; i < sorted.length; i++) {
      expect(sorted[i].firstLevelId, sorted[i - 1].lastLevelId + 1,
          reason: 'gap/overlap between chapters ${sorted[i - 1].id} and ${sorted[i].id}');
    }
  });

  test('mazeChapterFor returns the chapter actually containing that level', () {
    for (final level in kMazeLevels) {
      expect(mazeChapterFor(level.id).contains(level.id), isTrue);
    }
  });

  test('mazeChapterFor throws for a level id no chapter covers', () {
    expect(() => mazeChapterFor(0), throwsArgumentError);
    expect(() => mazeChapterFor(kMazeLevels.length + 1), throwsArgumentError);
  });
}
