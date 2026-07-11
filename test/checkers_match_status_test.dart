import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/checkers/checkers_match_status.dart';

void main() {
  group('CheckersMatchStatus resultText', () {
    test('shows a readable three-line summary for a red win', () {
      const status = CheckersMatchStatus(
        redPieces: 9,
        blackPieces: 5,
        redHasMove: true,
        blackHasMove: false,
        winner: CheckersWinner.red,
        reason: 'لا توجد حركة للأسود',
      );

      expect(status.resultText.split('\n'), hasLength(3));
      expect(status.resultText, contains('فاز الأحمر — لا توجد حركة للأسود'));
      expect(status.resultText, contains('الأحجار المتبقية: الأحمر 9 • الأسود 5'));
      expect(status.resultText, contains('أسر الأحمر 11 من أحجار الأسود'));
      expect(status.resultText, contains('أفضلية الأحمر بفارق 4'));
    });

    test('trims the reason and avoids a dangling separator', () {
      const status = CheckersMatchStatus(
        redPieces: 8,
        blackPieces: 6,
        redHasMove: true,
        blackHasMove: false,
        winner: CheckersWinner.red,
        reason: '   ',
      );

      expect(status.resultText.split('\n').first, 'فاز الأحمر');
      expect(status.resultText, isNot(contains('—')));
    });

    test('keeps unfinished matches without a result message', () {
      const status = CheckersMatchStatus(
        redPieces: 16,
        blackPieces: 16,
        redHasMove: true,
        blackHasMove: true,
      );

      expect(status.resultText, isEmpty);
    });
  });
}
