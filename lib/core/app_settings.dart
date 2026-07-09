import 'package:flutter/foundation.dart';

enum BotDifficulty { easy, normal, hard }

class AppSettingsController extends ChangeNotifier {
  AppSettingsController._();

  static final AppSettingsController instance = AppSettingsController._();

  BotDifficulty botDifficulty = BotDifficulty.easy;
  bool soundEnabled = true;
  bool vibrationEnabled = true;
  int tableColorIndex = 0;

  String get botDifficultyText {
    switch (botDifficulty) {
      case BotDifficulty.easy:
        return 'سهل';
      case BotDifficulty.normal:
        return 'متوسط';
      case BotDifficulty.hard:
        return 'صعب';
    }
  }

  void setBotDifficulty(BotDifficulty value) {
    botDifficulty = value;
    notifyListeners();
  }

  void setSoundEnabled(bool value) {
    soundEnabled = value;
    notifyListeners();
  }

  void setVibrationEnabled(bool value) {
    vibrationEnabled = value;
    notifyListeners();
  }

  void setTableColorIndex(int value) {
    tableColorIndex = value;
    notifyListeners();
  }
}
