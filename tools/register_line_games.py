from pathlib import Path

main = Path('lib/main.dart')
text = main.read_text(encoding='utf-8')
imp = "import 'games/line_games/line_games.dart';\n"
if imp not in text:
    text = text.replace("import 'games/name_animal_object/name_animal_object_game.dart';\n", "import 'games/name_animal_object/name_animal_object_game.dart';\n" + imp)
marker = "    GameDefinition(\n      id: 'name_animal_object',"
if "id: 'sheikh_beard'" not in text:
    block = """    GameDefinition(
      id: 'sheikh_beard',
      name: 'لحية الشيخ',
      playersText: '2 إلى 4 لاعبين',
      status: 'تظليل نقاط وخطوط تلقائية عبر أندرويد والآيفون',
      builder: (_, networkCore) => LineGameScreen(
        kind: LineGameKind.sheikhBeard,
        networkCore: networkCore,
      ),
    ),
    GameDefinition(
      id: 'dots_boxes',
      name: 'المربعات',
      playersText: '2 إلى 4 لاعبين',
      status: 'أغلق المربعات والعب مرة أخرى عند التسجيل',
      builder: (_, networkCore) => LineGameScreen(
        kind: LineGameKind.dotsBoxes,
        networkCore: networkCore,
      ),
    ),
"""
    text = text.replace(marker, block + marker)
text = text.replace("        'name_animal_object',\n      }.contains(game.id);", "        'name_animal_object',\n        'sheikh_beard',\n        'dots_boxes',\n      }.contains(game.id);")
text = text.replace("      case 'name_animal_object':\n        return Icons.edit_note;", "      case 'name_animal_object':\n        return Icons.edit_note;\n      case 'sheikh_beard':\n        return Icons.change_history;\n      case 'dots_boxes':\n        return Icons.grid_on;")
text = text.replace("      case 'name_animal_object':\n        return const Color(0xFF7B2CBF);", "      case 'name_animal_object':\n        return const Color(0xFF7B2CBF);\n      case 'sheikh_beard':\n        return const Color(0xFF9C6644);\n      case 'dots_boxes':\n        return const Color(0xFF277DA1);")
main.write_text(text, encoding='utf-8')

room = Path('lib/core/game_room.dart')
r = room.read_text(encoding='utf-8')
r = r.replace("  bool get _isNameGame => widget.game.id == 'name_animal_object';", "  bool get _isNameGame => widget.game.id == 'name_animal_object';\n  bool get _supportsBrowserPlayer => const <String>{\n        'name_animal_object',\n        'sheikh_beard',\n        'dots_boxes',\n      }.contains(widget.game.id);")
r = r.replace("(_isNameGame ? state.players.isNotEmpty : state.players.length >= 2);", "(_supportsBrowserPlayer ? state.players.isNotEmpty : state.players.length >= 2);")
r = r.replace("_isNameGame\n                            ? 'العب من أندرويد أو الآيفون على نفس الشبكة'", "_supportsBrowserPlayer\n                            ? 'العب من أندرويد أو الآيفون على نفس الشبكة'")
r = r.replace("_isNameGame\n                              ? 'فتح اللعبة واستقبال الآيفون'", "_supportsBrowserPlayer\n                              ? 'فتح اللعبة واستقبال الآيفون'")
room.write_text(r, encoding='utf-8')
