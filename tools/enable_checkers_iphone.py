from pathlib import Path

path = Path('lib/games/checkers/checkers_game.dart')
text = path.read_text(encoding='utf-8')

text = text.replace(
"import 'package:flutter/material.dart';\n",
"import 'package:flutter/material.dart';\nimport 'package:qr_flutter/qr_flutter.dart';\n",
)
text = text.replace(
"import '../../core/app_settings.dart';\n",
"import '../../core/app_settings.dart';\nimport '../../core/iphone_game_bridge.dart';\n",
)
text = text.replace(
"import 'checkers_match_status.dart';\n",
"import 'checkers_match_status.dart';\nimport 'checkers_iphone_web.dart';\n",
)

field_anchor = "  StreamSubscription<NetworkMessage>? networkSubscription;\n"
field_insert = """  StreamSubscription<NetworkMessage>? networkSubscription;
  IphoneGameBridge? _iphoneBridge;
  StreamSubscription<List<IphoneWebPlayer>>? _iphonePlayersSub;
  StreamSubscription<IphoneWebEvent>? _iphoneEventsSub;
  String _iphoneUrl = '';
  int _iphonePlayers = 0;
"""
text = text.replace(field_anchor, field_insert)

init_old = """    networkSubscription =
        widget.networkCore?.messages.listen(_handleNetworkMessage);
    resetBoard();
  }
"""
init_new = """    networkSubscription =
        widget.networkCore?.messages.listen(_handleNetworkMessage);
    resetBoard();
    if (networkMode && localPlayerIsRed) {
      unawaited(_startIphoneBridge());
    }
  }
"""
text = text.replace(init_old, init_new)

dispose_old = """  void dispose() {
    networkSubscription?.cancel();
    super.dispose();
  }
"""
dispose_new = """  void dispose() {
    networkSubscription?.cancel();
    _iphonePlayersSub?.cancel();
    _iphoneEventsSub?.cancel();
    unawaited(_iphoneBridge?.dispose());
    super.dispose();
  }
"""
text = text.replace(dispose_old, dispose_new)

reset_old = """    message = currentTurnMessage();
    if (mounted) setState(() {});
  }
"""
reset_new = """    message = currentTurnMessage();
    if (mounted) setState(() {});
    _broadcastIphoneState();
  }
"""
text = text.replace(reset_old, reset_new, 1)

text = text.replace(
"  void tapCell(int r, int c) {\n",
"  void tapCell(int r, int c) => _tapCell(r, c);\n\n  void _tapCell(int r, int c, {bool fromIphone = false}) {\n",
)
text = text.replace(
"    if (networkMode && !isMyNetworkTurn) {\n",
"    if (networkMode && !(fromIphone ? !redTurn : isMyNetworkTurn)) {\n",
1,
)
text = text.replace(
"    if (networkMode) {\n      widget.networkCore!.sendMove(move.toJson(), senderId: _localPlayerId());\n    }\n",
"    if (networkMode && !fromIphone) {\n      widget.networkCore!.sendMove(move.toJson(), senderId: _localPlayerId());\n    }\n",
1,
)

finish_old = """    message = currentTurnMessage();
    setState(() {});

    if (playVsBot && !redTurn) runBotMove();
  }
"""
finish_new = """    message = currentTurnMessage();
    setState(() {});
    _broadcastIphoneState();

    if (playVsBot && !redTurn) runBotMove();
  }
"""
text = text.replace(finish_old, finish_new)

runbot_old = """    message = 'أنت الأحمر - دورك';
    setState(() {});
  }
"""
runbot_new = """    message = 'أنت الأحمر - دورك';
    setState(() {});
    _broadcastIphoneState();
  }
"""
text = text.replace(runbot_old, runbot_new)

helper_anchor = "  @override\n  Widget build(BuildContext context) {\n"
helpers = r'''  Future<void> _startIphoneBridge() async {
    final bridge = IphoneGameBridge(html: checkersIphoneHtml, port: 40450);
    _iphoneBridge = bridge;
    _iphonePlayersSub = bridge.players.stream.listen((players) {
      if (!mounted) return;
      setState(() => _iphonePlayers = players.length);
      _broadcastIphoneState();
    });
    _iphoneEventsSub = bridge.events.stream.listen((event) {
      if (event.type != 'tap' || redTurn || gameFinished) return;
      final row = (event.data['row'] as num?)?.toInt() ?? -1;
      final col = (event.data['col'] as num?)?.toInt() ?? -1;
      if (!inside(row, col)) return;
      _tapCell(row, col, fromIphone: true);
      _broadcastIphoneState();
    });
    try {
      final url = await bridge.start();
      if (mounted) setState(() => _iphoneUrl = url);
      _broadcastIphoneState();
    } catch (_) {
      if (mounted) setState(() => _iphoneUrl = 'تعذر تشغيل رابط الآيفون');
    }
  }

  void _broadcastIphoneState() {
    final bridge = _iphoneBridge;
    if (bridge == null) return;
    bridge.broadcast(<String, dynamic>{
      'type': 'state',
      'message': message,
      'redTurn': redTurn,
      'canPlay': !redTurn && !gameFinished,
      'finished': gameFinished,
      'redCount': redPieceCount,
      'blackCount': blackPieceCount,
      'selected': selectedRow == null ? '' : '$selectedRow,$selectedCol',
      'targets': possibleTargets.toList(),
      'board': board
          .map((row) => row.map((piece) => piece.name).toList())
          .toList(),
    });
  }

  Widget _iphoneCard() {
    if (!networkMode || !localPlayerIsRed) return const SizedBox.shrink();
    return Card(
      color: const Color(0xFFEAF8F1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: <Widget>[
            const Text('دخول الآيفون', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 8),
            if (_iphoneUrl.startsWith('http'))
              QrImageView(data: _iphoneUrl, size: 150, backgroundColor: Colors.white),
            SelectableText(_iphoneUrl.isEmpty ? 'جاري تجهيز الرابط...' : _iphoneUrl,
                textAlign: TextAlign.center),
            Text('لاعبو Safari: $_iphonePlayers'),
          ],
        ),
      ),
    );
  }

'''
text = text.replace(helper_anchor, helpers + helper_anchor)

body_anchor = """          body: Column(
            children: [
"""
body_new = """          body: Column(
            children: [
              if (networkMode && localPlayerIsRed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _iphoneCard(),
                ),
"""
text = text.replace(body_anchor, body_new, 1)

path.write_text(text, encoding='utf-8')
