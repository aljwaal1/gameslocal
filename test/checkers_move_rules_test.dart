import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/checkers/checkers_game.dart';

CheckersMove move({
  required int fromRow,
  required int fromCol,
  required int toRow,
  required int toCol,
  bool capture = false,
}) {
  return CheckersMove(
    fromRow: fromRow,
    fromCol: fromCol,
    toRow: toRow,
    toCol: toCol,
    captureRow: capture ? (fromRow + toRow) ~/ 2 : null,
    captureCol: capture ? (fromCol + toCol) ~/ 2 : null,
  );
}

void main() {
  group('CheckersMoveRules', () {
    test('forces captures by removing ordinary moves when a capture exists', () {
      final normalMove = move(fromRow: 5, fromCol: 0, toRow: 4, toCol: 1);
      final captureMove = move(
        fromRow: 5,
        fromCol: 2,
        toRow: 3,
        toCol: 4,
        capture: true,
      );

      expect(
        CheckersMoveRules.requireCapture(<CheckersMove>[normalMove, captureMove]),
        <CheckersMove>[captureMove],
      );
    });

    test('keeps ordinary moves when no capture is available', () {
      final first = move(fromRow: 5, fromCol: 0, toRow: 4, toCol: 1);
      final second = move(fromRow: 5, fromCol: 2, toRow: 4, toCol: 3);

      expect(
        CheckersMoveRules.requireCapture(<CheckersMove>[first, second]),
        <CheckersMove>[first, second],
      );
    });

    test('continues a capture chain only from the piece that captured', () {
      final firstCapture = move(
        fromRow: 5,
        fromCol: 0,
        toRow: 3,
        toCol: 2,
        capture: true,
      );
      final chainedCapture = move(
        fromRow: 3,
        fromCol: 2,
        toRow: 1,
        toCol: 4,
        capture: true,
      );
      final otherCapture = move(
        fromRow: 5,
        fromCol: 6,
        toRow: 3,
        toCol: 4,
        capture: true,
      );

      expect(
        CheckersMoveRules.chainedCaptures(
          <CheckersMove>[chainedCapture, otherCapture],
          firstCapture,
        ),
        <CheckersMove>[chainedCapture],
      );
    });
  });
}
