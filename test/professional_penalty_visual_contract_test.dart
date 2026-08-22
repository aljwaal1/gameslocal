import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('penalty mode uses the cinematic arena and keeps LAN compatibility', () {
    final compatibilityEntry = File(
      'lib/games/football/professional_penalty_game.dart',
    ).readAsStringSync();
    final gameSource = File(
      'lib/games/football/world_class_penalty_game_v2.dart',
    ).readAsStringSync();
    final compatibilityScene = File(
      'lib/games/football/professional_penalty_scene.dart',
    ).readAsStringSync();
    final stableScene = File(
      'lib/games/football/stable_penalty_scene.dart',
    ).readAsStringSync();

    // The public entry point stays stable while the production implementation
    // uses the cinematic arena. Network sessions still delegate to the
    // established compatible implementation.
    expect(
      compatibilityEntry,
      contains(
        "export 'world_class_penalty_game_v2.dart' show ProPenaltyShootoutGameScreen;",
      ),
    );

    expect(gameSource, contains('class ProPenaltyShootoutGameScreen'));
    expect(gameSource, contains('LocalNetworkCore? networkCore'));
    expect(
      gameSource,
      contains('legacy.ProPenaltyShootoutGameScreen(networkCore: networkCore)'),
    );
    expect(gameSource, contains('class CinematicPenaltyGame extends FlameGame'));
    expect(gameSource, contains('GameWidget<CinematicPenaltyGame>'));
    expect(
      gameSource,
      contains('GameFeedback.kick(GameAudioTheme.football)'),
    );
    expect(
      gameSource,
      contains('GameFeedback.goal(GameAudioTheme.football)'),
    );
    expect(gameSource, contains('_drawSkyAndStadium'));
    expect(gameSource, contains('_drawPitch'));
    expect(gameSource, contains('_drawGoal'));
    expect(gameSource, contains('_drawKeeper'));
    expect(
      gameSource,
      contains("_loadAssetImage('assets/football/keeper_pro_v2.png')"),
    );
    expect(
      gameSource,
      contains("_loadAssetImage('assets/football/keeper_dive_pro_v2.png')"),
    );
    expect(gameSource, contains('canvas.drawImageRect'));
    expect(File('assets/football/keeper_pro_v2.png').existsSync(), isTrue);
    expect(
      File('assets/football/keeper_dive_pro_v2.png').existsSync(),
      isTrue,
    );
    expect(gameSource, contains('_drawPlayer'));
    expect(gameSource, contains('_drawBall'));
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
