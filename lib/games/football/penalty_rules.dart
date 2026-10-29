class PenaltyRules {
  const PenaltyRules._();

  static bool isFinished({
    required int playerGoals,
    required int robotGoals,
    required int playerShots,
    required int robotShots,
  }) {
    if (playerShots < 5 || robotShots < 5) {
      final playerRemaining = (5 - playerShots).clamp(0, 5);
      final robotRemaining = (5 - robotShots).clamp(0, 5);
      return playerGoals > robotGoals + robotRemaining ||
          robotGoals > playerGoals + playerRemaining;
    }
    return playerShots == robotShots && playerGoals != robotGoals;
  }
}
