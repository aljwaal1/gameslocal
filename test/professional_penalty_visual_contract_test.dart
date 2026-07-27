import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('penalty mode keeps slow staged motion and stable full composition', () {
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
    expect(gameSource, contains('Duration(milliseconds: 1350)'));
    expect(gameSource, contains('Duration(milliseconds: 1250)'));
    expect(gameSource, contains("'targetX': targetX"));
    expect(gameSource, contains("'power': _shotPower"));
    expect(gameSource, contains('_robotShot()'));
    expect(gameSource, contains('LocalNetworkCore? networkCore'));

    expect(compatibilityScene, contains('class ProfessionalPenaltyScene'));
    expect(compatibilityScene, contains('StablePenaltyScene'));
    expect(stableScene, contains('class StablePenaltyScene'));
    expect(stableScene, contains('fit: BoxFit.contain'));
    expect(stableScene, contains("'stable-full-player-keeper-scene'"));
    expect(stableScene, contains('_ShotOverlayPainter'));
    expect(stableScene, contains('_TargetReticle'));
    expect(stableScene, isNot(contains('fit: BoxFit.cover')));
    expect(stableScene, isNot(contains('Transform.scale')));
  });
}
