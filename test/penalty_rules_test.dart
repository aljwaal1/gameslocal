import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/football/penalty_rules.dart';

void main() {
  test('shootout ends early when trailing side cannot recover', () {
    expect(
      PenaltyRules.isFinished(
        playerGoals: 3,
        robotGoals: 0,
        playerShots: 3,
        robotShots: 3,
      ),
      isTrue,
    );
  });

  test('shootout continues while trailing side can still recover', () {
    expect(
      PenaltyRules.isFinished(
        playerGoals: 2,
        robotGoals: 0,
        playerShots: 3,
        robotShots: 3,
      ),
      isFalse,
    );
  });

  test('sudden death waits until both sides have taken the same shots', () {
    expect(
      PenaltyRules.isFinished(
        playerGoals: 5,
        robotGoals: 4,
        playerShots: 6,
        robotShots: 5,
      ),
      isFalse,
    );
    expect(
      PenaltyRules.isFinished(
        playerGoals: 5,
        robotGoals: 4,
        playerShots: 6,
        robotShots: 6,
      ),
      isTrue,
    );
  });
}
