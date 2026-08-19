import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('XO bot is allowed to place O on the bot turn', () {
    final source = File('lib/games/xo/xo_game.dart').readAsStringSync();
    expect(
      source,
      contains("if (playVsBot && !xTurn && senderId != 'bot') return;"),
    );
    expect(source, isNot(contains('if (playVsBot && !xTurn) return;')));
  });

  test('Domino starts the bot when the bot owns the opening turn', () {
    final source = File('lib/games/domino/domino_game.dart').readAsStringSync();
    expect(source, contains(r"'الجولة $roundNumber: الكمبيوتر يبدأ...'"));
    expect(source, contains('if (!isNetworkGame && !playerTurn) {'));
    expect(
      source,
      contains('if (mounted && !roundFinished && !playerTurn) botMove();'),
    );
  });
}
