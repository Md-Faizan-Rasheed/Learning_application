import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/logic/mechanics/cave_lantern.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_cell.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_mechanics.dart';

void main() {
  CaveLantern lanternWith({
    CaveConfig config = const CaveConfig(),
    Set<MazeCoord> orbs = const {},
  }) =>
      CaveLantern(config: config, orbCells: orbs);

  group('CaveLantern.placeOrbs', () {
    List<MazeCoord> straightPath(int length) => List.generate(length, (i) => MazeCoord(0, i));

    test('places an orb every `spacing` steps along the path', () {
      final orbs = CaveLantern.placeOrbs(solutionPath: straightPath(16), spacing: 5);

      expect(orbs, {const MazeCoord(0, 5), const MazeCoord(0, 10)});
    });

    test('never places an orb on the start or the destination', () {
      final path = straightPath(11);
      final orbs = CaveLantern.placeOrbs(solutionPath: path, spacing: 1);

      expect(orbs, isNot(contains(path.first)));
      expect(orbs, isNot(contains(path.last)));
    });

    test('skips excluded cells so an orb never shares a cell with a star', () {
      final orbs = CaveLantern.placeOrbs(
        solutionPath: straightPath(16),
        spacing: 5,
        exclude: {const MazeCoord(0, 5)},
      );

      expect(orbs, {const MazeCoord(0, 10)});
    });

    test('a path too short for any orb yields none instead of throwing', () {
      expect(CaveLantern.placeOrbs(solutionPath: straightPath(2), spacing: 5), isEmpty);
      expect(CaveLantern.placeOrbs(solutionPath: const [], spacing: 5), isEmpty);
    });

    test('is deterministic — same path and spacing, same orbs', () {
      final a = CaveLantern.placeOrbs(solutionPath: straightPath(30), spacing: 4);
      final b = CaveLantern.placeOrbs(solutionPath: straightPath(30), spacing: 4);

      expect(a, b);
    });
  });

  group('CaveLantern.collectAt', () {
    test('picking up an orb removes it and starts the boost', () {
      final lantern = lanternWith(orbs: {const MazeCoord(1, 1)});

      expect(lantern.isBoosted, isFalse);
      expect(lantern.collectAt(const MazeCoord(1, 1)), isTrue);
      expect(lantern.isBoosted, isTrue);
      expect(lantern.remainingOrbs, isEmpty);
    });

    test('stepping on an empty cell collects nothing', () {
      final lantern = lanternWith(orbs: {const MazeCoord(1, 1)});

      expect(lantern.collectAt(const MazeCoord(4, 4)), isFalse);
      expect(lantern.isBoosted, isFalse);
      expect(lantern.remainingOrbs, hasLength(1));
    });

    test('the same orb cannot be collected twice', () {
      final lantern = lanternWith(orbs: {const MazeCoord(1, 1)});
      lantern.collectAt(const MazeCoord(1, 1));

      expect(lantern.collectAt(const MazeCoord(1, 1)), isFalse);
    });

    test('a second orb restarts the window rather than stacking it', () {
      final lantern = lanternWith(
        config: const CaveConfig(boostDuration: Duration(seconds: 10)),
        orbs: {const MazeCoord(1, 1), const MazeCoord(2, 2)},
      );

      lantern.collectAt(const MazeCoord(1, 1));
      lantern.tick(const Duration(seconds: 6));
      expect(lantern.boostRemaining, const Duration(seconds: 4));

      lantern.collectAt(const MazeCoord(2, 2));
      expect(lantern.boostRemaining, const Duration(seconds: 10));
    });
  });

  group('CaveLantern.tick', () {
    test('counts the boost down and expires it exactly once', () {
      final lantern = lanternWith(
        config: const CaveConfig(boostDuration: Duration(seconds: 10)),
        orbs: {const MazeCoord(1, 1)},
      );
      lantern.collectAt(const MazeCoord(1, 1));

      lantern.tick(const Duration(seconds: 9));
      expect(lantern.isBoosted, isTrue);

      lantern.tick(const Duration(seconds: 1));
      expect(lantern.isBoosted, isFalse);
      expect(lantern.boostRemaining, Duration.zero);
    });

    test('never counts below zero, even on a long tick', () {
      final lantern = lanternWith(orbs: {const MazeCoord(1, 1)});
      lantern.collectAt(const MazeCoord(1, 1));

      lantern.tick(const Duration(hours: 1));

      expect(lantern.boostRemaining, Duration.zero);
    });

    test('ticking with no boost active is a no-op', () {
      final lantern = lanternWith();

      lantern.tick(const Duration(seconds: 5));

      expect(lantern.boostRemaining, Duration.zero);
      expect(lantern.isBoosted, isFalse);
    });
  });

  group('CaveLantern.radiusAt', () {
    test('with no flicker it is exactly the configured base radius', () {
      final lantern = lanternWith(
        config: const CaveConfig(lanternRadius: 2, flickerAmplitude: 0),
      );

      expect(lantern.radiusAt(const Duration(milliseconds: 400)), 2);
      expect(lantern.radiusAt(const Duration(seconds: 9)), 2);
    });

    test('a boost widens it to the boosted radius', () {
      final lantern = lanternWith(
        config: const CaveConfig(
          lanternRadius: 2,
          boostedLanternRadius: 4,
          flickerAmplitude: 0,
        ),
        orbs: {const MazeCoord(1, 1)},
      );

      expect(lantern.radiusAt(Duration.zero), 2);
      lantern.collectAt(const MazeCoord(1, 1));
      expect(lantern.radiusAt(Duration.zero), 4);
    });

    test('flicker stays within the configured amplitude band', () {
      const base = 2.0;
      const amplitude = 0.12;
      final lantern = lanternWith(
        config: const CaveConfig(lanternRadius: base, flickerAmplitude: amplitude),
      );

      for (var ms = 0; ms < 5000; ms += 17) {
        final radius = lantern.radiusAt(Duration(milliseconds: ms));
        expect(radius, greaterThan(base * (1 - amplitude * 1.01)));
        expect(radius, lessThan(base * (1 + amplitude * 1.01)));
      }
    });

    test('is a pure function of elapsed time — same instant, same radius', () {
      final lantern = lanternWith();
      const at = Duration(milliseconds: 823);

      expect(lantern.radiusAt(at), lantern.radiusAt(at));
    });

    test('actually varies over time rather than sitting flat', () {
      final lantern = lanternWith(config: const CaveConfig(flickerAmplitude: 0.2));
      final samples = [
        for (var ms = 0; ms < 1700; ms += 100) lantern.radiusAt(Duration(milliseconds: ms)),
      ];

      expect(samples.toSet().length, greaterThan(5));
    });
  });
}
