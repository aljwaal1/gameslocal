import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/cards/cards_game.dart';

void main() {
  test('card values follow the capture rules', () {
    expect(const PlayingCardModel(rank: 'A', suit: '♠').value, 1);
    expect(const PlayingCardModel(rank: '10', suit: '♣').value, 10);
    expect(const PlayingCardModel(rank: 'K', suit: '♥').value, 13);
  });

  test('picture cards score ten while number cards score one', () {
    expect(const PlayingCardModel(rank: 'J', suit: '♠').scoreValue, 10);
    expect(const PlayingCardModel(rank: 'Q', suit: '♦').scoreValue, 10);
    expect(const PlayingCardModel(rank: '7', suit: '♣').scoreValue, 1);
  });

  test('detects red and black suits', () {
    expect(const PlayingCardModel(rank: '4', suit: '♥').red, isTrue);
    expect(const PlayingCardModel(rank: '4', suit: '♦').red, isTrue);
    expect(const PlayingCardModel(rank: '4', suit: '♠').red, isFalse);
  });
}
