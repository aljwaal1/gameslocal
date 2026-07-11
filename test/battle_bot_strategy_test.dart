import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/battle/battle_bot_strategy.dart';

void main() {
  test('seeks a nearby health pickup when health is low', () {
    expect(
      chooseBattleBotGoal(
        health: 30,
        pickupVisible: true,
        pickupDistance: 0.5,
        difficulty: 'متوسط',
        decisionRoll: 0.9,
      ),
      BattleBotGoal.seekHealth,
    );
  });

  test('seeks health at the exact low-health and reach boundaries', () {
    expect(
      chooseBattleBotGoal(
        health: 35,
        pickupVisible: true,
        pickupDistance: 0.9,
        difficulty: 'متوسط',
        decisionRoll: 0.99,
      ),
      BattleBotGoal.seekHealth,
    );
  });

  test('retreats at critical health without a reachable pickup', () {
    expect(
      chooseBattleBotGoal(
        health: 18,
        pickupVisible: false,
        pickupDistance: 2,
        difficulty: 'صعب',
        decisionRoll: 0,
      ),
      BattleBotGoal.retreat,
    );
  });

  test('retreats at the exact critical-health boundary', () {
    expect(
      chooseBattleBotGoal(
        health: 22,
        pickupVisible: false,
        pickupDistance: 2,
        difficulty: 'صعب',
        decisionRoll: 0,
      ),
      BattleBotGoal.retreat,
    );
  });

  test('hard bot pursues more often than easy bot', () {
    const roll = 0.7;
    expect(
      chooseBattleBotGoal(
        health: 80,
        pickupVisible: false,
        pickupDistance: 2,
        difficulty: 'صعب',
        decisionRoll: roll,
      ),
      BattleBotGoal.chase,
    );
    expect(
      chooseBattleBotGoal(
        health: 80,
        pickupVisible: false,
        pickupDistance: 2,
        difficulty: 'سهل',
        decisionRoll: roll,
      ),
      BattleBotGoal.wander,
    );
  });
}
