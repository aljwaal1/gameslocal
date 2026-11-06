import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/core/app_settings.dart';
import 'package:gameslocal/core/audio_feedback.dart';
import 'package:gameslocal/games/football/world_class_penalty_game_v2.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <String>[];
  final haptics = <String>[];
  Completer<void>? stopGate;
  setUpAll(() {
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global'), (_) async => null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global/events'),
        (_) async => null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'), (call) async {
      final id = (call.arguments as Map)['playerId'];
      if (call.method == 'create') {
        messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$id'),
            (_) async => null);
      }
      calls.add(call.method);
      if (call.method == 'stop') await stopGate?.future;
      if (call.method == 'setSourceBytes') {
        messenger.handlePlatformMessage(
            'xyz.luan/audioplayers/events/$id',
            const StandardMethodCodec().encodeSuccessEnvelope(
                {'event': 'audio.onPrepared', 'value': true}),
            (_) {});
      }
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add(call.arguments as String);
      }
      return null;
    });
  });
  setUp(() {
    calls.clear();
    haptics.clear();
    stopGate = null;
    AppSettingsController.instance.soundEnabled = true;
    AppSettingsController.instance.vibrationEnabled = true;
  });
  Future<void> flush() async {
    for (var i = 0; i < 60; i++) {
      await Future<void>.value();
    }
  }

  test('selection feedback preserves haptic-only input even with sound enabled',
      () async {
    await GameFeedback.selection();
    expect(calls, isEmpty);
    expect(haptics, ['HapticFeedbackType.selectionClick']);
    AppSettingsController.instance.vibrationEnabled = false;
    await GameFeedback.selection();
    expect(haptics.length, 1);
  });
  test('GameFeedback kick haptic is immediate while backend stop is blocked',
      () async {
    stopGate = Completer<void>();
    final cancellation = GameFeedbackCancellation();
    final feedback = GameFeedback.kick(GameAudioTheme.football, cancellation);
    await flush();
    expect(calls, contains('stop'));
    expect(haptics, ['HapticFeedbackType.lightImpact']);
    expect(calls, isNot(contains('setVolume')));
    cancellation.cancel();
    stopGate!.complete();
    await feedback;
    await flush();
    expect(calls, isNot(contains('setSourceBytes')));
    expect(calls, isNot(contains('resume')));
  });
  for (final cue in [GameFeedback.win, GameFeedback.lose, GameFeedback.error]) {
    test(
        'outcome/match cue cancellation during preparation never resumes audio: $cue',
        () async {
      stopGate = Completer<void>();
      final token = GameFeedbackCancellation();
      final pending = cue(GameAudioTheme.football, token);
      await flush();
      expect(calls, contains('stop'));
      expect(haptics.length, 1);
      token.cancel();
      stopGate!.complete();
      await pending;
      await flush();
      expect(calls, isNot(contains('resume')));
    });
  }
  test(
      'actual game next shot cancels prior pending kick/outcome; removal cancels the new shot',
      () async {
    stopGate = Completer<void>();
    final game = CinematicPenaltyGame(championsMode: false);
    game.shoot(aim: const Offset(.4, .4), power: .8, curve: 0);
    game.update(game.shotDuration * .35);
    await flush();
    expect(calls, contains('stop'));
    game.update(game.shotDuration * .52);
    await flush();
    expect(game.playerShots, 1);
    game.update(1.2);
    expect(game.phase, PenaltyPhase.saving);
    game.chooseDive(const Offset(.3, .4));
    game.update(game.shotDuration * .35);
    await flush();
    game.onRemove();
    stopGate!.complete();
    await flush();
    game.update(3);
    expect(game.robotShots, 0);
    expect(calls, isNot(contains('resume')));
    game.hud.dispose();
  });
  test('actual game pause/resume cancels pending audio before it can start',
      () async {
    stopGate = Completer<void>();
    final game = CinematicPenaltyGame(championsMode: false);
    game.shoot(aim: const Offset(.4, .4), power: .8, curve: 0);
    game.update(game.shotDuration * .35);
    await flush();
    game.pauseEngine();
    game.resumeEngine();
    stopGate!.complete();
    await flush();
    game.update(3);
    expect(game.playerShots, 0);
    expect(calls, isNot(contains('resume')));
    game.onRemove();
    game.hud.dispose();
  });
  test('pre-cancelled win lose error and outcome cues are silent', () async {
    final cancelled = GameFeedbackCancellation()..cancel();
    await Future.wait([
      GameFeedback.win(GameAudioTheme.football, cancelled),
      GameFeedback.lose(GameAudioTheme.football, cancelled),
      GameFeedback.error(GameAudioTheme.football, cancelled),
      GameFeedback.goal(GameAudioTheme.football, cancelled),
      GameFeedback.save(GameAudioTheme.football, cancelled),
      GameFeedback.post(GameAudioTheme.football, cancelled),
    ]);
    expect(calls, isEmpty);
    expect(haptics, isEmpty);
  });
  test('existing no-token feedback calls still prepare and play audio',
      () async {
    await GameFeedback.win(GameAudioTheme.chess);
    expect(calls,
        containsAllInOrder(['stop', 'setVolume', 'setSourceBytes', 'resume']));
    expect(haptics, ['HapticFeedbackType.mediumImpact']);
  });
}
