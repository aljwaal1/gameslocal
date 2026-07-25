from pathlib import Path

main_path = Path('lib/main.dart')
source = main_path.read_text(encoding='utf-8')

football_import = "import 'games/football/penalty_shootout_game.dart';\n"
if football_import not in source:
    source = source.replace(
        "import 'games/domino/domino_game.dart';\n",
        "import 'games/domino/domino_game.dart';\n" + football_import,
    )

football_definition = """    GameDefinition(
      id: 'football_penalties',
      name: 'ركلات الترجيح',
      playersText: 'لاعب ضد روبوت أو لاعبان LAN',
      status: 'كرة قدم احترافية بمنتخبات وحارس آلي',
      builder: (_, networkCore) => PenaltyShootoutGameScreen(networkCore: networkCore),
    ),
"""
if "id: 'football_penalties'" not in source:
    source = source.replace(
        "    GameDefinition(\n      id: 'chicken',",
        football_definition + "    GameDefinition(\n      id: 'chicken',",
    )

source = source.replace(
    "!const <String>{'xo', 'checkers', 'domino'}.contains(game.id)",
    "!const <String>{'xo', 'checkers', 'domino', 'football_penalties'}.contains(game.id)",
)

if "case 'football_penalties':\n        return Icons.sports_soccer;" not in source:
    source = source.replace(
        "      case 'chicken':\n        return Icons.egg_alt;",
        "      case 'football_penalties':\n        return Icons.sports_soccer;\n      case 'chicken':\n        return Icons.egg_alt;",
        1,
    )

if "case 'football_penalties':\n        return const Color(0xFF0B7A3B);" not in source:
    marker = "      case 'chicken':\n        return const Color(0xFFFF9F1C);"
    replacement = "      case 'football_penalties':\n        return const Color(0xFF0B7A3B);\n" + marker
    source = source.replace(marker, replacement, 1)

source = source.replace(
    'اختر Battle أو إكس أو أو الضامة أو الدومينو أو الشدة للعب ضد الروبوت.',
    'اختر كرة القدم أو Battle أو إكس أو الضامة أو الدومينو أو الشدة للعب ضد الروبوت.',
)

main_path.write_text(source, encoding='utf-8')

football_path = Path('lib/games/football/penalty_shootout_game.dart')
football = football_path.read_text(encoding='utf-8')
football = football.replace(
    "                      final col = (details.localPosition.dx / (details.localPosition.dx.isFinite ? 1 : 1));\n",
    '',
)
football_path.write_text(football, encoding='utf-8')

print('Penalty shootout activated in GamesLocal')
