import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/battle/battle_quick_match.dart';

void main() {
  group('BattleQuickMatchChoice.differsFrom validation', () {
    final choice = BattleQuickMatchChoice(
      characterIndex: 2,
      characterCount: 4,
      botLevel: 'صعب',
    );

    test('still compares valid current settings', () {
      expect(
        choice.differsFrom(characterIndex: 2, botLevel: 'صعب'),
        isFalse,
      );
      expect(
        choice.differsFrom(characterIndex: 1, botLevel: 'صعب'),
        isTrue,
      );
    });

    test('rejects an invalid current character index', () {
      expect(
        () => choice.differsFrom(characterIndex: -1, botLevel: 'صعب'),
        throwsArgumentError,
      );
      expect(
        () => choice.differsFrom(characterIndex: 4, botLevel: 'صعب'),
        throwsArgumentError,
      );
    });

    test('rejects an unknown current bot level', () {
      expect(
        () => choice.differsFrom(
          characterIndex: 2,
          botLevel: 'مستوى غير معروف',
        ),
        throwsArgumentError,
      );
    });
  });
}
