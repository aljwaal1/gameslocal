import 'dart:math' as math;

/// Solo checkpoints. One reserve plane is spent per crash or empty tank.
class PlaneCampaign {
  static const tank = 45.0;
  static const pickup = 13.0;
  static const startingLives = 3;

  int stage = 1;
  int lives = startingLives;
  double travel = 0;
  int gateHealth = 0;
  int get gateCapacity => 8 + math.min(10, (stage - 1) * 2);
  double get stageLength => 360 + math.min(240, (stage - 1) * 40);
  bool get gateReady => travel >= stageLength;

  static double fuelDrain({bool boosting = false}) => boosting ? .11 : .076;
  static double speedFactor({bool boosting = false}) => boosting ? 1.65 : 1;

  void advance(double ticks, {bool boosting = false}) {
    travel += ticks * speedFactor(boosting: boosting);
  }

  void openGate() {
    if (gateReady && gateHealth == 0) gateHealth = gateCapacity;
  }

  bool hitGate() {
    if (gateHealth == 0 || --gateHealth > 0) return false;
    stage++;
    travel = 0;
    return true;
  }

  bool loseLife() {
    if (lives > 0) lives--;
    travel = 0;
    gateHealth = 0;
    return lives > 0;
  }
}
