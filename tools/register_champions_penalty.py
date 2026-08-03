from pathlib import Path

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')

import_line = "import 'games/football/champions_penalty_game.dart';\n"
anchor = "import 'games/football/professional_penalty_game.dart';\n"
if import_line not in text:
    if anchor not in text:
        raise SystemExit('Football import anchor not found')
    text = text.replace(anchor, import_line + anchor)

card = """    GameDefinition(
      id: 'champions_penalties',
      name: 'ركلات الأبطال',
      playersText: 'لاعب ضد روبوت أو لاعبان LAN',
      status: 'لعبة جديدة: تسديد بالسحب وتحكم كامل بالحارس',
      builder: (_, networkCore) =>
          ChampionsPenaltyGameScreen(networkCore: networkCore),
    ),
"""
card_anchor = """    GameDefinition(
      id: 'football_penalties',
"""
if "id: 'champions_penalties'" not in text:
    if card_anchor not in text:
        raise SystemExit('Penalty card anchor not found')
    text = text.replace(card_anchor, card + card_anchor)

ready_old = """        'football_penalties',
        'name_animal_object',
"""
ready_new = """        'football_penalties',
        'champions_penalties',
        'name_animal_object',
"""
if "        'champions_penalties',\n" not in text:
    if ready_old not in text:
        raise SystemExit('Ready games anchor not found')
    text = text.replace(ready_old, ready_new)

icon_anchor = """      case 'football_penalties':
        return Icons.sports_soccer;
"""
icon_new = """      case 'football_penalties':
        return Icons.sports_soccer;
      case 'champions_penalties':
        return Icons.sports_score;
"""
if "case 'champions_penalties':" not in text:
    if icon_anchor not in text:
        raise SystemExit('Icon anchor not found')
    text = text.replace(icon_anchor, icon_new, 1)

color_anchor = """      case 'football_penalties':
        return const Color(0xFF0B7A3B);
"""
color_new = """      case 'football_penalties':
        return const Color(0xFF0B7A3B);
      case 'champions_penalties':
        return const Color(0xFF0B4F8A);
"""
# The icon case already added the same case string, so target the color block by exact return.
if "case 'champions_penalties':\n        return const Color(0xFF0B4F8A);" not in text:
    if color_anchor not in text:
        raise SystemExit('Color anchor not found')
    text = text.replace(color_anchor, color_new, 1)

path.write_text(text, encoding='utf-8')
