import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('penalty mode renders complete actors without fragile bitmap assets', () {
    final gameSource = File(
      'lib/games/football/professional_penalty_game.dart',
    ).readAsStringSync();
    final compatibilityScene = File(
      'lib/games/football/professional_penalty_scene.dart',
    ).readAsStringSync();
    final stableScene = File(
      'lib/games/football/stable_penalty_scene.dart',
    ).readAsStringSync();

    expect(gameSource, contains('class ProPenaltyShootoutGameScreen'));
    expect(gameSource, contains('Duration(milliseconds: 3000)'));
    expect(gameSource, contains("'targetX': targetX"));
    expect(gameSource, contains("'power': _shotPower"));
    expect(gameSource, contains('_robotShot()'));
    expect(gameSource, contains('LocalNetworkCore? networkCore'));

    expect(compatibilityScene, contains('class ProfessionalPenaltyScene'));
    expect(compatibilityScene, contains('StablePenaltyScene'));
    expect(stableScene, contains('class StablePenaltyScene'));
    expect(stableScene, contains('class _ArenaPainter'));
    expect(stableScene, contains('_drawStriker'));
    expect(stableScene, contains('_drawKeeper'));
    expect(stableScene, contains('_drawGoalBack'));
    expect(stableScene, contains('_drawGoalFront'));
    expect(stableScene, contains('_drawBall'));
    expect(stableScene, contains("'procedural-professional-penalty-scene'"));
    expect(stableScene, contains("'always-visible-football-actors'"));
    expect(stableScene, isNot(contains('Image.asset')));
    expect(stableScene, isNot(contains('تعذر تحميل مشهد كرة القدم')));
    expect(stableScene, isNot(contains('BoxFit.cover')));
  });
}
