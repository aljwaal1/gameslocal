import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/battle/battle_quick_match.dart';

void main() {
  group('BattleQuickMatchChoice', () {
    test('compares choices by character, count, and bot level', () {
      final first = BattleQuickMatchChoice(
        characterIndex: 2,
        characterCount: 4,
        botLevel: 'صعب',
      );
      final same = BattleQuickMatchChoice(
        characterIndex: 2,
        characterCount: 4,
        botLevel: 'صعب',
      );
      final different = BattleQuickMatchChoice(
        characterIndex: 1,
        characterCount: 4,
        botLevel: 'صعب',
      );

      expect(first, same);
      expect(first.hashCode, same.hashCode);
      expect(first, isNot(different));
    });

    test('provides a readable diagnostic representation', () {
      final choice = BattleQuickMatchChoice(
        characterIndex: 3,
        characterCount: 4,
        botLevel: 'سهل',
      );

      expect(
        choice.toString(),
        'BattleQuickMatchChoice(characterIndex: 3, characterCount: 4, botLevel: سهل)',
      );
    });

    test('rejects invalid direct choices', () {
      expect(
        () => BattleQuickMatchChoice(
          characterIndex: -1,
          characterCount: 4,
          botLevel: 'سهل',
        ),
        throwsArgumentError,
      );
      expect(
        () => BattleQuickMatchChoice(
          characterIndex: 4,
          characterCount: 4,
          botLevel: 'سهل',
        ),
        throwsArgumentError,
      );
      expect(
        () => BattleQuickMatchChoice(
          characterIndex: 0,
          characterCount: 0,
          botLevel: 'سهل',
        ),
        throwsArgumentError,
      );
      expect(
        () => BattleQuickMatchChoice(
          characterIndex: 0,
          characterCount: 4,
          botLevel: 'مستوى غير معروف',
        ),
        throwsArgumentError,
      );
    });
  });

  group('battleQuickMatchRollBound', () {
    test('always returns a positive Random.nextInt bound', () {
      expect(battleQuickMatchRollBound(1), 1);
      expect(battleQuickMatchRollBound(2), 1);
      expect(battleQuickMatchRollBound(4), 3);
    });

    test('rejects an empty options list', () {
      expect(() => battleQuickMatchRollBound(0), throwsArgumentError);
      expect(() => battleQuickMatchRollBound(-1), throwsArgumentError);
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
          expect(choice.characterCount, 4);
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
      expect(choice.characterCount, 1);
      expect(choice.botLevel, 'متوسط');
    });

    test('maps rolls across every available alternative', () {
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

    test('rejects invalid inputs', () {
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
          currentCharacter: 0,
          currentBotLevel: 'مستوى غير معروف',
          characterRoll: 0,
          levelRoll: 0,
          characterCount: 4,
        ),
        throwsArgumentError,
      );
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
