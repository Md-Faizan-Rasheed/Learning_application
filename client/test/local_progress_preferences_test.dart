import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/services/local_progress_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('legacy progress is migrated to the currently signed-in account once',
      () async {
    SharedPreferences.setMockInitialValues({
      'session': jsonEncode({'user_id': 'account-a'}),
      'word_search_stats': '{"Prophets":{"easy":{"bestSeconds":42}}}',
    });
    final prefs = await SharedPreferences.getInstance();

    final accountAKey =
        await LocalProgressPreferences.keyFor('word_search_stats');
    expect(prefs.getString(accountAKey), contains('bestSeconds'));

    await prefs.setString(
      'session',
      jsonEncode({'user_id': 'account-b'}),
    );
    final accountBKey =
        await LocalProgressPreferences.keyFor('word_search_stats');

    expect(prefs.getString(accountBKey), isNull);
    expect(prefs.getString(accountAKey), contains('bestSeconds'));
    // Keep the original key as a recovery copy; the migration marker prevents
    // it from being copied into every account on this device.
    expect(prefs.getString('word_search_stats'), contains('bestSeconds'));
  });

  test('legacy anonymous progress migrates into anonymous storage', () async {
    SharedPreferences.setMockInitialValues({
      'names_on_water_completed_chapters': ['2', '4'],
      'seerah_maze_ghost_level_3': '[]',
    });
    final prefs = await SharedPreferences.getInstance();

    final chaptersKey = await LocalProgressPreferences.keyFor(
      'names_on_water_completed_chapters',
    );
    final ghostKey =
        await LocalProgressPreferences.keyFor('seerah_maze_ghost_level_3');

    expect(chaptersKey, startsWith('local_progress.v1.anonymous.'));
    expect(prefs.getStringList(chaptersKey), ['2', '4']);
    expect(prefs.getString(ghostKey), '[]');
  });

  test('account namespaces remain separate after switching sessions', () async {
    SharedPreferences.setMockInitialValues({
      'session': jsonEncode({'user_id': 'account-a'}),
    });
    final prefs = await SharedPreferences.getInstance();
    final accountAKey =
        await LocalProgressPreferences.keyFor('seerah_maze_progress');
    await prefs.setString(accountAKey, 'progress-a');

    await prefs.setString(
      'session',
      jsonEncode({'user_id': 'account-b'}),
    );
    final accountBKey =
        await LocalProgressPreferences.keyFor('seerah_maze_progress');
    expect(accountBKey, isNot(accountAKey));
    expect(prefs.getString(accountBKey), isNull);
    expect(prefs.getString(accountAKey), 'progress-a');

    await prefs.remove('session');
    final anonymousKey =
        await LocalProgressPreferences.keyFor('seerah_maze_progress');
    expect(anonymousKey, isNot(accountAKey));
    expect(anonymousKey, isNot(accountBKey));
  });
}
