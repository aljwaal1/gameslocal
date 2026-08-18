from pathlib import Path
import re

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

s = s.replace("import 'games/football/champions_penalty_game.dart';\n", "")

s = re.sub(
    r"\n    GameDefinition\(\n      id: 'champions_penalties',.*?\n    \),",
    "",
    s,
    count=1,
    flags=re.S,
)

s = s.replace("        'champions_penalties',\n", "")

s = re.sub(
    r"\n      case 'champions_penalties':\n        return Icons\.[^;]+;",
    "",
    s,
)
s = re.sub(
    r"\n      case 'champions_penalties':\n        return const Color\([^;]+;",
    "",
    s,
)

if 'ChampionsPenaltyGameScreen' in s or "id: 'champions_penalties'" in s:
    raise SystemExit('champions penalties references remain in main.dart')

p.write_text(s, encoding='utf-8')
