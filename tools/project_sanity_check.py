from pathlib import Path
import sys

errors: list[str] = []


def read(path: str) -> str:
    file = Path(path)
    if not file.exists():
        errors.append(f'MISSING FILE: {path}')
        return ''
    return file.read_text(encoding='utf-8')


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        errors.append(f'MISSING: {label}')


def unique(text: str, needle: str, label: str) -> None:
    count = text.count(needle)
    if count != 1:
        errors.append(f'DUPLICATE/ABSENT: {label} count={count}')


main = read('lib/main.dart')
room = read('lib/core/game_room.dart')
checkers = read('lib/games/checkers/checkers_game.dart')
xo = read('lib/games/xo/xo_game.dart')
bridge = read('lib/core/iphone_game_bridge.dart')
name_game = read('lib/games/name_animal_object/name_animal_object_game.dart')
line_games = read('lib/games/line_games/line_games.dart')
champions = read('lib/games/football/champions_penalty_game.dart')
checkers_web = read('lib/games/checkers/checkers_iphone_web.dart')
pubspec = read('pubspec.yaml')

# Games must be registered and reachable.
require(main, "import 'games/football/champions_penalty_game.dart';", 'Champions import')
require(main, "id: 'champions_penalties'", 'Champions game card')
require(main, 'ChampionsPenaltyGameScreen', 'Champions builder')
require(champions, 'class ChampionsPenaltyGameScreen', 'Champions screen class')

# iPhone capability declarations must match real implementations.
for game_id in ('xo', 'checkers', 'name_animal_object', 'sheikh_beard', 'dots_boxes'):
    require(room, f"'{game_id}'", f'iPhone room declaration: {game_id}')

require(xo, 'IphoneGameBridge? _iphoneBridge;', 'XO iPhone bridge')
require(xo, 'QrImageView', 'XO QR UI')
require(checkers, 'IphoneGameBridge? _iphoneBridge;', 'Checkers iPhone bridge')
require(checkers, 'QrImageView', 'Checkers QR UI')
require(checkers, 'checkersIphoneHtml', 'Checkers Safari page binding')
require(checkers_web, 'checkersIphoneHtml', 'Checkers Safari page')
require(bridge, 'WebSocketTransformer.upgrade', 'WebSocket upgrade')
require(pubspec, 'qr_flutter:', 'QR dependency')

# Prevent patch scripts from duplicating source on later builds.
unique(checkers, "import 'package:qr_flutter/qr_flutter.dart';", 'Checkers qr import')
unique(checkers, 'IphoneGameBridge? _iphoneBridge;', 'Checkers bridge field')
unique(main, "id: 'champions_penalties'", 'Champions card')

# Core rule invariants requested for the games.
require(name_game, "'حيوان': <String>{'دب', 'قط', 'بط'}", 'Short animal exceptions')
require(name_game, "'بلاد': <String>{}", 'No short country exceptions')
require(name_game, 'approvals.length < 2', 'Two-player score approval')
require(line_games, 'gained += line.length', 'Sheikh Beard line-length scoring')
require(line_games, 'const rows = 8;', 'Sheikh Beard eight rows')

# Basic dangerous regressions.
if "'checkers'," in room and 'IphoneGameBridge? _iphoneBridge;' not in checkers:
    errors.append('CATASTROPHIC: Checkers advertised as iPhone-ready without bridge')
if "id: 'champions_penalties'" not in main and champions:
    errors.append('CATASTROPHIC: Champions source exists but game is unreachable')

if errors:
    print('PROJECT SANITY CHECK FAILED')
    for error in errors:
        print(f'- {error}')
    sys.exit(1)

print('PROJECT SANITY CHECK PASSED')
