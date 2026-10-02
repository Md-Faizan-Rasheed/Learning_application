import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/logic/environment/ambient_particle_field.dart';
import 'package:islamic_game/features/seerah_maze/models/maze_environment.dart';

void main() {
  group('AmbientParticleField', () {
    test('produces exactly particleCount particles', () {
      final field = AmbientParticleField(
        type: MazeAmbientParticleType.dust,
        seed: 1,
        particleCount: 9,
      );

      expect(field.particlesAt(0).length, 9);
    });

    test('every particle position stays within the unit box over time', () {
      for (final type in MazeAmbientParticleType.values) {
        final field = AmbientParticleField(type: type, seed: 3);
        for (var t = 0.0; t < 120; t += 1.7) {
          for (final particle in field.particlesAt(t)) {
            expect(particle.position.x, inInclusiveRange(0.0, 1.0), reason: '$type at t=$t');
            expect(particle.position.y, inInclusiveRange(0.0, 1.0), reason: '$type at t=$t');
            expect(particle.opacity, inInclusiveRange(0.0, 1.0));
          }
        }
      }
    });

    test('is a pure function of time — same instant, same field', () {
      final field = AmbientParticleField(type: MazeAmbientParticleType.fireflies, seed: 7);

      final a = field.particlesAt(42.5);
      final b = field.particlesAt(42.5);

      for (var i = 0; i < a.length; i++) {
        expect(a[i].position, b[i].position);
        expect(a[i].opacity, b[i].opacity);
      }
    });

    test('a frozen clock (reduce motion) yields a frozen field', () {
      final field = AmbientParticleField(type: MazeAmbientParticleType.dust, seed: 4);

      final first = field.particlesAt(0);
      final second = field.particlesAt(0);

      for (var i = 0; i < first.length; i++) {
        expect(first[i].position, second[i].position);
      }
    });

    test('dust and fireflies actually move over time; stars do not drift position', () {
      final dust = AmbientParticleField(type: MazeAmbientParticleType.dust, seed: 1);
      final fireflies = AmbientParticleField(type: MazeAmbientParticleType.fireflies, seed: 1);
      final stars = AmbientParticleField(type: MazeAmbientParticleType.stars, seed: 1);

      bool anyMoved(AmbientParticleField field) {
        final a = field.particlesAt(0);
        final b = field.particlesAt(30);
        for (var i = 0; i < a.length; i++) {
          if (a[i].position != b[i].position) return true;
        }
        return false;
      }

      expect(anyMoved(dust), isTrue);
      expect(anyMoved(fireflies), isTrue);
      expect(anyMoved(stars), isFalse, reason: 'stars twinkle in place, they do not drift');
    });

    test('different seeds produce different layouts (not all particles stacked)', () {
      final a = AmbientParticleField(type: MazeAmbientParticleType.dust, seed: 1).particlesAt(0);
      final b = AmbientParticleField(type: MazeAmbientParticleType.dust, seed: 2).particlesAt(0);

      expect(a.map((p) => p.position).toList(), isNot(b.map((p) => p.position).toList()));
    });

    test('particles from the same field are already spread rather than clumped at one point', () {
      final field = AmbientParticleField(type: MazeAmbientParticleType.stars, seed: 5);
      final xs = field.particlesAt(0).map((p) => p.position.x).toSet();

      expect(xs.length, greaterThan(1));
    });
  });
}
