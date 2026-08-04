from pathlib import Path

path = Path('lib/games/football/champions_penalty_game.dart')
text = path.read_text(encoding='utf-8')

replacements = {
    "((position.dx - goalLeft) / (goalRight - goalLeft)).clamp(0.02, 0.98),": "((position.dx - goalLeft) / (goalRight - goalLeft)).clamp(0.02, 0.98).toDouble(),",
    "((position.dy - goalTop) / (goalBottom - goalTop)).clamp(0.03, 0.97),": "((position.dy - goalTop) / (goalBottom - goalTop)).clamp(0.03, 0.97).toDouble(),",
    "_power = (0.48 + distance / (size.height * 0.44)).clamp(0.48, 1.0);": "_power = (0.48 + distance / (size.height * 0.44)).clamp(0.48, 1.0).toDouble();",
    "(target.dx + (_random.nextDouble() - 0.5) * accuracyError).clamp(0.01, 0.99),": "(target.dx + (_random.nextDouble() - 0.5) * accuracyError).clamp(0.01, 0.99).toDouble(),",
    "(target.dy + (_random.nextDouble() - 0.5) * accuracyError).clamp(0.01, 0.99),": "(target.dy + (_random.nextDouble() - 0.5) * accuracyError).clamp(0.01, 0.99).toDouble(),",
    "(d.localPosition.dx / size.width).clamp(0.0, 1.0),": "(d.localPosition.dx / size.width).clamp(0.0, 1.0).toDouble(),",
    "(d.localPosition.dy / (size.height * 0.58)).clamp(0.0, 1.0),": "(d.localPosition.dy / (size.height * 0.58)).clamp(0.0, 1.0).toDouble(),",
}

for old, new in replacements.items():
    text = text.replace(old, new)

old_finished = """  bool get _finished {
    if (_playerOneShots < 5 || _playerTwoShots < 5) return false;
    return _playerOneGoals != _playerTwoGoals;
  }
"""
new_finished = """  bool get _finished {
    if (_playerOneShots < 5 || _playerTwoShots < 5) return false;
    // In sudden death both players must complete the same number of shots.
    // Otherwise the match could end after player one's shot before player two
    // receives the matching attempt.
    if (_playerOneShots != _playerTwoShots) return false;
    return _playerOneGoals != _playerTwoGoals;
  }
"""
if old_finished in text:
    text = text.replace(old_finished, new_finished, 1)
elif 'if (_playerOneShots != _playerTwoShots) return false;' not in text:
    raise SystemExit('Champions finished-state function not found')

path.write_text(text, encoding='utf-8')
