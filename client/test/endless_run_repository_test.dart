import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/data/endless_run_repository.dart';
import 'package:islamic_game/features/seerah_maze/models/endless_best_run.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const repository = EndlessRunRepository();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('a fresh install loads a fresh default (0 rounds)', () async {
    final run = await repository.load();
    expect(run.bestRoundsCleared, 0);
  });

  test('round-trips through save and load', () async {
    await repository.save(const EndlessBestRun(bestRoundsCleared: 12));
    final run = await repository.load();
    expect(run.bestRoundsCleared, 12);
  });

  test('a later save overwrites the earlier one', () async {
    await repository.save(const EndlessBestRun(bestRoundsCleared: 5));
    await repository.save(const EndlessBestRun(bestRoundsCleared: 9));
    final run = await repository.load();
    expect(run.bestRoundsCleared, 9);
  });

  test('malformed stored JSON falls back to the fresh default instead of throwing', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('seerah_maze_endless_best', 'not json at all');
    final run = await repository.load();
    expect(run.bestRoundsCleared, 0);
  });

  test('EndlessBestRun.fromJson rejects a negative rounds value', () {
    final run = EndlessBestRun.fromJson({'bestRoundsCleared': -3});
    expect(run.bestRoundsCleared, 0);
  });

  test('EndlessBestRun.fromJson rejects a non-int rounds value', () {
    final run = EndlessBestRun.fromJson({'bestRoundsCleared': 'twelve'});
    expect(run.bestRoundsCleared, 0);
  });

  test('copyWith updates only the given field', () {
    const run = EndlessBestRun(bestRoundsCleared: 4);
    expect(run.copyWith(bestRoundsCleared: 7).bestRoundsCleared, 7);
    expect(run.copyWith().bestRoundsCleared, 4);
  });
}
