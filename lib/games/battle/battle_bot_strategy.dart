enum BattleBotGoal { chase, retreat, seekHealth, wander }

BattleBotGoal chooseBattleBotGoal({
  required int health,
  required bool pickupVisible,
  required double pickupDistance,
  required String difficulty,
  required double decisionRoll,
}) {
  if (health < 35 && pickupVisible && pickupDistance < 0.9) {
    return BattleBotGoal.seekHealth;
  }
  if (health < 22) return BattleBotGoal.retreat;

  final chaseThreshold = switch (difficulty) {
    'صعب' => 0.88,
    'سهل' => 0.48,
    _ => 0.68,
  };
  return decisionRoll < chaseThreshold ? BattleBotGoal.chase : BattleBotGoal.wander;
}
