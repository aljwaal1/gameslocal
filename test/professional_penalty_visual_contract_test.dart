import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('penalty mode keeps the production photo arena and LAN compatibility', () {
    final compatibilityEntry = File(
      'lib/games/football/professional_penalty_game.dart',
    ).readAsStringSync();
    final gameSource = File(
      'lib/games/football/photo_penalty_game_v3.dart',
    ).readAsStringSync();
    final compatibilityScene = File(
      'lib/games/football/professional_penalty_scene.dart',
    ).readAsStringSync();
    final stableScene = File(
      'lib/games/football/stable_penalty_scene.dart',
    ).readAsStringSync();

    // The public entry point intentionally stays a compatibility export while
    // the current production implementation lives in photo_penalty_game_v3.
    expect(
      compatibilityEntry,
      contains(
        "export 'photo_penalty_game_v3.dart' show ProPenaltyShootoutGameScreen;",
      ),
    );

    expect(gameSource, contains('class ProPenaltyShootoutGameScreen'));
    expect(gameSource, contains('LocalNetworkCore? networkCore'));
    expect(
      gameSource,
      contains('legacy.ProPenaltyShootoutGameScreen(networkCore: networkCore)'),
    );
    expect(gameSource, contains('Duration(milliseconds: 1180)'));
    expect(gameSource, contains('Future<void> _shootPlayer'));
    expect(gameSource, contains('Future<void> _shootRobot'));
    expect(gameSource, contains('Future<void> _animateShot()'));
    expect(gameSource, contains('GameFeedback.kick()'));
    expect(gameSource, contains("'assets/football/pro_penalty_arena.jpg'"));
    expect(gameSource, contains('RealisticFootballSprite'));
    expect(gameSource, contains('_GoalGridPainter'));
    expect(gameSource, contains('fit: StackFit.expand'));

    // Keep the compatibility scene contract protected as well because the LAN
    // implementation can still delegate to the established stable scene.
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
