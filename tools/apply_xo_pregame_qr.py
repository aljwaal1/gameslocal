from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    return text.replace(old, new, 1)

# XO
p = Path('lib/games/xo/xo_game.dart')
s = p.read_text(encoding='utf-8')
s = replace_once(
    s,
    "import '../../core/audio_feedback.dart';\n",
    "import '../../core/audio_feedback.dart';\nimport '../../core/pregame_qr_lobby.dart';\n",
    'XO import',
)
s = replace_once(
    s,
    "  String _iphoneUrl = '';\n",
    "  String _iphoneUrl = '';\n  bool _showNetworkQrLobby = true;\n",
    'XO field',
)
s = replace_once(
    s,
    "  @override\n  Widget build(BuildContext context) {\n    return Scaffold(\n",
    """  @override
  Widget build(BuildContext context) {
    final hasAndroidGuest = widget.networkCore?.state.players
            .any((player) => !player.isHost) ??
        false;
    if (isNetworkGame &&
        isHost &&
        _showNetworkQrLobby &&
        !hasAndroidGuest) {
      return PregameQrLobby(
        title: 'إكس أو • دعوة لاعب',
        url: _iphoneUrl,
        connectedPlayers: _iphonePlayers.length,
        accent: const Color(0xFF7C3AED),
        onStart: () {
          GameFeedback.tap();
          setState(() => _showNetworkQrLobby = false);
          _broadcastWebState();
        },
      );
    }
    return Scaffold(
""",
    'XO build',
)
p.write_text(s, encoding='utf-8')

# Checkers
p = Path('lib/games/checkers/checkers_game.dart')
s = p.read_text(encoding='utf-8')
s = replace_once(
    s,
    "import '../../core/audio_feedback.dart';\n",
    "import '../../core/audio_feedback.dart';\nimport '../../core/pregame_qr_lobby.dart';\n",
    'Checkers import',
)
s = replace_once(
    s,
    "  int _iphonePlayers = 0;\n",
    "  int _iphonePlayers = 0;\n  bool _showNetworkQrLobby = true;\n",
    'Checkers field',
)
s = replace_once(
    s,
    "  @override\n  Widget build(BuildContext context) {\n    return AnimatedBuilder(\n",
    """  @override
  Widget build(BuildContext context) {
    if (networkMode &&
        localPlayerIsRed &&
        _showNetworkQrLobby &&
        !hasAndroidGuest) {
      return PregameQrLobby(
        title: 'الضامة • دعوة لاعب',
        url: _iphoneUrl,
        connectedPlayers: _iphonePlayers,
        accent: const Color(0xFFE11D48),
        onStart: () {
          GameFeedback.tap();
          setState(() => _showNetworkQrLobby = false);
          _broadcastIphoneState();
        },
      );
    }
    return AnimatedBuilder(
""",
    'Checkers build',
)
p.write_text(s, encoding='utf-8')

# Line games (Sheikh Beard + Dots & Boxes)
p = Path('lib/games/line_games/line_games.dart')
s = p.read_text(encoding='utf-8')
s = replace_once(
    s,
    "import '../../core/audio_feedback.dart';\n",
    "import '../../core/audio_feedback.dart';\nimport '../../core/pregame_qr_lobby.dart';\n",
    'Line import',
)
s = replace_once(
    s,
    "  String _webUrl = '';\n  int _turnIndex = 0;\n",
    "  String _webUrl = '';\n  bool _showNetworkQrLobby = true;\n  int _turnIndex = 0;\n",
    'Line field',
)
s = replace_once(
    s,
    """    return Scaffold(
      appBar: AppBar(
        title: Text(title),
""",
    """    if (_isHost && _showNetworkQrLobby) {
      return PregameQrLobby(
        title: '$title • دعوة لاعب',
        url: _webUrl,
        connectedPlayers: _webPlayers.length,
        accent: widget.kind == LineGameKind.sheikhBeard
            ? const Color(0xFF2563EB)
            : const Color(0xFF14B8A6),
        onStart: () {
          GameFeedback.tap();
          setState(() => _showNetworkQrLobby = false);
          _broadcastState();
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
""",
    'Line build',
)
p.write_text(s, encoding='utf-8')

