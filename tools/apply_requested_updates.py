from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'Expected text not found in {path}: {old[:80]!r}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')


# 1) Reliable audible feedback generated in memory (no binary assets required).
pubspec = Path('pubspec.yaml')
text = pubspec.read_text(encoding='utf-8')
text = text.replace('version: 1.0.0+4', 'version: 1.0.0+5')
if 'audioplayers:' not in text:
    text = text.replace('  qr_flutter: ^4.1.0\n', '  qr_flutter: ^4.1.0\n  audioplayers: ^6.1.0\n')
pubspec.write_text(text, encoding='utf-8')

Path('lib/core/audio_feedback.dart').write_text(r'''import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'app_settings.dart';

class GameFeedback {
  static final AppSettingsController _settings = AppSettingsController.instance;
  static final AudioPlayer _player = AudioPlayer();

  static Uint8List _wavTone(double frequency, int milliseconds) {
    const sampleRate = 22050;
    final samples = (sampleRate * milliseconds / 1000).round();
    final dataSize = samples * 2;
    final bytes = ByteData(44 + dataSize);
    void ascii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        bytes.setUint8(offset + i, value.codeUnitAt(i));
      }
    }
    ascii(0, 'RIFF');
    bytes.setUint32(4, 36 + dataSize, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    bytes.setUint32(40, dataSize, Endian.little);
    for (var i = 0; i < samples; i++) {
      final fade = math.min(1.0, (samples - i) / (sampleRate * 0.035));
      final value = (math.sin(2 * math.pi * frequency * i / sampleRate) *
              10000 * fade)
          .round();
      bytes.setInt16(44 + i * 2, value, Endian.little);
    }
    return bytes.buffer.asUint8List();
  }

  static Future<void> _play(double frequency, int milliseconds,
      {HapticFeedbackType vibration = HapticFeedbackType.selection}) async {
    if (_settings.soundEnabled) {
      try {
        await _player.stop();
        await _player.play(BytesSource(_wavTone(frequency, milliseconds)));
      } catch (_) {
        await SystemSound.play(SystemSoundType.click);
      }
    }
    if (!_settings.vibrationEnabled) return;
    switch (vibration) {
      case HapticFeedbackType.light:
        await HapticFeedback.lightImpact();
      case HapticFeedbackType.medium:
        await HapticFeedback.mediumImpact();
      case HapticFeedbackType.heavy:
        await HapticFeedback.heavyImpact();
      case HapticFeedbackType.selection:
        await HapticFeedback.selectionClick();
    }
  }

  static Future<void> tap() => _play(620, 75);
  static Future<void> move() =>
      _play(760, 90, vibration: HapticFeedbackType.light);
  static Future<void> win() =>
      _play(1040, 260, vibration: HapticFeedbackType.medium);
  static Future<void> error() =>
      _play(190, 230, vibration: HapticFeedbackType.heavy);
  static Future<void> roundStart() =>
      _play(880, 170, vibration: HapticFeedbackType.medium);
  static Future<void> submitted() =>
      _play(700, 120, vibration: HapticFeedbackType.light);
}

enum HapticFeedbackType { selection, light, medium, heavy }
''', encoding='utf-8')

