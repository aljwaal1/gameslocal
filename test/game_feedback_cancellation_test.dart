import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/core/game_feedback_cancellation.dart';

class _Audio {
  final calls = <String>[];
  String? blocked;
  final gate = Completer<void>();
  Future<void> call(String name) async {
    calls.add(name);
    if (name == blocked) await gate.future;
  }

  late final channel = GameFeedbackAudioChannel(
    stop: () => call('stop'),
    setVolume: (_) => call('volume'),
    setSourceBytes: (_) => call('source'),
    resume: () => call('resume'),
  );
  Future<void> play(GameFeedbackCancellation token) =>
      channel.play(bytes: Uint8List(1), volume: .5, cancellation: token);
}

Future<void> _flush() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.value();
  }
}

void main() {
  for (final blocked in ['stop', 'volume', 'source', 'resume']) {
    test('cancellation during $blocked prevents every later preparation step',
        () async {
      final audio = _Audio()..blocked = blocked;
      final token = GameFeedbackCancellation();
      final pending = audio.play(token);
      await _flush();
      expect(audio.calls.last, blocked);
      token.cancel();
      audio.gate.complete();
      await pending;
      await _flush();
      final allowed = ['stop', 'volume', 'source', 'resume'];
      expect(audio.calls.where((e) => e != 'stop'),
          allowed.take(allowed.indexOf(blocked) + 1).where((e) => e != 'stop'));
      if (blocked == 'resume') expect(audio.calls.last, 'stop');
    });
  }
  test('cancelling started cue stops it once; cancellation is idempotent',
      () async {
    final audio = _Audio();
    final token = GameFeedbackCancellation();
    await audio.play(token);
    token.cancel();
    token.cancel();
    await _flush();
    expect(audio.calls, ['stop', 'volume', 'source', 'resume', 'stop']);
  });
  test('stale cancellation never stops a newer owner on a reused player',
      () async {
    final audio = _Audio();
    final old = GameFeedbackCancellation();
    await audio.play(old);
    final fresh = GameFeedbackCancellation();
    await audio.play(fresh);
    final before = List<String>.of(audio.calls);
    old.cancel();
    await _flush();
    expect(audio.calls, before);
    fresh.cancel();
    await _flush();
    expect(audio.calls.length, before.length + 1);
  });
  test('old cancellation stop completing after reuse cannot stop the new sound',
      () async {
    final audio = _Audio();
    final old = GameFeedbackCancellation();
    await audio.play(old);
    audio.blocked = 'stop';
    old.cancel();
    await _flush();
    expect(audio.calls.last, 'stop');
    audio.blocked = null;
    final fresh = GameFeedbackCancellation();
    final newPlay = audio.play(fresh);
    await _flush();
    expect(audio.calls.where((e) => e == 'resume').length, 1);
    audio.gate.complete();
    await newPlay;
    expect(audio.calls, [
      'stop',
      'volume',
      'source',
      'resume',
      'stop',
      'stop',
      'volume',
      'source',
      'resume'
    ]);
    await _flush();
    expect(audio.calls.last, 'resume');
  });
  test(
      'reuse while old resume awaits serializes old completion before new sound',
      () async {
    final audio = _Audio()..blocked = 'resume';
    final old = GameFeedbackCancellation();
    final oldPlay = audio.play(old);
    await _flush();
    old.cancel();
    audio.blocked = null;
    final fresh = GameFeedbackCancellation();
    final newPlay = audio.play(fresh);
    audio.gate.complete();
    await Future.wait([oldPlay, newPlay]);
    expect(audio.calls, [
      'stop',
      'volume',
      'source',
      'resume',
      'stop',
      'volume',
      'source',
      'resume'
    ]);
    old.cancel();
    await _flush();
    expect(audio.calls.last, 'resume');
  });
}
