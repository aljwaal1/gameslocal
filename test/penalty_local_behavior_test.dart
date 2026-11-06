import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/core/app_settings.dart';
import 'package:gameslocal/games/football/world_class_penalty_game_v2.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cues = <String>[];
  setUp(() {
    AppSettingsController.instance.soundEnabled = false;
    AppSettingsController.instance.vibrationEnabled = true;
    cues.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        cues.add(call.arguments as String);
      }
      return null;
    });
  });
  tearDown(() {
    AppSettingsController.instance.soundEnabled = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
  test('paused game rejects shooting and keeper input before resume', () {
    final game = CinematicPenaltyGame(championsMode: false);
    game.pauseEngine();
    expect(game.canShoot, isFalse);
    game.shoot(aim: const Offset(.4, .4), power: .8, curve: 0);
    expect(game.phase, PenaltyPhase.aiming);
    game.phase = PenaltyPhase.saving;
    expect(game.canDive, isFalse);
    game.chooseDive(const Offset(.2, .3));
    expect(game.phase, PenaltyPhase.saving);
    game.resumeEngine();
    expect(game.canDive, isTrue);
    game.onRemove();
    game.hud.dispose();
  });
  test('actual game contacts once, scores at arrival, and completes landing',
      () async {
    final game = CinematicPenaltyGame(championsMode: false);
    game.shoot(aim: const Offset(.4, .4), power: .8, curve: 0);
    await Future<void>.value();
    expect(cues, isEmpty, reason: 'no kick at approach start');
    game.update(game.shotDuration * .339);
    expect(game.playerShots, 0);
    expect(cues, isEmpty);
    game.update(game.shotDuration * .002);
    await Future<void>.value();
    expect(cues, ['HapticFeedbackType.lightImpact']);
    game.update(game.shotDuration * .518);
    expect(game.playerShots, 0);
    game.update(game.shotDuration * .002);
    expect(game.playerShots, 1);
    expect(game.hud.value.playerResults.length, 1);
    expect(game.phase, PenaltyPhase.result);
    expect(game.flight, lessThan(1));
    game.update(game.shotDuration * .139);
    expect(game.flight, closeTo(1, 1e-8));
    expect(game.playerShots, 1);
    game.onRemove();
    game.hud.dispose();
  });
  for (final remove in [false, true]) {
    test(
        '${remove ? 'removal' : 'pause/resume'} cancels active shot without late cues or score',
        () async {
      final game = CinematicPenaltyGame(championsMode: false);
      game.shoot(aim: const Offset(.4, .4), power: .8, curve: 0);
      if (remove) {
        game.onRemove();
      } else {
        game.pauseEngine();
        game.resumeEngine();
      }
      cues.clear();
      game.update(2);
      await Future<void>.value();
      expect(game.playerShots, 0);
      expect(cues, isEmpty);
      game.hud.dispose();
    });
  }
}
