import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/battle/battle_quick_match.dart';

void main() {
  group('buildBattleQuickMatchChoice', () {
    test('keeps the rolled values when they differ from the current setup', () {
      final choice = buildBattleQuickMatchChoice(
        currentCharacter: 0,
        currentBotLevel: 'متوسط',
        characterRoll: 2,
        levelRoll: 2,
        characterCount: 4,
      );

      expect(choice.characterIndex, 2);
      expect(choice.botLevel, 'صعب');
    });

    test('changes the character when the full setup would repeat', () {
      final choice = buildBattleQuickMatchChoice(
        currentCharacter: 1,
        currentBotLevel: 'متوسط',
        characterRoll: 1,
        levelRoll: 1,
        characterCount: 4,
      );

      expect(choice.characterIndex, 2);
      expect(choice.botLevel, 'متوسط');
    });

    test('wraps the fallback character at the end of the list', () {
      final choice = buildBattleQuickMatchChoice(
        currentCharacter: 3,
        currentBotLevel: 'سهل',
        characterRoll: 3,
        levelRoll: 0,
        characterCount: 4,
      );

      expect(choice.characterIndex, 0);
      expect(choice.botLevel, 'سهل');
    });

    test('rejects an empty character list in release builds too', () {
      expect(
        () => buildBattleQuickMatchChoice(
          currentCharacter: 0,
          currentBotLevel: 'سهل',
          characterRoll: 0,
          levelRoll: 0,
          characterCount: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}
