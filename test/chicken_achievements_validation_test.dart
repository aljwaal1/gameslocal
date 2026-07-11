import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/chicken/chicken_achievements.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('accepts valid round stats and unlocks matching achievements', () async {
    final unlocked = await ChickenAchievements.evaluateRound(
      score: 500,
      hits: 10,
      accuracy: 90,
      bestCombo: 10,
      coins: 3,
    );

    expect(
      unlocked.map((achievement) => achievement.id),
      containsAll(<String>[
        'first_hit',
        'score_500',
        'combo_10',
        'accuracy_90',
        'coins_3',
      ]),
    );
  });

  test('rejects accuracy outside the supported range', () async {
    expect(
      () => ChickenAchievements.evaluateRound(
        score: 0,
        hits: 0,
        accuracy: 101,
        bestCombo: 0,
        coins: 0,
      ),
      throwsArgumentError,
    );
  });

  test('rejects impossible combo larger than hit count', () async {
    expect(
      () => ChickenAchievements.evaluateRound(
        score: 100,
        hits: 2,
        accuracy: 100,
        bestCombo: 3,
        coins: 0,
      ),
      throwsArgumentError,
    );
  });

  test('rejects negative counters', () async {
    expect(
      () => ChickenAchievements.evaluateRound(
        score: 0,
        hits: -1,
        accuracy: 0,
        bestCombo: 0,
        coins: 0,
      ),
      throwsArgumentError,
    );
  });
}
