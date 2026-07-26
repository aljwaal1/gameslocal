import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('penalty mode keeps slow staged motion and real photo frames', () {
    final gameSource = File(
      'lib/games/football/professional_penalty_game.dart',
    ).readAsStringSync();
    final compatibilityScene = File(
      'lib/games/football/professional_penalty_scene.dart',
    ).readAsStringSync();
    final realisticScene = File(
      'lib/games/football/realistic_penalty_scene.dart',
    ).readAsStringSync();
    final frameSource = File(
      'lib/games/football/realistic_football_sprite.dart',
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
    expect(compatibilityScene, contains('RealisticPenaltyScene'));
    expect(realisticScene, contains('class RealisticPenaltyScene'));
    expect(realisticScene, contains('final runT = _phase(0.12, 0.47'));
    expect(realisticScene, contains('final keeperDiveT = _phase(0.66, 0.92'));
    expect(realisticScene, contains('final flightT = _phase(0.60, 0.86'));
    expect(realisticScene, contains('AnimatedSwitcher'));
    expect(realisticScene, contains('_quadraticBezier'));
    expect(realisticScene, contains('_drawNetImpact'));
    expect(realisticScene, isNot(contains('_drawFootballerBody')));
    expect(realisticScene, isNot(contains('_drawKeeperBody')));

    expect(frameSource, contains('Image.asset'));
    expect(frameSource, contains('assets/football/photo/player_ready.jpg'));
    expect(frameSource, contains('assets/football/photo/player_run.jpg'));
    expect(frameSource, contains('assets/football/photo/player_kick.jpg'));
    expect(frameSource, contains('assets/football/photo/keeper_ready.jpg'));
    expect(frameSource, contains('assets/football/photo/keeper_dive.jpg'));
    expect(frameSource, isNot(contains('SvgPicture')));

    for (final asset in <String>[
      'assets/football/photo/player_ready.jpg',
      'assets/football/photo/player_run.jpg',
      'assets/football/photo/player_kick.jpg',
      'assets/football/photo/keeper_ready.jpg',
      'assets/football/photo/keeper_dive.jpg',
      'assets/football/photo/SOURCES.md',
    ]) {
      final file = File(asset);
      expect(file.existsSync(), isTrue, reason: 'Missing $asset');
      expect(file.lengthSync(), greaterThan(20000), reason: 'Invalid $asset');
    }
  });
}
