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

    test('changes the character whenever the roll repeats it', () {
      final choice = buildBattleQuickMatchChoice(
        currentCharacter: 1,
        currentBotLevel: 'سهل',
        characterRoll: 1,
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

    test('changes the bot level when only one character is available', () {
      final choice = buildBattleQuickMatchChoice(
        currentCharacter: 0,
        currentBotLevel: 'سهل',
        characterRoll: 0,
        levelRoll: 0,
        characterCount: 1,
      );

      expect(choice.characterIndex, 0);
      expect(choice.botLevel, 'متوسط');
    });

    test('keeps a different rolled level with one character', () {
      final choice = buildBattleQuickMatchChoice(
        currentCharacter: 0,
        currentBotLevel: 'سهل',
        characterRoll: 0,
        levelRoll: 2,
        characterCount: 1,
      );

      expect(choice.characterIndex, 0);
      expect(choice.botLevel, 'صعب');
    });

    test('wraps the fallback bot level for a single character', () {
      final choice = buildBattleQuickMatchChoice(
        currentCharacter: 0,
        currentBotLevel: 'صعب',
        characterRoll: 0,
        levelRoll: 2,
        characterCount: 1,
      );

      expect(choice.characterIndex, 0);
      expect(choice.botLevel, 'سهل');
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

    test('rejects an invalid current character before comparing choices', () {
      expect(
        () => buildBattleQuickMatchChoice(
          currentCharacter: -1,
          currentBotLevel: 'سهل',
          characterRoll: 0,
          levelRoll: 0,
          characterCount: 4,
        ),
        throwsArgumentError,
      );
      expect(
        () => buildBattleQuickMatchChoice(
          currentCharacter: 4,
          currentBotLevel: 'سهل',
          characterRoll: 0,
          levelRoll: 0,
          characterCount: 4,
        ),
        throwsArgumentError,
      );
    });

    test('rejects an unknown current bot level', () {
      expect(
        () => buildBattleQuickMatchChoice(
          currentCharacter: 0,
          currentBotLevel: 'مستوى غير معروف',
          characterRoll: 0,
          levelRoll: 0,
          characterCount: 4,
        ),
        throwsArgumentError,
      );
    });

    test('rejects negative random rolls before indexing lists', () {
      expect(
        () => buildBattleQuickMatchChoice(
          currentCharacter: 0,
          currentBotLevel: 'سهل',
          characterRoll: -1,
          levelRoll: 0,
          characterCount: 4,
        ),
        throwsArgumentError,
      );
      expect(
        () => buildBattleQuickMatchChoice(
          currentCharacter: 0,
          currentBotLevel: 'سهل',
          characterRoll: 0,
          levelRoll: -1,
          characterCount: 4,
        ),
        throwsArgumentError,
      );
    });
  });
}
