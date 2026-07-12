import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/chicken/chicken_achievements.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('accepts valid round stats and unlocks matching achievements', () async {
    final unlocked = await ChickenAchievements.evaluateRound(
      score: 1000,
      hits: 15,
      accuracy: 100,
      bestCombo: 10,
      coins: 3,
    );

    expect(
      unlocked.map((achievement) => achievement.id),
      containsAll(<String>[
        'first_hit',
        'score_500',
        'score_1000',
        'combo_10',
        'accuracy_90',
        'perfect_15',
        'coins_3',
      ]),
    );
  });

  test('1000-point achievement respects the exact score boundary', () async {
    final belowThreshold = await ChickenAchievements.evaluateRound(
      score: 999,
      hits: 10,
      accuracy: 80,
      bestCombo: 5,
      coins: 0,
    );
    expect(
      belowThreshold.map((achievement) => achievement.id),
      isNot(contains('score_1000')),
    );

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final atThreshold = await ChickenAchievements.evaluateRound(
      score: 1000,
      hits: 10,
      accuracy: 80,
      bestCombo: 5,
      coins: 0,
    );
    expect(
      atThreshold.map((achievement) => achievement.id),
      contains('score_1000'),
    );
  });

  test('perfect round requires both full accuracy and enough hits', () async {
    final tooFewHits = await ChickenAchievements.evaluateRound(
      score: 400,
      hits: 14,
      accuracy: 100,
      bestCombo: 8,
      coins: 0,
    );
    expect(tooFewHits.map((achievement) => achievement.id), isNot(contains('perfect_15')));

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final missedShot = await ChickenAchievements.evaluateRound(
      score: 400,
      hits: 15,
      accuracy: 99,
      bestCombo: 8,
      coins: 0,
    );
    expect(missedShot.map((achievement) => achievement.id), isNot(contains('perfect_15')));
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

  test('rejects non-zero accuracy when a round has no hits', () async {
    expect(
      () => ChickenAchievements.evaluateRound(
        score: 0,
        hits: 0,
        accuracy: 100,
        bestCombo: 0,
        coins: 0,
      ),
      throwsArgumentError,
    );
  });

  test('accepts a zero-accuracy round with no hits', () async {
    final unlocked = await ChickenAchievements.evaluateRound(
      score: 0,
      hits: 0,
      accuracy: 0,
      bestCombo: 0,
      coins: 0,
    );

    expect(unlocked, isEmpty);
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
