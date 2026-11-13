import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/core/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads saved gameplay preferences', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bot_difficulty': BotDifficulty.hard.index,
      'bot_difficulty_xo': BotDifficulty.normal.index,
      'bot_difficulty_chess': BotDifficulty.easy.index,
      'sound_enabled': false,
      'vibration_enabled': false,
      'table_color': 2,
      'player_name': 'أحمد',
    });

    final settings = AppSettingsController.instance;
    await settings.load();

    expect(settings.botDifficulty, BotDifficulty.hard);
    expect(settings.botDifficultyFor('xo'), BotDifficulty.normal);
    expect(settings.botDifficultyFor('chess'), BotDifficulty.easy);
    expect(settings.botDifficultyFor('domino'), BotDifficulty.hard);
    expect(settings.soundEnabled, isFalse);
    expect(settings.vibrationEnabled, isFalse);
    expect(settings.tableColorIndex, 2);
    expect(settings.playerName, 'أحمد');
  });

  test('stores a separate robot level for each game', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = AppSettingsController.instance;
    await settings.load();

    settings.setBotDifficultyFor('xo', BotDifficulty.easy);
    settings.setBotDifficultyFor('chess', BotDifficulty.hard);

    expect(settings.botDifficultyFor('xo'), BotDifficulty.easy);
    expect(settings.botDifficultyFor('chess'), BotDifficulty.hard);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getInt('bot_difficulty_chess'),
      BotDifficulty.hard.index,
    );
  });

  test('clamps invalid saved indexes safely', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bot_difficulty': 99,
      'table_color': -20,
    });

    final settings = AppSettingsController.instance;
    await settings.load();

    expect(settings.botDifficulty, BotDifficulty.hard);
    expect(settings.tableColorIndex, 0);
  });
}
