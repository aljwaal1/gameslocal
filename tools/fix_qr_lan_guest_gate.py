from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    s = p.read_text(encoding='utf-8')
    count = s.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one anchor, found {count}')
    p.write_text(s.replace(old, new, 1), encoding='utf-8')

replace_once(
    'lib/games/line_games/line_games.dart',
    """        connectedPlayers: _webPlayers.length,
        accent: widget.kind == LineGameKind.sheikhBeard
""",
    """        connectedPlayers: (widget.networkCore?.state.players
                    .where((player) => !player.isHost)
                    .length ??
                0) +
            _webPlayers.length,
        accent: widget.kind == LineGameKind.sheikhBeard
""",
)

replace_once(
    'lib/games/name_animal_object/name_animal_object_game.dart',
    """        connectedPlayers: _webPlayers.length,
        accent: const Color(0xFF8B5CF6),
""",
    """        connectedPlayers: (_network?.state.players
                    .where((player) => !player.isHost)
                    .length ??
                0) +
            _webPlayers.length,
        accent: const Color(0xFF8B5CF6),
""",
)

p = Path('test/pregame_qr_all_browser_games_test.dart')
s = p.read_text(encoding='utf-8')
old_line = """    expect(source, contains('_showNetworkQrLobby'));
  });

  test('name animal object uses pregame QR lobby'"""
new_line = """    expect(source, contains('_showNetworkQrLobby'));
    expect(source, contains('.where((player) => !player.isHost)'));
  });

  test('name animal object uses pregame QR lobby'"""
if s.count(old_line) != 1:
    raise SystemExit('line-game test anchor mismatch')
s = s.replace(old_line, new_line, 1)
old_name = """    expect(source, contains('_showNetworkQrLobby'));
  });

  test('game room labels browser QR as a pregame action'"""
new_name = """    expect(source, contains('_showNetworkQrLobby'));
    expect(source, contains('.where((player) => !player.isHost)'));
  });

  test('game room labels browser QR as a pregame action'"""
if s.count(old_name) != 1:
    raise SystemExit('name-game test anchor mismatch')
s = s.replace(old_name, new_name, 1)
p.write_text(s, encoding='utf-8')

print('Fixed QR lobby LAN guest gating for line games and Name/Animal/Object.')
