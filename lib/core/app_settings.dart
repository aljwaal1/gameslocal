import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BotDifficulty { easy, normal, hard }

class AppSettingsController extends ChangeNotifier {
  AppSettingsController._();

  static final AppSettingsController instance = AppSettingsController._();
  SharedPreferences? _prefs;
  static const List<String> robotGameIds = <String>[
    'football_penalties',
    'xo',
    'checkers',
    'domino',
    'chess',
    'cards',
    'sheikh_beard',
    'dots_boxes',
  ];
  final Map<String, BotDifficulty> _gameBotDifficulties =
      <String, BotDifficulty>{};

  BotDifficulty botDifficulty = BotDifficulty.easy;
  bool soundEnabled = true;
  bool vibrationEnabled = true;
  int tableColorIndex = 0;
  String playerName = '';

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final difficultyIndex =
        _prefs!.getInt('bot_difficulty') ?? BotDifficulty.easy.index;
    botDifficulty = BotDifficulty.values[
        difficultyIndex.clamp(0, BotDifficulty.values.length - 1).toInt()];
    _gameBotDifficulties.clear();
    for (final gameId in robotGameIds) {
      final saved = _prefs!.getInt('bot_difficulty_$gameId');
      if (saved != null) {
        _gameBotDifficulties[gameId] = BotDifficulty.values[
          saved.clamp(0, BotDifficulty.values.length - 1).toInt()
        ];
      }
    }
    soundEnabled = _prefs!.getBool('sound_enabled') ?? true;
    vibrationEnabled = _prefs!.getBool('vibration_enabled') ?? true;
    tableColorIndex = (_prefs!.getInt('table_color') ?? 0).clamp(0, 3).toInt();
    playerName = (_prefs!.getString('player_name') ?? '').trim();
    notifyListeners();
  }

  String get botDifficultyText {
    return difficultyText(botDifficulty);
  }

  String difficultyText(BotDifficulty difficulty) {
    switch (difficulty) {
      case BotDifficulty.easy:
        return 'سهل';
      case BotDifficulty.normal:
        return 'متوسط';
      case BotDifficulty.hard:
        return 'صعب';
    }
  }

  BotDifficulty botDifficultyFor(String gameId) =>
      _gameBotDifficulties[gameId] ?? botDifficulty;

  String botDifficultyTextFor(String gameId) =>
      difficultyText(botDifficultyFor(gameId));

  void setBotDifficultyFor(String gameId, BotDifficulty value) {
    if (_gameBotDifficulties[gameId] == value) return;
    _gameBotDifficulties[gameId] = value;
    _prefs?.setInt('bot_difficulty_$gameId', value.index);
    notifyListeners();
  }

  void setBotDifficulty(BotDifficulty value) {
    if (botDifficulty == value) return;
    botDifficulty = value;
    _prefs?.setInt('bot_difficulty', value.index);
    notifyListeners();
  }

  void setBotDifficultyForAll(BotDifficulty value) {
    botDifficulty = value;
    _prefs?.setInt('bot_difficulty', value.index);
    for (final gameId in robotGameIds) {
      _gameBotDifficulties[gameId] = value;
      _prefs?.setInt('bot_difficulty_$gameId', value.index);
    }
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

  void setPlayerName(String value) {
    final cleaned = value.trim();
    if (playerName == cleaned) return;
    playerName = cleaned;
    _prefs?.setString('player_name', cleaned);
    notifyListeners();
  }
}
