from pathlib import Path

path = Path('lib/games/checkers/checkers_game.dart')
text = path.read_text(encoding='utf-8')

old = """  String _localPlayerId() {
    final LocalNetworkState? state = widget.networkCore?.state;
    if (state == null || state.players.isEmpty)
      return localPlayerIsRed ? 'host-checkers' : 'client-checkers';
    return state.players.first.id;
  }
"""
new = """  String _localPlayerId() {
    final LocalNetworkCore? core = widget.networkCore;
    if (core == null || core.localPlayerId == 'system') {
      return localPlayerIsRed ? 'host-checkers' : 'client-checkers';
    }
    return core.localPlayerId;
  }
"""

if old in text:
    text = text.replace(old, new, 1)
elif 'return core.localPlayerId;' not in text:
    raise SystemExit('Checkers local-player identity function not found')

path.write_text(text, encoding='utf-8')
