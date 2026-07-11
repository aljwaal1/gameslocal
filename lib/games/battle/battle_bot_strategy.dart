enum BattleBotGoal { chase, retreat, seekHealth, wander }

const _supportedBattleDifficulties = {'سهل', 'متوسط', 'صعب'};

BattleBotGoal chooseBattleBotGoal({
  required int health,
  required bool pickupVisible,
  required double pickupDistance,
  required String difficulty,
  required double decisionRoll,
}) {
  if (health < 0 || health > 100) {
    throw ArgumentError.value(health, 'health', 'must be between 0 and 100');
  }
  if (pickupDistance.isNaN || pickupDistance < 0) {
    throw ArgumentError.value(
      pickupDistance,
      'pickupDistance',
      'must be zero or greater',
    );
  }
  if (!_supportedBattleDifficulties.contains(difficulty)) {
    throw ArgumentError.value(
      difficulty,
      'difficulty',
      'must be سهل, متوسط, or صعب',
    );
  }
  if (decisionRoll.isNaN || decisionRoll < 0 || decisionRoll > 1) {
    throw ArgumentError.value(
      decisionRoll,
      'decisionRoll',
      'must be between 0 and 1',
    );
  }

  if (health <= 35 && pickupVisible && pickupDistance <= 0.9) {
    return BattleBotGoal.seekHealth;
  }
  if (health <= 22) return BattleBotGoal.retreat;

  final chaseThreshold = switch (difficulty) {
    'صعب' => 0.88,
    'سهل' => 0.48,
    _ => 0.68,
  };
  return decisionRoll < chaseThreshold ? BattleBotGoal.chase : BattleBotGoal.wander;
}
