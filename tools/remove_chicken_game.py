from pathlib import Path
import re

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

s = s.replace("import 'games/chicken/chicken_game.dart';\n", "")

s = re.sub(
    r"\n    GameDefinition\(\n      id: 'chicken',.*?\n    \),",
    "",
    s,
    count=1,
    flags=re.S,
)

s = re.sub(
    r"\n      case 'chicken':\n        return Icons\.[^;]+;",
    "",
    s,
)
s = re.sub(
    r"\n      case 'chicken':\n        return const Color\([^;]+;",
    "",
    s,
)

if "id: 'chicken'" in s or 'ChickenGameScreen' in s or "games/chicken/chicken_game.dart" in s:
    raise SystemExit('chicken references remain in main.dart')

p.write_text(s, encoding='utf-8')
