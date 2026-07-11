import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/domino/domino_turn_order.dart';

void main() {
  test('cycles through four players', () {
    final turns = DominoTurnOrder(playerCount: 4);
    expect([turns.next(), turns.next(), turns.next(), turns.next()], [1, 2, 3, 0]);
  });

  test('skips blocked players', () {
    final turns = DominoTurnOrder(playerCount: 4);
    expect(turns.next(skipped: {1, 2}), 3);
    expect(turns.next(skipped: {0}), 1);
  });

  test('validates a reset starting player', () {
    final turns = DominoTurnOrder(playerCount: 3);
    expect(() => turns.reset(startingPlayer: 3), throwsRangeError);
  });
}
