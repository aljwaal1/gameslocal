import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/cards/cards_game.dart';

void main() {
  testWidgets(
      'compact 10 keeps its main identity inside the card at text scale 1.3',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
      child: const Scaffold(
          body: Center(
              child: PlayingCardView(
        card: PlayingCardModel(rank: '10', suit: '♥'),
        compact: true,
      ))),
    )));
    expect(tester.takeException(), isNull);
  });
}
