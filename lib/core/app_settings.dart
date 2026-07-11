import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BotDifficulty { easy, normal, hard }

class AppSettingsController extends ChangeNotifier {
  AppSettingsController._();

  static final AppSettingsController instance = AppSettingsController._();
  SharedPreferences? _prefs;

  BotDifficulty botDifficulty = BotDifficulty.easy;
  bool soundEnabled = true;
  bool vibrationEnabled = true;
  int tableColorIndex = 0;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final difficultyIndex = _prefs!.getInt('bot_difficulty') ?? BotDifficulty.easy.index;
    botDifficulty = BotDifficulty.values[difficultyIndex.clamp(0, BotDifficulty.values.length - 1).toInt()];
    soundEnabled = _prefs!.getBool('sound_enabled') ?? true;
    vibrationEnabled = _prefs!.getBool('vibration_enabled') ?? true;
    tableColorIndex = (_prefs!.getInt('table_color') ?? 0).clamp(0, 3).toInt();
    notifyListeners();
  }

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
    if (botDifficulty == value) return;
    botDifficulty = value;
    _prefs?.setInt('bot_difficulty', value.index);
    notifyListeners();
  }

  void setSoundEnabled(bool value) {
    if (soundEnabled == value) return;
    soundEnabled = value;
    _prefs?.setBool('sound_enabled', value);
    notifyListeners();
  }

  void setVibrationEnabled(bool value) {
    if (vibrationEnabled == value) return;
    vibrationEnabled = value;
    _prefs?.setBool('vibration_enabled', value);
    notifyListeners();
  }

  void setTableColorIndex(int value) {
    final safeValue = value.clamp(0, 3).toInt();
    if (tableColorIndex == safeValue) return;
    tableColorIndex = safeValue;
    _prefs?.setInt('table_color', safeValue);
    notifyListeners();
  }
}
