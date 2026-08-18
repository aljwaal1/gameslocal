from pathlib import Path
import re

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

s = s.replace("import 'games/battle/battle_mode_screen.dart';\n", "")
s = re.sub(
    r"\n    GameDefinition\(\n      id: 'battle',.*?\n    \),",
    "",
    s,
    count=1,
    flags=re.S,
)
s = s.replace("        'battle',\n", "")
s = re.sub(r"\n      case 'battle':\n        return Icons\.[^;]+;", "", s)
s = re.sub(r"\n      case 'battle':\n        return const Color\([^;]+;", "", s)
s = s.replace(
    'اختر كرة القدم أو Battle أو إكس أو الضامة أو الدومينو أو الشدة للعب ضد الروبوت.',
    'اختر كرة القدم أو إكس أو أو الضامة أو الدومينو أو الشدة للعب ضد الروبوت.',
)

for forbidden in ["id: 'battle'", 'BattleModeScreen', "games/battle/battle_mode_screen.dart", "'battle',"]:
    if forbidden in s:
        raise SystemExit(f'Battle reference remains in main.dart: {forbidden}')

p.write_text(s, encoding='utf-8')
