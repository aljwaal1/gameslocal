import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('professional penalty mode keeps precise aiming and SVG animation', () {
    final gameSource = File(
      'lib/games/football/professional_penalty_game.dart',
    ).readAsStringSync();
    final compatibilityScene = File(
      'lib/games/football/professional_penalty_scene.dart',
    ).readAsStringSync();
    final realisticScene = File(
      'lib/games/football/realistic_penalty_scene.dart',
    ).readAsStringSync();
    final spriteSource = File(
      'lib/games/football/realistic_football_sprite.dart',
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

    expect(compatibilityScene, contains('class ProfessionalPenaltyScene'));
    expect(compatibilityScene, contains('RealisticPenaltyScene'));
    expect(realisticScene, contains('class RealisticPenaltyScene'));
    expect(realisticScene, contains('RealisticFootballSprite'));
    expect(realisticScene, contains('_quadraticBezier'));
    expect(realisticScene, contains('_drawNetImpact'));
    expect(realisticScene, isNot(contains('_drawFootballerBody')));
    expect(realisticScene, isNot(contains('_drawKeeperBody')));

    expect(spriteSource, contains('SvgPicture.string'));
    expect(spriteSource, contains('player_ready.svg'));
    expect(spriteSource, contains('player_run.svg'));
    expect(spriteSource, contains('player_kick.svg'));
    expect(spriteSource, contains('keeper_ready.svg'));
    expect(spriteSource, contains('keeper_dive.svg'));

    for (final asset in <String>[
      'assets/football/player_ready.svg',
      'assets/football/player_run.svg',
      'assets/football/player_kick.svg',
      'assets/football/keeper_ready.svg',
      'assets/football/keeper_dive.svg',
    ]) {
      expect(File(asset).existsSync(), isTrue, reason: 'Missing $asset');
    }

    expect(activationSource, contains('ProPenaltyShootoutGameScreen'));
    expect(activationSource, contains('professional_penalty_game.dart'));
  });
}
