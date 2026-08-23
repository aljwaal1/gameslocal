import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'app_settings.dart';

enum GameSound {
  uiTap,
  tap,
  move,
  capture,
  win,
  lose,
  error,
  kick,
  goal,
  save,
  post,
}

/// A separate acoustic identity for every production game.
enum GameAudioTheme {
  system,
  football,
  xo,
  checkers,
  domino,
  chess,
  cards,
  word,
  beard,
  dots,
}

class GameFeedback {
  static final AppSettingsController _settings = AppSettingsController.instance;
  static final List<AudioPlayer> _players = List<AudioPlayer>.generate(
    4,
    (_) => AudioPlayer(),
  );
  static final Map<String, Uint8List> _cache = <String, Uint8List>{};
  static final Map<String, DateTime> _lastPlayed = <String, DateTime>{};
  static int _playerIndex = 0;

  static Future<void> uiTap() => _emit(
        GameSound.uiTap,
        vibration: false,
        volume: .12,
        minInterval: const Duration(milliseconds: 45),
      );

  static Future<void> tap([GameAudioTheme theme = GameAudioTheme.system]) => _emit(
        GameSound.tap,
        theme: theme,
        haptic: HapticFeedback.selectionClick,
        volume: .24,
        minInterval: const Duration(milliseconds: 35),
      );

  static Future<void> move([GameAudioTheme theme = GameAudioTheme.system]) => _emit(
        GameSound.move,
        theme: theme,
        haptic: HapticFeedback.lightImpact,
        volume: .34,
        minInterval: const Duration(milliseconds: 45),
      );

  static Future<void> capture([GameAudioTheme theme = GameAudioTheme.system]) => _emit(
        GameSound.capture,
        theme: theme,
        haptic: HapticFeedback.mediumImpact,
        volume: .42,
      );

  static Future<void> win([GameAudioTheme theme = GameAudioTheme.system]) => _emit(
        GameSound.win,
        theme: theme,
        haptic: HapticFeedback.mediumImpact,
        volume: .52,
      );

  static Future<void> lose([GameAudioTheme theme = GameAudioTheme.system]) => _emit(
        GameSound.lose,
        theme: theme,
        haptic: HapticFeedback.heavyImpact,
        volume: .48,
      );

  static Future<void> error([GameAudioTheme theme = GameAudioTheme.system]) => _emit(
        GameSound.error,
        theme: theme,
        haptic: HapticFeedback.heavyImpact,
        volume: .40,
      );

  static Future<void> kick([GameAudioTheme theme = GameAudioTheme.football]) => _emit(
        GameSound.kick,
        theme: theme,
        haptic: HapticFeedback.lightImpact,
        volume: .48,
      );

  static Future<void> goal([GameAudioTheme theme = GameAudioTheme.football]) => _emit(
        GameSound.goal,
        theme: theme,
        haptic: HapticFeedback.heavyImpact,
        volume: .58,
      );

  static Future<void> save([GameAudioTheme theme = GameAudioTheme.football]) => _emit(
        GameSound.save,
        theme: theme,
        haptic: HapticFeedback.mediumImpact,
        volume: .48,
      );

  static Future<void> post([GameAudioTheme theme = GameAudioTheme.football]) => _emit(
        GameSound.post,
        theme: theme,
        haptic: HapticFeedback.heavyImpact,
        volume: .55,
      );

  static Future<void> _emit(
    GameSound sound, {
    GameAudioTheme theme = GameAudioTheme.system,
    Future<void> Function()? haptic,
    bool vibration = true,
    double volume = .35,
    Duration minInterval = const Duration(milliseconds: 70),
  }) async {
    final now = DateTime.now();
    final cacheKey = '${theme.name}:${sound.name}';
    final previous = _lastPlayed[cacheKey];
    if (previous != null && now.difference(previous) < minInterval) return;
    _lastPlayed[cacheKey] = now;

    if (_settings.soundEnabled) {
      try {
        final player = _players[_playerIndex++ % _players.length];
        await player.stop();
        await player.play(
          BytesSource(
            _cache.putIfAbsent(cacheKey, () => _buildWav(sound, theme)),
          ),
          volume: volume,
        );
      } catch (_) {
        // Keep gameplay responsive even if a device audio backend rejects a cue.
      }
    }

    if (vibration && _settings.vibrationEnabled && haptic != null) {
      await haptic();
    }
  }

