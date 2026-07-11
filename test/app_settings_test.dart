import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/core/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads saved gameplay preferences', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bot_difficulty': BotDifficulty.hard.index,
      'sound_enabled': false,
      'vibration_enabled': false,
      'table_color': 2,
    });

    final settings = AppSettingsController.instance;
    await settings.load();

    expect(settings.botDifficulty, BotDifficulty.hard);
    expect(settings.soundEnabled, isFalse);
    expect(settings.vibrationEnabled, isFalse);
    expect(settings.tableColorIndex, 2);
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
