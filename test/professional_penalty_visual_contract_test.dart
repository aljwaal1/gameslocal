import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('professional penalty mode keeps precise aiming and animated scene', () {
    final gameSource = File(
      'lib/games/football/professional_penalty_game.dart',
    ).readAsStringSync();
    final sceneSource = File(
      'lib/games/football/professional_penalty_scene.dart',
    ).readAsStringSync();
    final activationSource = File(
      'tools/activate_penalty_game.py',
    ).readAsStringSync();

    expect(gameSource, contains('class ProPenaltyShootoutGameScreen'));
    expect(gameSource, contains('AnimationController'));
    expect(gameSource, contains("'targetX': targetX"));
    expect(gameSource, contains("'power': _shotPower"));
    expect(gameSource, contains('_robotShot()'));
    expect(gameSource, contains('LocalNetworkCore? networkCore'));

    expect(sceneSource, contains('class ProfessionalPenaltyScene'));
    expect(sceneSource, contains('class _PenaltyArenaPainter'));
    expect(sceneSource, contains('_drawFootballerBody'));
    expect(sceneSource, contains('_drawKeeperBody'));
    expect(sceneSource, contains('_quadraticBezier'));
    expect(sceneSource, contains('_drawNetImpact'));
    expect(sceneSource, isNot(contains('class _PlayerPainter')));

    expect(activationSource, contains('ProPenaltyShootoutGameScreen'));
    expect(activationSource, contains('professional_penalty_game.dart'));
  });
}
