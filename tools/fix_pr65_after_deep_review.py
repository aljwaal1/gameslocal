from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    s = p.read_text(encoding='utf-8')
    count = s.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one anchor, found {count}')
    p.write_text(s.replace(old, new, 1), encoding='utf-8')

# 1) Restore the established Sheikh Beard capture rule:
# every contiguous 3-point segment scores once; the player placing the final
# point captures that completed segment. Do not require prior same-player ownership.
replace_once(
    'lib/games/line_games/line_games.dart',
    '''  int _claimCompletedSheikhLines(int ownerIndex, String playerId) {
    var gained = 0;
    for (final line in _sheikhLines) {
      final key = line.join('-');
      if (_claimedSheikhLines.containsKey(key)) continue;

      // A Sheikh Beard line belongs to a player only when all three
      // points in that straight segment were actually selected by that
      // same player. Never recolor/steal points from another player:
      // doing so creates false chain scores at crosses and overlaps.
      if (!line.every((pointIndex) => _pointOwners[pointIndex] == ownerIndex)) {
        continue;
      }

      _claimedSheikhLines[key] = playerId;
      gained++;
    }
    return gained;
  }
''',
    '''  int _claimCompletedSheikhLines(int ownerIndex, String playerId) {
    var gained = 0;
    for (final line in _sheikhLines) {
      final key = line.join('-');
      if (_claimedSheikhLines.containsKey(key)) continue;
      if (!line.every((pointIndex) => _pointOwners[pointIndex] >= 0)) {
        continue;
      }

      // The player who places the final point captures this completed
      // contiguous 3-point segment. Each segment scores exactly one point.
      for (final pointIndex in line) {
        _pointOwners[pointIndex] = ownerIndex;
      }
      _claimedSheikhLines[key] = playerId;
      gained++;
    }
    return gained;
  }
''',
)

# 2) LAN Android guests must count in the same pre-game gate as browser guests.
replace_once(
    'lib/games/line_games/line_games.dart',
    '''        connectedPlayers: _webPlayers.length,
        accent: widget.kind == LineGameKind.sheikhBeard
''',
    '''        connectedPlayers: (widget.networkCore?.state.players
                    .where((player) => !player.isHost)
                    .length ??
                0) +
            _webPlayers.length,
        accent: widget.kind == LineGameKind.sheikhBeard
''',
)

replace_once(
    'lib/games/name_animal_object/name_animal_object_game.dart',
    '''        connectedPlayers: _webPlayers.length,
        accent: const Color(0xFF8B5CF6),
''',
    '''        connectedPlayers: (_network?.state.players
                    .where((player) => !player.isHost)
                    .length ??
                0) +
            _webPlayers.length,
        accent: const Color(0xFF8B5CF6),
''',
)

# 3) Keep QR large on normal portrait screens but allow it to shrink safely on
# short/landscape screens instead of forcing a 220 px minimum that can overflow.
replace_once(
    'lib/core/pregame_qr_lobby.dart',
    '''            final qrSize = math.min(
              constraints.maxWidth * .78,
              constraints.maxHeight * .46,
            ).clamp(220.0, 380.0).toDouble();
''',
    '''            final qrSize = math.min(
              constraints.maxWidth * .78,
              constraints.maxHeight * .46,
            ).clamp(140.0, 380.0).toDouble();
''',
)

# 4) Replace the static scoring contract with the actual established capture contract.
Path('test/sheikh_beard_scoring_contract_test.dart').write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Sheikh Beard keeps contiguous triples on all three axes', () {
    final source = File('lib/games/line_games/line_games.dart').readAsStringSync();
    expect(source, contains('void addTriples(List<int> axis)'));
    expect(source, contains('axis.sublist(start, start + 3)'));
    expect(source, contains('for (var column = 0; column < rows; column++)'));
    expect(source, contains('for (var diagonal = 0; diagonal < rows; diagonal++)'));
  });

  test('final point captures a completed three-point segment for one point', () {
    final source = File('lib/games/line_games/line_games.dart').readAsStringSync();
    expect(source, contains('_pointOwners[pointIndex] >= 0'));
    expect(source, contains('_pointOwners[pointIndex] = ownerIndex;'));
    expect(source, contains('_claimedSheikhLines[key] = playerId;'));
    expect(source, contains('gained++;'));
    expect(source, isNot(contains('gained += line.length')));
  });
}
''', encoding='utf-8')

# Strengthen QR regression contracts for Android/LAN guests and short screens.
p = Path('test/pregame_qr_all_browser_games_test.dart')
s = p.read_text(encoding='utf-8')
s = s.replace(
    "    expect(source, contains('constraints.maxWidth * .78'));\n",
    "    expect(source, contains('constraints.maxWidth * .78'));\n    expect(source, contains('.clamp(140.0, 380.0)'));\n",
    1,
)
s = s.replace(
    "    expect(source, contains('_showNetworkQrLobby'));\n  });\n\n  test('name animal object uses pregame QR lobby'",
    "    expect(source, contains('_showNetworkQrLobby'));\n    expect(source, contains('.where((player) => !player.isHost)'));\n  });\n\n  test('name animal object uses pregame QR lobby'",
    1,
)
s = s.replace(
    "    expect(source, contains('_showNetworkQrLobby'));\n  });\n\n  test('game room labels browser QR as a pregame action'",
    "    expect(source, contains('_showNetworkQrLobby'));\n    expect(source, contains('.where((player) => !player.isHost)'));\n  });\n\n  test('game room labels browser QR as a pregame action'",
    1,
)
p.write_text(s, encoding='utf-8')

print('Applied only the corrections established by the deep review.')
