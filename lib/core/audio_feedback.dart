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
  error,
  kick,
  goal,
  save,
  post,
}

class GameFeedback {
  static final AppSettingsController _settings = AppSettingsController.instance;
  static final List<AudioPlayer> _players = List<AudioPlayer>.generate(
    4,
    (_) => AudioPlayer(),
  );
  static final Map<GameSound, Uint8List> _cache = <GameSound, Uint8List>{};
  static final Map<GameSound, DateTime> _lastPlayed = <GameSound, DateTime>{};
  static int _playerIndex = 0;

  static Future<void> uiTap() => _emit(
        GameSound.uiTap,
        vibration: false,
        volume: .12,
        minInterval: const Duration(milliseconds: 45),
      );

  static Future<void> tap() => _emit(
        GameSound.tap,
        haptic: HapticFeedback.selectionClick,
        volume: .24,
        minInterval: const Duration(milliseconds: 35),
      );

  static Future<void> move() => _emit(
        GameSound.move,
        haptic: HapticFeedback.lightImpact,
        volume: .34,
        minInterval: const Duration(milliseconds: 45),
      );

  static Future<void> capture() => _emit(
        GameSound.capture,
        haptic: HapticFeedback.mediumImpact,
        volume: .42,
      );

  static Future<void> win() => _emit(
        GameSound.win,
        haptic: HapticFeedback.mediumImpact,
        volume: .52,
      );

  static Future<void> error() => _emit(
        GameSound.error,
        haptic: HapticFeedback.heavyImpact,
        volume: .40,
      );

  static Future<void> kick() => _emit(
        GameSound.kick,
        haptic: HapticFeedback.lightImpact,
        volume: .48,
      );

  static Future<void> goal() => _emit(
        GameSound.goal,
        haptic: HapticFeedback.heavyImpact,
        volume: .58,
      );

  static Future<void> save() => _emit(
        GameSound.save,
        haptic: HapticFeedback.mediumImpact,
        volume: .48,
      );

  static Future<void> post() => _emit(
        GameSound.post,
        haptic: HapticFeedback.heavyImpact,
        volume: .55,
      );

  static Future<void> _emit(
    GameSound sound, {
    Future<void> Function()? haptic,
    bool vibration = true,
    double volume = .35,
    Duration minInterval = const Duration(milliseconds: 70),
  }) async {
    final now = DateTime.now();
    final previous = _lastPlayed[sound];
    if (previous != null && now.difference(previous) < minInterval) return;
    _lastPlayed[sound] = now;

    if (_settings.soundEnabled) {
      try {
        final player = _players[_playerIndex++ % _players.length];
        await player.stop();
        await player.play(
          BytesSource(_cache.putIfAbsent(sound, () => _buildWav(sound))),
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

  static Uint8List _buildWav(GameSound sound) {
    const sampleRate = 22050;
    final duration = switch (sound) {
      GameSound.uiTap => .045,
      GameSound.tap => .065,
      GameSound.move => .09,
      GameSound.capture => .16,
      GameSound.win => .42,
      GameSound.error => .20,
      GameSound.kick => .14,
      GameSound.goal => .50,
      GameSound.save => .26,
      GameSound.post => .18,
    };
    final sampleCount = (sampleRate * duration).round();
    final pcm = Int16List(sampleCount);
    final random = math.Random(sound.index * 7919 + 17);

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