  static Uint8List _buildWav(GameSound sound, GameAudioTheme theme) {
    const sampleRate = 22050;
    final baseDuration = switch (sound) {
      GameSound.uiTap => .045,
      GameSound.tap => .065,
      GameSound.move => .09,
      GameSound.capture => .16,
      GameSound.win => .42,
      GameSound.lose => .38,
      GameSound.error => .20,
      GameSound.kick => .14,
      GameSound.goal => .50,
      GameSound.save => .26,
      GameSound.post => .18,
    };
    final durationScale = switch (theme) {
      GameAudioTheme.system => 1.0,
      GameAudioTheme.football => 1.12,
      GameAudioTheme.xo => .82,
      GameAudioTheme.checkers => 1.08,
      GameAudioTheme.domino => .94,
      GameAudioTheme.chess => 1.18,
      GameAudioTheme.cards => .88,
      GameAudioTheme.word => .78,
      GameAudioTheme.beard => 1.10,
      GameAudioTheme.dots => .90,
    };
    final signatureFrequency = switch (theme) {
      GameAudioTheme.system => 760.0,
      GameAudioTheme.football => 118.0,
      GameAudioTheme.xo => 1320.0,
      GameAudioTheme.checkers => 410.0,
      GameAudioTheme.domino => 185.0,
      GameAudioTheme.chess => 246.94,
      GameAudioTheme.cards => 980.0,
      GameAudioTheme.word => 1560.0,
      GameAudioTheme.beard => 330.0,
      GameAudioTheme.dots => 720.0,
    };
    final duration = baseDuration * durationScale;
    final sampleCount = (sampleRate * duration).round();
    final pcm = Int16List(sampleCount);
    final random = math.Random(sound.index * 7919 + theme.index * 104729 + 17);

    double note(double t, double frequency, double length) {
      if (t < 0 || t > length) return 0;
      final envelope = math.pow(1 - t / length, 1.8).toDouble();
      return math.sin(2 * math.pi * frequency * t) * envelope;
    }

    for (var i = 0; i < sampleCount; i++) {
      final t = i / sampleRate;
      final progress = i / sampleCount;
      final envelope = math.pow(1 - progress, 1.6).toDouble();
      double value;

      switch (sound) {
        case GameSound.uiTap:
          value = note(t, 1450, duration) * .40;
          break;
        case GameSound.tap:
          value = (note(t, 1050, duration) + note(t, 1480, duration) * .42) * .52;
          break;
        case GameSound.move:
          value = (note(t, 620, duration) + note(t, 880, duration) * .48) * .62;
          break;
        case GameSound.capture:
          final frequency = 460 + progress * 1150;
          value = math.sin(2 * math.pi * frequency * t) * envelope * .72;
          break;
        case GameSound.win:
          final segment = duration / 3;
          final frequencies = <double>[523.25, 659.25, 783.99];
          final index = math.min(2, (t / segment).floor());
          value = note(t - index * segment, frequencies[index], segment) * .86;
          break;
        case GameSound.lose:
          final segment = duration / 3;
          final frequencies = <double>[392.00, 311.13, 220.00];
          final index = math.min(2, (t / segment).floor());
          value = note(t - index * segment, frequencies[index], segment) * .82;
          break;
        case GameSound.error:
          value = (note(t, 185, duration) + note(t, 128, duration) * .52) * .72;
          break;
        case GameSound.kick:
          final noise = random.nextDouble() * 2 - 1;
          value = (noise * .72 + math.sin(2 * math.pi * 115 * t) * .28) * envelope * .82;
          break;
        case GameSound.goal:
          final shimmer = math.sin(2 * math.pi * (620 + progress * 330) * t);
          final upper = math.sin(2 * math.pi * 930 * t) * .38;
          value = (shimmer + upper) * envelope * .70;
          break;
        case GameSound.save:
          final noise = random.nextDouble() * 2 - 1;
          value = (noise * .50 + math.sin(2 * math.pi * 255 * t) * .50) * envelope * .75;
          break;
        case GameSound.post:
          value = (note(t, 2350, duration) + note(t, 3150, duration) * .55) * .62;
          break;
      }

      // A quiet signature layer gives every game its own recognizable timbre
      // without masking the semantic cue (move, capture, win, and so on).
      final phase = 2 * math.pi * signatureFrequency * t;
      final signature = switch (theme) {
        GameAudioTheme.system => math.sin(phase),
        GameAudioTheme.football => math.sin(phase) + math.sin(phase * .5) * .55,
        GameAudioTheme.xo => math.sin(phase) + math.sin(phase * 2) * .30,
        GameAudioTheme.checkers => math.sin(phase) * .72 + math.sin(phase * 1.5) * .38,
        GameAudioTheme.domino => math.sin(phase) * .55 + math.sin(phase * .25) * .70,
        GameAudioTheme.chess => math.sin(phase) + math.sin(phase * 2.01) * .18,
        GameAudioTheme.cards => math.sin(phase + progress * math.pi * 7),
        GameAudioTheme.word => math.sin(phase) * .65 + math.sin(phase * 1.25) * .35,
        GameAudioTheme.beard => math.sin(phase) + math.sin(phase * .75) * .42,
        GameAudioTheme.dots => math.sin(phase) * .70 + math.sin(phase * 2.5) * .24,
      };
      value = value * .86 + signature * envelope * .14;

      pcm[i] = (value.clamp(-1.0, 1.0) * 32767).round();
    }

    final dataLength = pcm.lengthInBytes;
    final bytes = ByteData(44 + dataLength);
    void ascii(int offset, String text) {
      for (var i = 0; i < text.length; i++) {
        bytes.setUint8(offset + i, text.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    bytes.setUint32(4, 36 + dataLength, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    bytes.setUint32(40, dataLength, Endian.little);
    for (var i = 0; i < pcm.length; i++) {
      bytes.setInt16(44 + i * 2, pcm[i], Endian.little);
    }
    return bytes.buffer.asUint8List();
  }
}
