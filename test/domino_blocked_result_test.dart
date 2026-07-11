import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/domino/domino_blocked_result.dart';

void main() {
  test('selects the player with the lowest remaining points', () {
    final result = calculateDominoBlockedResult([
      [6, 5, 4],
      [2, 1],
      [3, 3],
      [6, 6],
    ]);

    expect(result.points, [15, 3, 6, 12]);
    expect(result.bestScore, 3);
    expect(result.winners, [2]);
  });

  test('supports tied blocked-round winners', () {
    final result = calculateDominoBlockedResult([
      [4, 2],
      [3, 3],
      [5, 4],
      [6, 5],
    ]);

    expect(result.bestScore, 6);
    expect(result.winners, [1, 2]);
  });

  test('rejects a blocked result without players', () {
    expect(
      () => calculateDominoBlockedResult(const []),
      throwsArgumentError,
    );
  });
}
