import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/services/find_my_ayah_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FindMyAyahProgress', () {
    test('a fresh install has nothing visited', () async {
      expect(await FindMyAyahProgress.instance.visitedSituationIds(), isEmpty);
    });

    test('markVisited grows the set and reports true only the first time', () async {
      expect(await FindMyAyahProgress.instance.markVisited('anxiety'), isTrue);
      expect(await FindMyAyahProgress.instance.markVisited('anxiety'), isFalse);
      expect(await FindMyAyahProgress.instance.visitedSituationIds(), {'anxiety'});

      expect(await FindMyAyahProgress.instance.markVisited('fear'), isTrue);
      expect(await FindMyAyahProgress.instance.visitedSituationIds(), {'anxiety', 'fear'});
    });

    test('isFirstCheckInToday is true until markCheckedInToday is called', () async {
      expect(await FindMyAyahProgress.instance.isFirstCheckInToday(), isTrue);
      await FindMyAyahProgress.instance.markCheckedInToday();
      expect(await FindMyAyahProgress.instance.isFirstCheckInToday(), isFalse);
    });
  });

  group('findMyAyahMilestoneWeight', () {
    test('an ordinary check-in that crosses no milestone weighs 1', () {
      expect(findMyAyahMilestoneWeight(visitedCountBefore: 3, visitedCountAfter: 4), 1);
      expect(findMyAyahMilestoneWeight(visitedCountBefore: 4, visitedCountAfter: 4), 1);
    });

    test('crossing a milestone threshold weighs more', () {
      expect(findMyAyahMilestoneWeight(visitedCountBefore: 9, visitedCountAfter: 10), greaterThan(1));
      expect(findMyAyahMilestoneWeight(visitedCountBefore: 19, visitedCountAfter: 20), greaterThan(1));
      expect(findMyAyahMilestoneWeight(visitedCountBefore: 39, visitedCountAfter: 40), greaterThan(1));
    });

    test('landing exactly on a milestone from further below still counts as crossing it', () {
      // e.g. a milestone situation reached via search/saved rather than
      // one-at-a-time sequential discovery.
      expect(findMyAyahMilestoneWeight(visitedCountBefore: 5, visitedCountAfter: 10), greaterThan(1));
    });
  });
}