# Name / Animal / Object
p = Path('lib/games/name_animal_object/name_animal_object_game.dart')
s = p.read_text(encoding='utf-8')
s = replace_once(
    s,
    "import '../../core/audio_feedback.dart';\n",
    "import '../../core/audio_feedback.dart';\nimport '../../core/pregame_qr_lobby.dart';\n",
    'Name import',
)
s = replace_once(
    s,
    "  bool _finishing = false;\n",
    "  bool _finishing = false;\n  bool _showNetworkQrLobby = true;\n",
    'Name field',
)
s = replace_once(
    s,
    """  @override
  Widget build(BuildContext context) {
    if (_network == null)
      return const Scaffold(body: Center(child: Text('أنشئ غرفة أولًا.')));
    return Scaffold(
""",
    """  @override
  Widget build(BuildContext context) {
    if (_network == null)
      return const Scaffold(body: Center(child: Text('أنشئ غرفة أولًا.')));
    if (_isHost &&
        _stage == _Stage.waiting &&
        _showNetworkQrLobby) {
      return PregameQrLobby(
        title: 'اسم حيوان جماد • دعوة لاعبين',
        url: _webUrl,
        connectedPlayers: _webPlayers.length,
        accent: const Color(0xFF8B5CF6),
        onStart: () {
          GameFeedback.tap();
          setState(() => _showNetworkQrLobby = false);
        },
      );
    }
    return Scaffold(
""",
    'Name build',
)
p.write_text(s, encoding='utf-8')

# Shared room copy: every browser-capable game explains that QR comes before gameplay.
p = Path('lib/core/game_room.dart')
s = p.read_text(encoding='utf-8')
s = s.replace(
    "'افتح اللعبة لإظهار QR للمتصفح بعد انضمام اللاعب'",
    "'افتح QR الكبير وشاركه قبل ظهور لوحة اللعب'",
)
s = s.replace(
    "? 'بدء اللعبة وفتح QR'",
    "? 'فتح QR الكبير قبل اللعبة'",
)
p.write_text(s, encoding='utf-8')

# Permanent source contract for every currently browser-capable game.
p = Path('test/pregame_qr_all_browser_games_test.dart')
p.write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared QR lobby is large and non-scrollable', () {
    final source = File('lib/core/pregame_qr_lobby.dart').readAsStringSync();
    expect(source, contains('constraints.maxWidth * .78'));
    expect(source, contains("'امسح QR قبل بدء اللعبة'"));
    expect(source, contains('QrImageView('));
    expect(source, isNot(contains('ListView(')));
    expect(source, isNot(contains('SingleChildScrollView(')));
  });

  test('XO uses pregame QR lobby', () {
    final source = File('lib/games/xo/xo_game.dart').readAsStringSync();
    expect(source, contains("title: 'إكس أو • دعوة لاعب'"));
    expect(source, contains('_showNetworkQrLobby'));
  });

  test('checkers uses pregame QR lobby', () {
    final source = File('lib/games/checkers/checkers_game.dart').readAsStringSync();
    expect(source, contains("title: 'الضامة • دعوة لاعب'"));
    expect(source, contains('_showNetworkQrLobby'));
  });

  test('both line games use the shared pregame QR lobby', () {
    final source = File('lib/games/line_games/line_games.dart').readAsStringSync();
    expect(source, contains("title: '$title • دعوة لاعب'"));
    expect(source, contains('LineGameKind.sheikhBeard'));
    expect(source, contains('_showNetworkQrLobby'));
  });

  test('name animal object uses pregame QR lobby', () {
    final source = File('lib/games/name_animal_object/name_animal_object_game.dart').readAsStringSync();
    expect(source, contains("title: 'اسم حيوان جماد • دعوة لاعبين'"));
    expect(source, contains('_showNetworkQrLobby'));
  });

  test('game room labels browser QR as a pregame action', () {
    final source = File('lib/core/game_room.dart').readAsStringSync();
    expect(source, contains("'فتح QR الكبير قبل اللعبة'"));
    expect(source, contains("'افتح QR الكبير وشاركه قبل ظهور لوحة اللعب'"));
  });
}
''', encoding='utf-8')

print('Applied shared pre-game QR lobby to all browser-capable games.')
