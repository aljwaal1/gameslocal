import 'package:flutter/services.dart';

import 'app_settings.dart';

class GameFeedback {
  static final AppSettingsController _settings = AppSettingsController.instance;

  static Future<void> tap() async {
    if (_settings.soundEnabled) {
      await SystemSound.play(SystemSoundType.click);
    }
    if (_settings.vibrationEnabled) {
      await HapticFeedback.selectionClick();
    }
  }

  static Future<void> move() async {
    if (_settings.soundEnabled) {
      await SystemSound.play(SystemSoundType.click);
    }
    if (_settings.vibrationEnabled) {
      await HapticFeedback.lightImpact();
    }
  }

  static Future<void> win() async {
    if (_settings.soundEnabled) {
      await SystemSound.play(SystemSoundType.alert);
    }
    if (_settings.vibrationEnabled) {
      await HapticFeedback.mediumImpact();
    }
  }

  static Future<void> error() async {
    if (_settings.soundEnabled) {
      await SystemSound.play(SystemSoundType.alert);
    }
    if (_settings.vibrationEnabled) {
      await HapticFeedback.heavyImpact();
    }
  }
}
