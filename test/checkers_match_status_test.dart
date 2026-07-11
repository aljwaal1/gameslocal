import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/checkers/checkers_match_status.dart';

void main() {
  group('CheckersMatchStatus resultText', () {
    test('shows a readable five-line summary for a red win', () {
      const status = CheckersMatchStatus(
        redPieces: 9,
        blackPieces: 5,
        redHasMove: true,
        blackHasMove: false,
        winner: CheckersWinner.red,
        reason: 'لا توجد حركة للأسود',
      );

      expect(status.resultText.split('\n'), hasLength(5));
      expect(status.resultText, contains('فاز الأحمر — لا توجد حركة للأسود'));
      expect(
        status.resultText,
        contains('الأحجار المتبقية: الأحمر 9 أحجار • الأسود 5 أحجار'),
      );
      expect(
        status.resultText,
        contains('الأسر: الأحمر 11 حجرًا • الأسود 7 أحجار'),
      );
      expect(status.resultText, contains('أسر الأحمر 11 حجرًا من أحجار الأسود'));
      expect(status.resultText, contains('أفضلية الأحمر بفارق 4 أحجار'));
    });

    test('uses natural Arabic wording for remaining piece counts', () {
      const noPieces = CheckersMatchStatus(
        redPieces: 0,
        blackPieces: 1,
        redHasMove: false,
        blackHasMove: true,
        winner: CheckersWinner.black,
      );
      const twoPieces = CheckersMatchStatus(
        redPieces: 2,
        blackPieces: 2,
        redHasMove: false,
        blackHasMove: false,
        winner: CheckersWinner.draw,
      );

      expect(
        noPieces.piecesText,
        'الأحجار المتبقية: الأحمر لا أحجار • الأسود حجر واحد',
      );
      expect(
        twoPieces.piecesText,
        'الأحجار المتبقية: الأحمر حجران • الأسود حجران',
      );
    });

    test('uses natural Arabic wording for one- and two-piece differences', () {
      const onePieceLead = CheckersMatchStatus(
        redPieces: 8,
        blackPieces: 7,
        redHasMove: true,
        blackHasMove: false,
        winner: CheckersWinner.red,
      );
      const twoPieceLead = CheckersMatchStatus(
        redPieces: 8,
        blackPieces: 6,
        redHasMove: true,
        blackHasMove: false,
        winner: CheckersWinner.red,
      );

      expect(onePieceLead.piecesAdvantageText, 'أفضلية الأحمر بفارق حجر واحد');
      expect(twoPieceLead.piecesAdvantageText, 'أفضلية الأحمر بفارق حجرين');
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
