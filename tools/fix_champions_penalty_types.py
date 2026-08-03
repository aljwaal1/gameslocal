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

path.write_text(text, encoding='utf-8')