# 2) Shared Safari bridge for XO and Checkers.
Path('lib/core/network/browser_game_bridge.dart').write_text(r'''import 'dart:async';
import 'dart:convert';
import 'dart:io';

class BrowserGameEvent {
  const BrowserGameEvent(this.type, this.data);
  final String type;
  final Map<String, dynamic> data;
}

class BrowserGameBridge {
  BrowserGameBridge({required this.gameId, required this.title});
  static const int port = 40445;
  final String gameId;
  final String title;
  HttpServer? _server;
  WebSocket? _socket;
  final _events = StreamController<BrowserGameEvent>.broadcast();
  Stream<BrowserGameEvent> get events => _events.stream;
  bool get connected => _socket != null;

  Future<String> start() async {
    await stop();
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
    _server!.listen(_handle);
    return 'http://${await _address()}:$port';
  }

  Future<void> _handle(HttpRequest request) async {
    if (request.uri.path == '/ws' && WebSocketTransformer.isUpgradeRequest(request)) {
      final socket = await WebSocketTransformer.upgrade(request);
      _socket = socket;
      socket.listen((raw) {
        try {
          final decoded = jsonDecode(raw.toString());
          if (decoded is Map<String, dynamic>) {
            _events.add(BrowserGameEvent((decoded['type'] ?? '').toString(), decoded));
          }
        } catch (_) {}
      }, onDone: () => _socket = null, onError: (_) => _socket = null);
      return;
    }
    request.response.headers.contentType = ContentType.html;
    request.response.write(_html(gameId, title));
    await request.response.close();
  }

  void send(Map<String, dynamic> message) {
    try {
      _socket?.add(jsonEncode(message));
    } catch (_) {}
  }

  Future<String> _address() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback) return address.address;
      }
    }
    return '0.0.0.0';
  }

  Future<void> stop() async {
    await _socket?.close();
    _socket = null;
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> dispose() async {
    await stop();
    await _events.close();
  }

  static String _html(String gameId, String title) => '''<!doctype html>
<html lang="ar" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><meta name="apple-mobile-web-app-capable" content="yes"><title>$title</title>
<style>:root{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;background:#f5f2fb;color:#241833}*{box-sizing:border-box}body{margin:0;padding:18px}.card{background:#fff;border-radius:22px;padding:16px;margin-bottom:14px;box-shadow:0 8px 24px #33115a18}.hero{background:#6f2dbd;color:#fff;text-align:center}.grid3{display:grid;grid-template-columns:repeat(3,1fr);gap:9px}.xo{aspect-ratio:1;border:0;border-radius:18px;font-size:44px;font-weight:900;background:#eee7fa;color:#6f2dbd}.board8{display:grid;grid-template-columns:repeat(8,1fr);width:100%;aspect-ratio:1}.sq{border:0;padding:0;position:relative}.dark{background:#805a34}.light{background:#f1d8a8}.piece{position:absolute;inset:14%;border-radius:50%;border:2px solid #fff8}.red{background:#d94b4b}.black{background:#222831}.king:after{content:'♛';color:#ffd166;font-size:20px;position:absolute;inset:0;display:grid;place-items:center}.status{text-align:center;font-weight:800}.hidden{display:none}button.action{width:100%;padding:14px;border:0;border-radius:16px;background:#6f2dbd;color:#fff;font-weight:900;font-size:17px}</style></head>
<body><div class="card hero"><h1>$title</h1><div id="status">جاري الاتصال بالمضيف...</div></div><div id="xo" class="card grid3 hidden"></div><div id="checkers" class="card board8 hidden"></div><button class="action" id="reconnect">إعادة الاتصال</button>
<script>const game='$gameId';let ws,state={};const status=document.getElementById('status');function connect(){ws=new WebSocket(`ws://${location.host}/ws`);ws.onopen=()=>{status.textContent='متصل — بانتظار المضيف';ws.send(JSON.stringify({type:'join',game}))};ws.onmessage=e=>{state=JSON.parse(e.data);render()};ws.onclose=()=>status.textContent='انقطع الاتصال بالمضيف'}
function render(){status.textContent=state.message||'متصل';if(game==='xo'){const box=document.getElementById('xo');box.classList.remove('hidden');box.innerHTML='';(state.cells||Array(9).fill('')).forEach((v,i)=>{const b=document.createElement('button');b.className='xo';b.textContent=v;b.disabled=!state.browserTurn||v;b.addEventListener('click',()=>ws.send(JSON.stringify({type:'move',index:i})));box.appendChild(b)})}else{const box=document.getElementById('checkers');box.classList.remove('hidden');box.innerHTML='';(state.board||[]).flat().forEach((v,i)=>{const r=Math.floor(i/8),c=i%8,b=document.createElement('button');b.className='sq '+((r+c)%2?'dark':'light');if(v&&v!=='empty'){const p=document.createElement('span');p.className='piece '+(v.startsWith('red')?'red':'black')+(v.endsWith('King')?' king':'');b.appendChild(p)}b.addEventListener('click',()=>ws.send(JSON.stringify({type:'cell',row:r,col:c})));box.appendChild(b)})}}
document.getElementById('reconnect').addEventListener('click',connect);connect();</script></body></html>''';
}
''', encoding='utf-8')

# 3) Name/animal/object: real sounds, responsive no-scroll result cards, visible score editing.
name_path = Path('lib/games/name_animal_object/name_animal_object_game.dart')
name = name_path.read_text(encoding='utf-8')
name = name.replace("import 'package:flutter/services.dart';\n", '')
if "../../core/audio_feedback.dart" not in name:
    name = name.replace("import '../../core/network/local_network_core.dart';", "import '../../core/audio_feedback.dart';\nimport '../../core/network/local_network_core.dart';")
start = name.index('  void _sound(')
end = name.index('\n\n  Future<void> _startWebBridge', start)
name = name[:start] + "  void _sound([bool important = false]) {\n    if (important) {\n      GameFeedback.roundStart();\n    } else {\n      GameFeedback.tap();\n    }\n  }" + name[end:]
name = name.replace('_sound(SystemSoundType.alert);', '_sound(true);')
name = name.replace('    _sound();\n    _network?.sendMove({', '    GameFeedback.submitted();\n    _network?.sendMove({')
old_results = name[name.index('  Widget _results() {'):name.index('\n\n  Widget _info(', name.index('  Widget _results() {'))]
new_results = r'''  Widget _results() {
    final ids = _scores.keys.toList()
      ..sort((a, b) => (_scores[b] ?? 0).compareTo(_scores[a] ?? 0));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          'نتائج حرف $_letter',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        ...ids.map((id) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(_playerNames[id] ?? 'لاعب',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w900)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE4FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '+${_lastPoints[id] ?? 0}  •  ${_scores[id] ?? 0}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    LayoutBuilder(builder: (context, constraints) {
                      final columns = constraints.maxWidth < 380 ? 2 : 3;
                      return GridView.count(
                        crossAxisCount: columns,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 7,
                        crossAxisSpacing: 7,
                        childAspectRatio: columns == 2 ? 2.2 : 1.7,
                        children: _categories.map((category) {
                          final answer = _lastAnswers[id]?[category] ?? '';
                          return Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: const Color(0xFFD6C8EE)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(category,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF6F2DBD),
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 3),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(answer.isEmpty ? '—' : answer,
                                      maxLines: 1,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    }),
                    if (_isHost) ...[
                      const SizedBox(height: 9),
                      OutlinedButton.icon(
                        onPressed: () => _proposeScoreEdit(id),
                        icon: const Icon(Icons.how_to_vote),
                        label: const Text('اقتراح تعديل نتيجة هذا اللاعب'),
                      ),
                    ],
                  ],
                ),
              ),
            )),
        if (_proposals.isNotEmpty)
          Card(
            color: const Color(0xFFFFF3D8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'طلبات تعديل قيد التصويت: ${_proposals.length} — يطبق التعديل بعد موافقة لاعبين مختلفين.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        if (_isHost)
          FilledButton.icon(
            onPressed: _totalPlayers >= 2 ? _startRound : null,
            icon: const Icon(Icons.refresh),
            label: const Text('حرف جديد'),
          )
        else
          const Text('بانتظار المضيف للحرف التالي',
              textAlign: TextAlign.center),
      ],
    );
  }'''
name = name.replace(old_results, new_results)
# Ensure host vote is counted and proposal immediately visible.
name = name.replace("    _proposals[id] = proposal;", "    setState(() => _proposals[id] = proposal);")
name = name.replace("    _proposals.remove(proposalId);", "    setState(() => _proposals.remove(proposalId));")
name_path.write_text(name, encoding='utf-8')

# 4) XO: Safari opponent support with QR and synchronized board.
xo = Path('lib/games/xo/xo_game.dart').read_text(encoding='utf-8')
xo = xo.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:qr_flutter/qr_flutter.dart';")
xo = xo.replace("import '../../core/network/local_network_core.dart';", "import '../../core/audio_feedback.dart';\nimport '../../core/network/browser_game_bridge.dart';\nimport '../../core/network/local_network_core.dart';")
xo = xo.replace("  StreamSubscription<NetworkMessage>? networkSubscription;", "  StreamSubscription<NetworkMessage>? networkSubscription;\n  BrowserGameBridge? webBridge;\n  StreamSubscription<BrowserGameEvent>? webSubscription;\n  String webUrl = '';\n  bool webPlayerConnected = false;")
xo = xo.replace("      networkSubscription = widget.networkCore!.messages.listen(_handleNetworkMessage);", "      networkSubscription = widget.networkCore!.messages.listen(_handleNetworkMessage);\n      if (isHost) _startWebBridge();")
xo = xo.replace("    networkSubscription?.cancel();\n    super.dispose();", "    networkSubscription?.cancel();\n    webSubscription?.cancel();\n    webBridge?.dispose();\n    super.dispose();")
insert_at = xo.index('  void _handleNetworkMessage(')
web_methods = r'''  Future<void> _startWebBridge() async {
    final bridge = BrowserGameBridge(gameId: 'xo', title: 'إكس أو');
    webBridge = bridge;
    webSubscription = bridge.events.listen((event) {
      if (event.type == 'join') {
        setState(() => webPlayerConnected = true);
        _broadcastWebState();
      } else if (event.type == 'move') {
        final index = (event.data['index'] as num?)?.toInt() ?? -1;
        if (index >= 0 && index < 9 && !xTurn &&
            cells[index] == XoCell.empty && !roundCounted) {
          cells[index] = XoCell.o;
          GameFeedback.move();
          afterMove();
        }
      }
    });
    try {
      final url = await bridge.start();
      if (mounted) setState(() => webUrl = url);
    } catch (_) {}
  }

  void _broadcastWebState() {
    webBridge?.send({
      'type': 'state',
      'cells': cells.map((c) => c == XoCell.empty ? '' : c.name.toUpperCase()).toList(),
      'browserTurn': !xTurn && !roundCounted && winLine.isEmpty,
      'message': message,
      'xWins': xWins,
      'oWins': oWins,
      'draws': draws,
    });
  }

'''
xo = xo[:insert_at] + web_methods + xo[insert_at:]
xo = xo.replace("    if (notifyPeer && isNetworkGame) {", "    _broadcastWebState();\n    if (notifyPeer && isNetworkGame) {")
xo = xo.replace("    setState(() {});\n\n    if (playVsBot && !xTurn) runBot();", "    setState(() {});\n    GameFeedback.move();\n    _broadcastWebState();\n\n    if (playVsBot && !xTurn) runBot();")
# Winner/draw branches also need state broadcast.
xo = xo.replace("      setState(() => message = winner == XoCell.x ? 'فاز X' : 'فاز O');\n      return;", "      setState(() => message = winner == XoCell.x ? 'فاز X' : 'فاز O');\n      GameFeedback.win();\n      _broadcastWebState();\n      return;")
xo = xo.replace("      setState(() => message = 'تعادل');\n      return;", "      setState(() => message = 'تعادل');\n      _broadcastWebState();\n      return;")
marker = "              const SizedBox(height: 12),\n              Row("
card = r'''              if (isHost && isNetworkGame) ...[
                Card(
                  color: const Color(0xFFEDE4FF),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(children: [
                      const Text('دخول لاعب الآيفون',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      if (webUrl.startsWith('http'))
                        QrImageView(data: webUrl, size: 150,
                            backgroundColor: Colors.white),
                      SelectableText(webUrl.isEmpty
                          ? 'جاري تجهيز الرابط...' : webUrl,
                          textAlign: TextAlign.center),
                      Text(webPlayerConnected
                          ? 'الآيفون متصل ويلعب بعلامة O'
                          : 'امسح QR أو افتح الرابط من Safari على نفس الشبكة'),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row('''
xo = xo.replace(marker, card, 1)
Path('lib/games/xo/xo_game.dart').write_text(xo, encoding='utf-8')

# 5) Checkers: Safari black player support, QR, synchronized board.
check = Path('lib/games/checkers/checkers_game.dart').read_text(encoding='utf-8')
check = check.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:qr_flutter/qr_flutter.dart';")
check = check.replace("import '../../core/network/local_network_core.dart';", "import '../../core/network/browser_game_bridge.dart';\nimport '../../core/network/local_network_core.dart';")
check = check.replace("  StreamSubscription<NetworkMessage>? networkSubscription;", "  StreamSubscription<NetworkMessage>? networkSubscription;\n  BrowserGameBridge? webBridge;\n  StreamSubscription<BrowserGameEvent>? webSubscription;\n  String webUrl = '';\n  bool webPlayerConnected = false;\n  int? webSelectedRow;\n  int? webSelectedCol;")
check = check.replace("    networkSubscription = widget.networkCore?.messages.listen(_handleNetworkMessage);\n    resetBoard();", "    networkSubscription = widget.networkCore?.messages.listen(_handleNetworkMessage);\n    resetBoard();\n    if (networkMode && localPlayerIsRed) _startWebBridge();")
check = check.replace("    networkSubscription?.cancel();\n    super.dispose();", "    networkSubscription?.cancel();\n    webSubscription?.cancel();\n    webBridge?.dispose();\n    super.dispose();")
pos = check.index('  void resetBoard()')
methods = r'''  Future<void> _startWebBridge() async {
    final bridge = BrowserGameBridge(gameId: 'checkers', title: 'الضامة');
    webBridge = bridge;
    webSubscription = bridge.events.listen((event) {
      if (event.type == 'join') {
        setState(() => webPlayerConnected = true);
        _broadcastWebState();
      } else if (event.type == 'cell') {
        final row = (event.data['row'] as num?)?.toInt() ?? -1;
        final col = (event.data['col'] as num?)?.toInt() ?? -1;
        _handleWebCell(row, col);
      }
    });
    try {
      final url = await bridge.start();
      if (mounted) setState(() => webUrl = url);
    } catch (_) {}
  }

  void _handleWebCell(int row, int col) {
    if (row < 0 || row > 7 || col < 0 || col > 7 || redTurn || gameFinished) return;
    if (webSelectedRow == null) {
      if (isBlackPiece(board[row][col])) {
        webSelectedRow = row;
        webSelectedCol = col;
        _broadcastWebState();
      }
      return;
    }
    final move = legalMoveFor(webSelectedRow!, webSelectedCol!, row, col, false);
    if (move == null) {
      if (isBlackPiece(board[row][col]) && !mustContinueCapture) {
        webSelectedRow = row;
        webSelectedCol = col;
      }
      _broadcastWebState();
      return;
    }
    GameFeedback.move();
    applyMove(move);
    if (networkMode) widget.networkCore!.sendMove(move.toJson(), senderId: 'web-checkers');
    if (updateMatchStatus()) {
      _broadcastWebState();
      setState(() {});
      return;
    }
    final next = move.isCapture ? captureMovesFrom(move.toRow, move.toCol, false) : const <CheckersMove>[];
    if (next.isNotEmpty) {
      webSelectedRow = move.toRow;
      webSelectedCol = move.toCol;
      mustContinueCapture = true;
      message = 'لاعب الآيفون يكمل الأكل...';
    } else {
      webSelectedRow = null;
      webSelectedCol = null;
      mustContinueCapture = false;
      redTurn = true;
      selectedRow = null;
      selectedCol = null;
      message = currentTurnMessage();
    }
    setState(() {});
    _broadcastWebState();
  }

  void _broadcastWebState() {
    webBridge?.send({
      'type': 'state',
      'board': board.map((row) => row.map((p) => p.name).toList()).toList(),
      'browserTurn': !redTurn && !gameFinished,
      'message': message,
      'selectedRow': webSelectedRow,
      'selectedCol': webSelectedCol,
    });
  }

'''
check = check[:pos] + methods + check[pos:]
check = check.replace("    if (mounted) setState(() {});\n  }\n\n  void requestBoardReset", "    if (mounted) setState(() {});\n    _broadcastWebState();\n  }\n\n  void requestBoardReset", 1)
check = check.replace("    if (playVsBot && !redTurn) runBotMove();", "    _broadcastWebState();\n    if (playVsBot && !redTurn) runBotMove();")
check = check.replace("    GameFeedback.win();\n    _showMatchResultDialog(status);", "    GameFeedback.win();\n    _broadcastWebState();\n    _showMatchResultDialog(status);")
ui_marker = "                        Row(\n                          children: [\n                            Expanded(child: _InfoChip(label: 'أحجار الأحمر'"
web_card = r'''                        if (networkMode && localPlayerIsRed) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE4FF),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(children: [
                              const Text('دخول الآيفون — يلعب بالأسود',
                                  style: TextStyle(fontWeight: FontWeight.w900)),
                              if (webUrl.startsWith('http'))
                                QrImageView(data: webUrl, size: 130,
                                    backgroundColor: Colors.white),
                              SelectableText(webUrl.isEmpty
                                  ? 'جاري تجهيز الرابط...' : webUrl,
                                  textAlign: TextAlign.center),
                              Text(webPlayerConnected ? 'الآيفون متصل' :
                                  'امسح QR أو افتح الرابط في Safari'),
                            ]),
                          ),
                        ],
                        Row(
                          children: [
                            Expanded(child: _InfoChip(label: 'أحجار الأحمر' '''
check = check.replace(ui_marker, web_card, 1)
Path('lib/games/checkers/checkers_game.dart').write_text(check, encoding='utf-8')

# 6) Room can open with only Android host for browser-supported games.
room = Path('lib/core/game_room.dart').read_text(encoding='utf-8')
room = room.replace("  bool get _isNameGame => widget.game.id == 'name_animal_object';", "  bool get _isNameGame => widget.game.id == 'name_animal_object';\n  bool get _supportsBrowserPlayer => const {'name_animal_object', 'xo', 'checkers'}.contains(widget.game.id);")
room = room.replace("final bool canStart = hostReady &&\n              (_isNameGame ? state.players.isNotEmpty : state.players.length >= 2);", "final bool canStart = hostReady &&\n              (_supportsBrowserPlayer ? state.players.isNotEmpty : state.players.length >= 2);")
Path('lib/core/game_room.dart').write_text(room, encoding='utf-8')

print('Requested updates applied successfully.')
