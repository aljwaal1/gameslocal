from pathlib import Path

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')

if 'bool get usesGameRoom =>' not in text:
    anchor = """  final GameDefinition game;

  bool get experimental => !const <String>{
"""
    replacement = """  final GameDefinition game;

  bool get usesGameRoom => const <String>{
        'battle',
        'football_penalties',
        'champions_penalties',
        'xo',
        'checkers',
        'domino',
        'cards',
        'name_animal_object',
        'sheikh_beard',
        'dots_boxes',
      }.contains(game.id);

  bool get experimental => !const <String>{
"""
    if anchor not in text:
        raise SystemExit('Game card field anchor not found')
    text = text.replace(anchor, replacement, 1)

old_tap = """      onTap: () {
        GameFeedback.tap();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Directionality(
              textDirection: TextDirection.rtl,
              child: GameRoomScreen(game: game),
            ),
          ),
        );
      },
"""
new_tap = """      onTap: () {
        GameFeedback.tap();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (routeContext) => Directionality(
              textDirection: TextDirection.rtl,
              child: usesGameRoom
                  ? GameRoomScreen(game: game)
                  : game.builder(routeContext, null),
            ),
          ),
        );
      },
"""
if old_tap in text:
    text = text.replace(old_tap, new_tap, 1)
elif 'child: usesGameRoom' not in text:
    raise SystemExit('Game card navigation anchor not found')

path.write_text(text, encoding='utf-8')
