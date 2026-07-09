import 'package:flutter/services.dart';

class GameFeedback {
  static Future<void> tap() async {
    await SystemSound.play(SystemSoundType.click);
    await HapticFeedback.selectionClick();
  }

  static Future<void> move() async {
    await SystemSound.play(SystemSoundType.click);
    await HapticFeedback.lightImpact();
  }

  static Future<void> win() async {
    await SystemSound.play(SystemSoundType.alert);
    await HapticFeedback.mediumImpact();
  }

  static Future<void> error() async {
    await SystemSound.play(SystemSoundType.alert);
    await HapticFeedback.heavyImpact();
  }
}
