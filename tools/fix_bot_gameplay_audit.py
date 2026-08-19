from pathlib import Path

# XO: allow the bot to place O during its own turn while still blocking human taps.
p = Path('lib/games/xo/xo_game.dart')
s = p.read_text(encoding='utf-8')
old = "    if (playVsBot && !xTurn) return;"
new = "    if (playVsBot && !xTurn && senderId != 'bot') return;"
if s.count(old) != 1:
    raise SystemExit(f'XO guard expected once, found {s.count(old)}')
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')

# Domino: when the bot owns the opening turn, start it automatically instead of deadlocking.
p = Path('lib/games/domino/domino_game.dart')
s = p.read_text(encoding='utf-8')
old = """    message = isNetworkGame
        ? (isLocalTurn
            ? 'الجولة $roundNumber: دورك'
            : 'الجولة $roundNumber: بانتظار اللاعب الآخر')
        : 'الجولة $roundNumber: دورك، اختر قطعة مناسبة';
    setState(() {});
  }
"""
new = """    message = isNetworkGame
        ? (isLocalTurn
            ? 'الجولة $roundNumber: دورك'
            : 'الجولة $roundNumber: بانتظار اللاعب الآخر')
        : (playerTurn
            ? 'الجولة $roundNumber: دورك، اختر قطعة مناسبة'
            : 'الجولة $roundNumber: الكمبيوتر يبدأ...');
    setState(() {});
    if (!isNetworkGame && !playerTurn) {
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !roundFinished && !playerTurn) botMove();
      });
    }
  }
"""
if s.count(old) != 1:
    raise SystemExit('Domino round-start block not found exactly once')
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')

# Permanent regression test for the two gameplay deadlocks discovered on device/source audit.
p = Path('test/bot_gameplay_regression_test.dart')
p.write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('XO bot is allowed to place O on the bot turn', () {
    final source = File('lib/games/xo/xo_game.dart').readAsStringSync();
    expect(
      source,
      contains("if (playVsBot && !xTurn && senderId != 'bot') return;"),
    );
    expect(
      source,
      isNot(contains('if (playVsBot && !xTurn) return;')),
    );
  });

  test('Domino schedules the bot when the bot wins the opening turn', () {
    final source = File('lib/games/domino/domino_game.dart').readAsStringSync();
    expect(source, contains("'الجولة $roundNumber: الكمبيوتر يبدأ...'"));
    expect(source, contains('if (!isNetworkGame && !playerTurn) {'));
    expect(source, contains('if (mounted && !roundFinished && !playerTurn) botMove();'));
  });
}
''', encoding='utf-8')

print('Fixed XO bot turn and domino bot opening turn; added regression tests.')
