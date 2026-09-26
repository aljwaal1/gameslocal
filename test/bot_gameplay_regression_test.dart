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
    expect(
      source,
      contains('difficulty == BotDifficulty.easy'),
    );
  });

  test('line games provide an offline robot without changing line scoring', () {
    final source =
        File('lib/games/line_games/line_games.dart').readAsStringSync();
    expect(source, contains("{'id': 'bot', 'name': 'الروبوت'}"));
    expect(source, contains("_processMove('bot', index)"));
    expect(source, contains('score += line.length * 10'));
    expect(source, contains('gained += line.length'));
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
