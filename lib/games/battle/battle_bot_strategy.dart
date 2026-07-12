enum BattleBotGoal { chase, retreat, seekHealth, wander }

const _supportedBattleDifficulties = {'سهل', 'متوسط', 'صعب'};
const _criticalHealthThreshold = 22;
const _criticalPickupReach = 0.45;
const _lowHealthThreshold = 35;
const _lowHealthPickupReach = 0.9;

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
  if (pickupVisible && (!pickupDistance.isFinite || pickupDistance < 0)) {
    throw ArgumentError.value(
      pickupDistance,
      'pickupDistance',
      'must be a finite value that is zero or greater when a pickup is visible',
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

  if (health <= _criticalHealthThreshold) {
    if (pickupVisible && pickupDistance <= _criticalPickupReach) {
      return BattleBotGoal.seekHealth;
    }
    return BattleBotGoal.retreat;
  }
  if (
    health <= _lowHealthThreshold &&
    pickupVisible &&
    pickupDistance <= _lowHealthPickupReach
  ) {
    return BattleBotGoal.seekHealth;
  }

  final chaseThreshold = switch (difficulty) {
    'صعب' => 0.88,
    'سهل' => 0.48,
    _ => 0.68,
  };
  return decisionRoll < chaseThreshold ? BattleBotGoal.chase : BattleBotGoal.wander;
}
