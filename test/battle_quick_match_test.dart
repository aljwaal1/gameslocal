import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/battle/battle_quick_match.dart';

void main() {
  group('BattleQuickMatchChoice', () {
    test('compares choices by their selected character and bot level', () {
      const first = BattleQuickMatchChoice(
        characterIndex: 2,
        botLevel: 'صعب',
      );
      const same = BattleQuickMatchChoice(
        characterIndex: 2,
        botLevel: 'صعب',
      );
      const different = BattleQuickMatchChoice(
        characterIndex: 1,
        botLevel: 'صعب',
      );

      expect(first, same);
      expect(first.hashCode, same.hashCode);
      expect(first, isNot(different));
    });

    test('provides a readable diagnostic representation', () {
      const choice = BattleQuickMatchChoice(
        characterIndex: 3,
        botLevel: 'سهل',
      );

      expect(
        choice.toString(),
        'BattleQuickMatchChoice(characterIndex: 3, botLevel: سهل)',
      );
    });
  });

  group('buildBattleQuickMatchChoice', () {
    test('always excludes the current character when alternatives exist', () {
      for (var currentCharacter = 0; currentCharacter < 4; currentCharacter++) {
        for (var roll = 0; roll < 40; roll++) {
          final choice = buildBattleQuickMatchChoice(
            currentCharacter: currentCharacter,
            currentBotLevel: 'متوسط',
            characterRoll: roll,
            levelRoll: roll,
            characterCount: 4,
          );

          expect(choice.characterIndex, isNot(currentCharacter));
          expect(choice.characterIndex, inInclusiveRange(0, 3));
        }
      }
    });

    test('always excludes the current bot level', () {
      for (final currentLevel in battleBotLevels) {
        for (var roll = 0; roll < 30; roll++) {
          final choice = buildBattleQuickMatchChoice(
            currentCharacter: 0,
            currentBotLevel: currentLevel,
            characterRoll: roll,
            levelRoll: roll,
            characterCount: 4,
          );

          expect(choice.botLevel, isNot(currentLevel));
          expect(battleBotLevels, contains(choice.botLevel));
        }
      }
    });

    test('keeps the only character but still changes the bot level', () {
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

    test('maps rolls across all alternatives without selecting current values', () {
      final choices = List.generate(
        6,
        (roll) => buildBattleQuickMatchChoice(
          currentCharacter: 1,
          currentBotLevel: 'متوسط',
          characterRoll: roll,
          levelRoll: roll,
          characterCount: 4,
        ),
      );

      expect(choices.map((choice) => choice.characterIndex).toSet(), {0, 2, 3});
      expect(choices.map((choice) => choice.botLevel).toSet(), {'سهل', 'صعب'});
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

    test('rejects an invalid current character', () {
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

    test('rejects negative random rolls', () {
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
