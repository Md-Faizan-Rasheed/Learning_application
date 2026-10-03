import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_character_skin.dart';

/// D3 — the cosmetic skin catalog: unlock levels, uniqueness, and the
/// lookup helper.
void main() {
  test('the default (traveler) skin is always unlocked, at level 1', () {
    final traveler = mazeCharacterSkinDefFor(MazeCharacterSkinId.traveler);
    expect(traveler.unlockLevel, 1);
  });

  test('every skin id appears exactly once', () {
    final ids = kMazeCharacterSkins.map((s) => s.id).toSet();
    expect(ids.length, kMazeCharacterSkins.length);
    expect(ids.length, MazeCharacterSkinId.values.length);
  });

  test('unlock levels are non-decreasing in catalog order', () {
    var previous = 0;
    for (final skin in kMazeCharacterSkins) {
      expect(skin.unlockLevel, greaterThanOrEqualTo(previous));
      previous = skin.unlockLevel;
    }
  });

  test('mazeCharacterSkinDefFor finds the matching definition for every id', () {
    for (final id in MazeCharacterSkinId.values) {
      expect(mazeCharacterSkinDefFor(id).id, id);
    }
  });

  test('no two unlocked skins share identical fill and trail colors', () {
    final pairs = kMazeCharacterSkins.map((s) => (s.fillColor, s.trailColor)).toSet();
    expect(pairs.length, kMazeCharacterSkins.length);
  });
}
