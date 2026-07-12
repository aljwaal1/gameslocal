import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/domino/domino_starting_player.dart';

void main() {
  test('selects the player holding the highest double', () {
    final player = selectDominoStartingPlayer([
      [(6, 5), (4, 4)],
      [(6, 6), (1, 0)],
      [(5, 5), (3, 2)],
      [(2, 2), (6, 4)],
    ]);

    expect(player, 1);
  });

  test('falls back to the strongest tile when there are no doubles', () {
    final player = selectDominoStartingPlayer([
      [(6, 4), (2, 1)],
      [(6, 5), (3, 1)],
      [(5, 4), (2, 0)],
      [(4, 3), (1, 0)],
    ]);

    expect(player, 1);
  });

  test('rejects duplicate tiles even when their pip order is reversed', () {
    for (final duplicateTile in <(int, int)>[(6, 5), (5, 6)]) {
      expect(
        () => selectDominoStartingPlayer([
          [(6, 5)],
          [duplicateTile],
        ]),
        throwsArgumentError,
      );
    }
  });

  test('rejects empty hands', () {
    expect(
      () => selectDominoStartingPlayer([
        [(6, 6)],
        <(int, int)>[],
      ]),
      throwsArgumentError,
    );
  });

  test('rejects tiles outside the standard zero-to-six range', () {
    for (final invalidTile in <(int, int)>[(-1, 2), (2, 7)]) {
      expect(
        () => selectDominoStartingPlayer([
          [(6, 6)],
          [invalidTile],
        ]),
        throwsArgumentError,
      );
    }
  });
}
