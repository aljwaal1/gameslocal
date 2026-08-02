import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/audio_feedback.dart';
import '../../core/network/local_network_core.dart';
import '../../core/network/network_message.dart';

enum LineGameKind { sheikhBeard, dotsBoxes }

class LineGameScreen extends StatefulWidget {
  const LineGameScreen({
    super.key,
    required this.kind,
    this.networkCore,
  });

  final LineGameKind kind;
  final LocalNetworkCore? networkCore;

  @override
  State<LineGameScreen> createState() => _LineGameScreenState();
}

class _WebPlayer {
  const _WebPlayer(this.id, this.name);

  final String id;
  final String name;
}

class _WebEvent {
  const _WebEvent(this.id, this.type, this.data);

  final String id;
  final String type;
  final Map<String, dynamic> data;
}

class _LineWebBridge {
  _LineWebBridge(this.kind);

  static const int port = 40446;

  final LineGameKind kind;
  HttpServer? _server;
  final Map<String, _WebPlayer> _players = <String, _WebPlayer>{};
  final Map<String, WebSocket> _sockets = <String, WebSocket>{};
  final StreamController<List<_WebPlayer>> players =
      StreamController<List<_WebPlayer>>.broadcast();
  final StreamController<_WebEvent> events =
      StreamController<_WebEvent>.broadcast();

  Future<String> start() async {
    await _server?.close(force: true);
    _server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      port,
      shared: true,
    );
    _server!.listen(_handleRequest);

    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.address.startsWith('169.254.')) {
          return 'http://${address.address}:$port';
        }
      }
    }
    return 'http://0.0.0.0:$port';
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.uri.path == '/ws' &&
        WebSocketTransformer.isUpgradeRequest(request)) {
      _attachSocket(await WebSocketTransformer.upgrade(request));
      return;
    }

    request.response.headers.contentType = ContentType.html;
    request.response.write(_html(kind));
    await request.response.close();
  }

  void _attachSocket(WebSocket socket) {
    String? playerId;

    socket.listen(
      (dynamic raw) {
        try {
          final dynamic decoded = jsonDecode(raw.toString());
          if (decoded is! Map) return;
          final message = decoded.map<String, dynamic>(
            (dynamic key, dynamic value) =>
                MapEntry<String, dynamic>(key.toString(), value),
          );
          final type = (message['type'] ?? '').toString();

          if (type == 'join') {
            final name = (message['name'] ?? '').toString().trim();
            playerId = 'web-${DateTime.now().microsecondsSinceEpoch}';
            final player = _WebPlayer(
              playerId!,
              name.isEmpty ? 'لاعب آيفون' : name,
            );
            _players[player.id] = player;
            _sockets[player.id] = socket;
            socket.add(
              jsonEncode(<String, dynamic>{
                'type': 'joined',
                'id': player.id,
                'name': player.name,
              }),
            );
            players.add(List<_WebPlayer>.unmodifiable(_players.values));
            return;
          }

          if (playerId != null) {
            events.add(_WebEvent(playerId!, type, message));
          }
        } catch (_) {}
      },
      onDone: () => _remove(playerId),
      onError: (_) => _remove(playerId),
    );
  }

  void _remove(String? id) {
    if (id == null) return;
    _players.remove(id);
    _sockets.remove(id);
    players.add(List<_WebPlayer>.unmodifiable(_players.values));
  }

  void broadcast(Map<String, dynamic> message) {
    final encoded = jsonEncode(message);
    for (final socket in List<WebSocket>.from(_sockets.values)) {
      try {
        socket.add(encoded);
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    for (final socket in List<WebSocket>.from(_sockets.values)) {
      await socket.close();
    }
    _sockets.clear();
    _players.clear();
    await _server?.close(force: true);
    _server = null;
    await players.close();
    await events.close();
  }

  static String _html(LineGameKind kind) {
    final title = kind == LineGameKind.sheikhBeard ? 'لحية الشيخ' : 'المربعات';
    final gameName = kind.name;
    return '''<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>$title</title>
<style>
*{box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;margin:0;background:#f6f3ff;color:#241a2e;padding:18px}
.card{background:#fff;border-radius:22px;padding:16px;margin:10px 0;box-shadow:0 8px 25px #3b17601a}
h1{text-align:center}input,button{width:100%;font-size:18px;padding:13px;border-radius:14px;margin:6px 0}
input{border:1px solid #d8cdea}button{border:0;background:#6f2dbd;color:#fff;font-weight:800}.hidden{display:none}
canvas{width:100%;aspect-ratio:1;background:#fff;border-radius:18px;touch-action:none}
.scores{display:flex;gap:8px;flex-wrap:wrap}.pill{flex:1;min-width:110px;background:#eee8ff;border-radius:14px;padding:10px;text-align:center}
</style>
</head>
<body>
<section id="join" class="card">
<h1>$title</h1>
<input id="name" placeholder="اسم اللاعب">
<button id="joinBtn">دخول</button>
</section>
<section id="game" class="hidden">
<div class="card">
<div id="status">بانتظار المضيف...</div>
<div id="scores" class="scores"></div>
</div>
<canvas id="board" width="700" height="700"></canvas>
</section>
<script>
const kind='$gameName';
let ws,id,state={};
const canvas=document.getElementById('board');
const ctx=canvas.getContext('2d');

document.getElementById('joinBtn').addEventListener('click',()=>{
  const name=document.getElementById('name').value.trim();
  if(!name)return;
  ws=new WebSocket(`ws://\${location.host}/ws`);
  ws.onopen=()=>ws.send(JSON.stringify({type:'join',name}));
  ws.onmessage=(event)=>{
    const message=JSON.parse(event.data);
    if(message.type==='joined'){
      id=message.id;
      document.getElementById('join').classList.add('hidden');
      document.getElementById('game').classList.remove('hidden');
    }else if(message.type==='state'){
      state=message;
      draw();
    }
  };
});

canvas.addEventListener('pointerdown',(event)=>{
  if(!ws||state.turnId!==id)return;
  const rect=canvas.getBoundingClientRect();
  const px=(event.clientX-rect.left)*700/rect.width;
  const py=(event.clientY-rect.top)*700/rect.height;

  if(kind==='sheikhBeard'){
    let best=-1,dist=1e9;
    (state.points||[]).forEach((point,index)=>{
      if(point.ownerId)return;
      const d=(point.x-px)**2+(point.y-py)**2;
      if(d<dist){dist=d;best=index;}
    });
    if(best>=0&&dist<1000){
      ws.send(JSON.stringify({type:'move',index:best}));
    }
  }else{
    let best=-1,dist=1e9;
    (state.edges||[]).forEach((edge,index)=>{
      if(edge.ownerId)return;
      const a=state.points[edge.a],b=state.points[edge.b];
      const vx=b.x-a.x,vy=b.y-a.y;
      const length=vx*vx+vy*vy;
      const t=Math.max(0,Math.min(1,((px-a.x)*vx+(py-a.y)*vy)/length));
      const qx=a.x+t*vx,qy=a.y+t*vy;
      const d=(px-qx)**2+(py-qy)**2;
      if(d<dist){dist=d;best=index;}
    });
    if(best>=0&&dist<650){
      ws.send(JSON.stringify({type:'move',index:best}));
    }
  }
});

function draw(){
  ctx.clearRect(0,0,700,700);
  document.getElementById('status').textContent=state.message||'';
  document.getElementById('scores').innerHTML=(state.players||[])
    .map(p=>`<div class="pill">\${p.name}<br><b>\${p.score||0}</b></div>`).join('');

  (state.boxes||[]).forEach(box=>{
    if(!box.color)return;
    const a=state.points[box.points[0]];
    const b=state.points[box.points[3]];
    ctx.fillStyle=box.color+'44';
    ctx.fillRect(a.x+8,a.y+8,b.x-a.x-16,b.y-a.y-16);
  });

  (state.lines||[]).forEach(line=>{
    const a=state.points[line.a],b=state.points[line.b];
    ctx.strokeStyle=line.color;
    ctx.lineWidth=10;
    ctx.lineCap='round';
    ctx.beginPath();ctx.moveTo(a.x,a.y);ctx.lineTo(b.x,b.y);ctx.stroke();
  });

  (state.edges||[]).forEach(edge=>{
    const a=state.points[edge.a],b=state.points[edge.b];
    ctx.strokeStyle=edge.color||'#ddd';
    ctx.lineWidth=edge.ownerId?8:3;
    ctx.lineCap='round';
    ctx.beginPath();ctx.moveTo(a.x,a.y);ctx.lineTo(b.x,b.y);ctx.stroke();
  });

  (state.points||[]).forEach(point=>{
    ctx.fillStyle=point.color||'#fff';
    ctx.strokeStyle='#382747';
    ctx.lineWidth=3;
    ctx.beginPath();ctx.arc(point.x,point.y,14,0,Math.PI*2);ctx.fill();ctx.stroke();
  });
}
</script>
</body>
</html>''';
  }
}

class _LineGameScreenState extends State<LineGameScreen> {
  static const List<Color> _colors = <Color>[
    Color(0xFFE63946),
    Color(0xFF277DA1),
    Color(0xFF2A9D8F),
    Color(0xFFF4A261),
  ];

  final List<Offset> _points = <Offset>[];
  final List<int> _pointOwners = <int>[];
  final List<List<int>> _edges = <List<int>>[];
  final List<String?> _edgeOwners = <String?>[];
  final List<List<int>> _boxes = <List<int>>[];
  final List<String?> _boxOwners = <String?>[];
  final List<List<int>> _sheikhLines = <List<int>>[];
  final Map<String, String> _claimedSheikhLines = <String, String>{};
  final Map<String, int> _scores = <String, int>{};
  final List<_WebPlayer> _webPlayers = <_WebPlayer>[];

  StreamSubscription<NetworkMessage>? _networkSubscription;
  StreamSubscription<List<_WebPlayer>>? _webPlayersSubscription;
  StreamSubscription<_WebEvent>? _webEventsSubscription;
  _LineWebBridge? _bridge;

  String _webUrl = '';
  int _turnIndex = 0;

  bool get _isHost => widget.networkCore?.state.mode == LocalNetworkMode.host;

  String get _myId => widget.networkCore?.localPlayerId ?? 'local';

  List<Map<String, String>> get _players {
    final result = <Map<String, String>>[];
    for (final player
        in widget.networkCore?.state.players ?? const <LocalPlayer>[]) {
      result.add(<String, String>{
        'id': player.id,
        'name': player.name,
      });
    }
    for (final player in _webPlayers) {
      result.add(<String, String>{
        'id': player.id,
        'name': player.name,
      });
    }
    return result;
  }

  String get _turnId {
    final players = _players;
    if (players.isEmpty) return '';
    return players[_turnIndex % players.length]['id']!;
  }

  @override
  void initState() {
    super.initState();
    _buildBoard();
    _networkSubscription =
        widget.networkCore?.messages.listen(_handleNetworkMessage);
    if (_isHost) {
      _startWebBridge();
    }
  }

  void _buildBoard() {
    if (widget.kind == LineGameKind.sheikhBeard) {
      const rows = 7;
      final rowStarts = <int>[];

      for (var row = 0; row < rows; row++) {
        rowStarts.add(_points.length);
        final count = row + 1;
        final y = 80.0 + row * 85;
        final startX = 350.0 - (count - 1) * 43;
        for (var column = 0; column < count; column++) {
          _points.add(Offset(startX + column * 86, y));
        }
      }
      _pointOwners.addAll(List<int>.filled(_points.length, -1));

      for (var row = 0; row < rows; row++) {
        _sheikhLines.add(
          List<int>.generate(
            row + 1,
            (index) => rowStarts[row] + index,
          ),
        );
      }

      for (var column = 0; column < rows; column++) {
        final line = <int>[];
        for (var row = column; row < rows; row++) {
          line.add(rowStarts[row] + column);
        }
        if (line.length >= 3) _sheikhLines.add(line);
      }

      for (var diagonal = 0; diagonal < rows; diagonal++) {
        final line = <int>[];
        for (var row = diagonal; row < rows; row++) {
          final column = row - diagonal;
          line.add(rowStarts[row] + column);
        }
        if (line.length >= 3) _sheikhLines.add(line);
      }
      return;
    }

    const size = 6;
    for (var row = 0; row < size; row++) {
      for (var column = 0; column < size; column++) {
        _points.add(Offset(75 + column * 110, 75 + row * 110));
      }
    }
    _pointOwners.addAll(List<int>.filled(_points.length, -1));

    for (var row = 0; row < size; row++) {
      for (var column = 0; column < size - 1; column++) {
        _edges.add(<int>[row * size + column, row * size + column + 1]);
      }
    }
    for (var row = 0; row < size - 1; row++) {
      for (var column = 0; column < size; column++) {
        _edges.add(<int>[
          row * size + column,
          (row + 1) * size + column,
        ]);
      }
    }
    _edgeOwners.addAll(List<String?>.filled(_edges.length, null));

    for (var row = 0; row < size - 1; row++) {
      for (var column = 0; column < size - 1; column++) {
        _boxes.add(<int>[
          row * size + column,
          row * size + column + 1,
          (row + 1) * size + column,
          (row + 1) * size + column + 1,
        ]);
      }
    }
    _boxOwners.addAll(List<String?>.filled(_boxes.length, null));
  }

  Future<void> _startWebBridge() async {
    final bridge = _LineWebBridge(widget.kind);
    _bridge = bridge;

    _webPlayersSubscription = bridge.players.stream.listen((players) {
      if (!mounted) return;
      setState(() {
        _webPlayers
          ..clear()
          ..addAll(players);
        for (final player in players) {
          _scores.putIfAbsent(player.id, () => 0);
        }
        if (_players.isNotEmpty) {
          _turnIndex %= _players.length;
        } else {
          _turnIndex = 0;
        }
      });
      _broadcastState();
    });

    _webEventsSubscription = bridge.events.stream.listen((event) {
      if (event.type == 'move') {
        final index = (event.data['index'] as num?)?.toInt() ?? -1;
        _processMove(event.id, index);
      }
    });

    try {
      final url = await bridge.start();
      if (mounted) {
        setState(() => _webUrl = url);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _webUrl = 'تعذر تشغيل رابط الآيفون');
      }
    }
  }

  void _handleNetworkMessage(NetworkMessage message) {
    if (message.type != NetworkMessageType.move) return;
    final action = (message.payload['action'] ?? '').toString();

    if (action == 'line_move' && _isHost) {
      final index = (message.payload['index'] as num?)?.toInt() ?? -1;
      _processMove(message.senderId, index);
    } else if (action == 'line_state' && !_isHost) {
      _applyState(message.payload);
    }
  }

  void _requestMove(int index) {
    if (_turnId != _myId || index < 0) return;

    if (_isHost) {
      _processMove(_myId, index);
    } else {
      widget.networkCore?.sendMove(
        <String, dynamic>{
          'action': 'line_move',
          'index': index,
        },
        senderId: _myId,
      );
    }
  }

  void _processMove(String playerId, int index) {
    if (!_isHost || playerId != _turnId || index < 0) return;

    var gained = 0;
    final players = _players;
    final playerIndex =
        players.indexWhere((player) => player['id'] == playerId);
    if (playerIndex < 0) return;

    if (widget.kind == LineGameKind.sheikhBeard) {
      if (index >= _pointOwners.length || _pointOwners[index] >= 0) return;
      _pointOwners[index] = playerIndex;
      gained = _claimCompletedSheikhLines(playerIndex, playerId);
    } else {
      if (index >= _edgeOwners.length || _edgeOwners[index] != null) return;
      _edgeOwners[index] = playerId;
      gained = _claimCompletedBoxes(playerId);
    }

    if (gained > 0) {
      _scores[playerId] = (_scores[playerId] ?? 0) + gained;
      GameFeedback.win();
    } else {
      _turnIndex = (_turnIndex + 1) % players.length;
      GameFeedback.move();
    }

    setState(() {});
    _broadcastState();
  }

  int _claimCompletedSheikhLines(int ownerIndex, String playerId) {
    var gained = 0;
    for (final line in _sheikhLines) {
      if (!line.every((pointIndex) => _pointOwners[pointIndex] == ownerIndex)) {
        continue;
      }
      final key = line.join('-');
      if (_claimedSheikhLines.containsKey(key)) continue;
      _claimedSheikhLines[key] = playerId;
      gained++;
    }
    return gained;
  }

  int _claimCompletedBoxes(String playerId) {
    var gained = 0;
    for (var boxIndex = 0; boxIndex < _boxes.length; boxIndex++) {
      if (_boxOwners[boxIndex] != null) continue;
      final box = _boxes[boxIndex];
      final neededEdges = <int>[
        _edgeIndex(box[0], box[1]),
        _edgeIndex(box[2], box[3]),
        _edgeIndex(box[0], box[2]),
        _edgeIndex(box[1], box[3]),
      ];
      if (neededEdges.every(
        (edgeIndex) => edgeIndex >= 0 && _edgeOwners[edgeIndex] != null,
      )) {
        _boxOwners[boxIndex] = playerId;
        gained++;
      }
    }
    return gained;
  }

  int _edgeIndex(int first, int second) {
    for (var index = 0; index < _edges.length; index++) {
      final edge = _edges[index];
      if ((edge[0] == first && edge[1] == second) ||
          (edge[0] == second && edge[1] == first)) {
        return index;
      }
    }
    return -1;
  }

  String? _colorHexForPlayer(String? playerId) {
    if (playerId == null) return null;
    final index = _players.indexWhere((player) => player['id'] == playerId);
    if (index < 0) return null;
    final value = _colors[index % _colors.length].value;
    return '#${value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  Map<String, dynamic> _createState() {
    final players = _players;
    final serializedPlayers = <Map<String, dynamic>>[];

    for (var index = 0; index < players.length; index++) {
      final player = players[index];
      final id = player['id']!;
      serializedPlayers.add(<String, dynamic>{
        'id': id,
        'name': player['name'],
        'score': _scores[id] ?? 0,
        'color': _colorHexForPlayer(id),
      });
    }

    final serializedLines = <Map<String, dynamic>>[];
    _claimedSheikhLines.forEach((key, ownerId) {
      final line = key.split('-').map(int.parse).toList();
      serializedLines.add(<String, dynamic>{
        'a': line.first,
        'b': line.last,
        'ownerId': ownerId,
        'color': _colorHexForPlayer(ownerId),
      });
    });

    final serializedBoxes = <Map<String, dynamic>>[];
    for (var index = 0; index < _boxes.length; index++) {
      serializedBoxes.add(<String, dynamic>{
        'points': _boxes[index],
        'ownerId': _boxOwners[index],
        'color': _colorHexForPlayer(_boxOwners[index]),
      });
    }

    final turnName = players.isEmpty
        ? ''
        : players[_turnIndex % players.length]['name'] ?? '';

    return <String, dynamic>{
      'type': 'state',
      'kind': widget.kind.name,
      'turnId': _turnId,
      'turnIndex': _turnIndex,
      'message': players.length < 2 ? 'بانتظار لاعب آخر' : 'الدور: $turnName',
      'players': serializedPlayers,
      'scores': _scores,
      'points': List<Map<String, dynamic>>.generate(
        _points.length,
        (index) {
          final ownerIndex = _pointOwners[index];
          final ownerId = ownerIndex >= 0 && ownerIndex < players.length
              ? players[ownerIndex]['id']
              : null;
          return <String, dynamic>{
            'x': _points[index].dx,
            'y': _points[index].dy,
            'ownerId': ownerId,
            'color': _colorHexForPlayer(ownerId),
          };
        },
      ),
      'lines': serializedLines,
      'edges': List<Map<String, dynamic>>.generate(
        _edges.length,
        (index) => <String, dynamic>{
          'a': _edges[index][0],
          'b': _edges[index][1],
          'ownerId': _edgeOwners[index],
          'color': _colorHexForPlayer(_edgeOwners[index]),
        },
      ),
      'boxes': serializedBoxes,
    };
  }

  void _broadcastState() {
    if (!_isHost) return;
    final state = _createState();
    _bridge?.broadcast(state);
    widget.networkCore?.sendMove(
      <String, dynamic>{
        'action': 'line_state',
        ...state,
      },
      senderId: _myId,
    );
  }

  void _applyState(Map<String, dynamic> state) {
    final rawPlayers = state['players'] as List<dynamic>? ?? const [];
    final playerIds = <String>[];
    final parsedScores = <String, int>{};

    for (final item in rawPlayers) {
      if (item is! Map) continue;
      final id = (item['id'] ?? '').toString();
      if (id.isEmpty) continue;
      playerIds.add(id);
      parsedScores[id] = (item['score'] as num?)?.toInt() ?? 0;
    }

    final rawPoints = state['points'] as List<dynamic>? ?? const [];
    for (var index = 0;
        index < rawPoints.length && index < _pointOwners.length;
        index++) {
      final item = rawPoints[index];
      if (item is! Map) continue;
      final ownerId = item['ownerId']?.toString();
      _pointOwners[index] = ownerId == null ? -1 : playerIds.indexOf(ownerId);
    }

    final rawEdges = state['edges'] as List<dynamic>? ?? const [];
    for (var index = 0;
        index < rawEdges.length && index < _edgeOwners.length;
        index++) {
      final item = rawEdges[index];
      if (item is Map) {
        _edgeOwners[index] = item['ownerId']?.toString();
      }
    }

    final rawBoxes = state['boxes'] as List<dynamic>? ?? const [];
    for (var index = 0;
        index < rawBoxes.length && index < _boxOwners.length;
        index++) {
      final item = rawBoxes[index];
      if (item is Map) {
        _boxOwners[index] = item['ownerId']?.toString();
      }
    }

    _claimedSheikhLines.clear();
    final rawLines = state['lines'] as List<dynamic>? ?? const [];
    for (final item in rawLines) {
      if (item is! Map) continue;
      final first = (item['a'] as num?)?.toInt();
      final last = (item['b'] as num?)?.toInt();
      final ownerId = item['ownerId']?.toString();
      if (first == null || last == null || ownerId == null) continue;
      final matching = _sheikhLines.where(
        (line) => line.first == first && line.last == last,
      );
      if (matching.isNotEmpty) {
        _claimedSheikhLines[matching.first.join('-')] = ownerId;
      }
    }

    setState(() {
      _turnIndex = (state['turnIndex'] as num?)?.toInt() ?? 0;
      _scores
        ..clear()
        ..addAll(parsedScores);
    });
  }

  void _handleTap(TapDownDetails details, BoxConstraints constraints) {
    if (_turnId != _myId) return;

    final side = math.min(constraints.maxWidth, constraints.maxHeight);
    if (side <= 0) return;
    final scale = side / 700;
    final point = details.localPosition / scale;

    if (widget.kind == LineGameKind.sheikhBeard) {
      var bestIndex = -1;
      var bestDistance = double.infinity;
      for (var index = 0; index < _points.length; index++) {
        if (_pointOwners[index] >= 0) continue;
        final distance = (_points[index] - point).distanceSquared;
        if (distance < bestDistance) {
          bestDistance = distance;
          bestIndex = index;
        }
      }
      if (bestDistance < 1000) _requestMove(bestIndex);
      return;
    }

    var bestIndex = -1;
    var bestDistance = double.infinity;
    for (var index = 0; index < _edges.length; index++) {
      if (_edgeOwners[index] != null) continue;
      final start = _points[_edges[index][0]];
      final end = _points[_edges[index][1]];
      final vector = end - start;
      final denominator = vector.distanceSquared;
      if (denominator == 0) continue;
      final rawT =
          ((point - start).dx * vector.dx + (point - start).dy * vector.dy) /
              denominator;
      final t = rawT.clamp(0.0, 1.0).toDouble();
      final nearest = start + vector * t;
      final distance = (point - nearest).distanceSquared;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = index;
      }
    }
    if (bestDistance < 650) _requestMove(bestIndex);
  }

  @override
  void dispose() {
    _networkSubscription?.cancel();
    _webPlayersSubscription?.cancel();
    _webEventsSubscription?.cancel();
    _bridge?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.kind == LineGameKind.sheikhBeard ? 'لحية الشيخ' : 'المربعات';
    final players = _players;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: <Widget>[
          if (_isHost && _webUrl.isNotEmpty)
            Card(
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: <Widget>[
                    if (_webUrl.startsWith('http'))
                      QrImageView(
                        data: _webUrl,
                        size: 90,
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SelectableText(
                        '$_webUrl\nافتحه من Safari على نفس الشبكة',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: <Widget>[
                for (var index = 0; index < players.length; index++)
                  Chip(
                    avatar: CircleAvatar(
                      backgroundColor: _colors[index % _colors.length],
                    ),
                    label: Text(
                      '${players[index]['name']}: '
                      '${_scores[players[index]['id']] ?? 0}',
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final side =
                    math.min(constraints.maxWidth, constraints.maxHeight);
                return Center(
                  child: GestureDetector(
                    onTapDown: (details) => _handleTap(details, constraints),
                    child: CustomPaint(
                      size: Size.square(side),
                      painter: _LinePainter(
                        points: _points,
                        pointOwners: _pointOwners,
                        edges: _edges,
                        edgeOwners: _edgeOwners,
                        boxes: _boxes,
                        boxOwners: _boxOwners,
                        sheikhLines: _claimedSheikhLines,
                        players: players,
                        colors: _colors,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Text(
              players.length < 2
                  ? 'بانتظار لاعب آخر'
                  : _turnId == _myId
                      ? 'دورك الآن'
                      : 'بانتظار دور اللاعب الآخر',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  const _LinePainter({
    required this.points,
    required this.pointOwners,
    required this.edges,
    required this.edgeOwners,
    required this.boxes,
    required this.boxOwners,
    required this.sheikhLines,
    required this.players,
    required this.colors,
  });

  final List<Offset> points;
  final List<int> pointOwners;
  final List<List<int>> edges;
  final List<String?> edgeOwners;
  final List<List<int>> boxes;
  final List<String?> boxOwners;
  final Map<String, String> sheikhLines;
  final List<Map<String, String>> players;
  final List<Color> colors;

  Color? _playerColor(String? playerId) {
    if (playerId == null) return null;
    final index = players.indexWhere((player) => player['id'] == playerId);
    if (index < 0) return null;
    return colors[index % colors.length];
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final scale = size.width / 700;
    canvas.scale(scale);

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var index = 0; index < boxes.length; index++) {
      final ownerColor = _playerColor(boxOwners[index]);
      if (ownerColor == null) continue;
      final box = boxes[index];
      final topLeft = points[box[0]];
      final bottomRight = points[box[3]];
      paint
        ..style = PaintingStyle.fill
        ..color = ownerColor.withOpacity(0.22);
      canvas.drawRect(
        Rect.fromLTRB(
          topLeft.dx + 8,
          topLeft.dy + 8,
          bottomRight.dx - 8,
          bottomRight.dy - 8,
        ),
        paint,
      );
    }

    for (var index = 0; index < edges.length; index++) {
      final ownerColor = _playerColor(edgeOwners[index]);
      paint
        ..style = PaintingStyle.stroke
        ..color = ownerColor ?? Colors.black12
        ..strokeWidth = ownerColor == null ? 3 : 9;
      canvas.drawLine(
        points[edges[index][0]],
        points[edges[index][1]],
        paint,
      );
    }

    sheikhLines.forEach((key, ownerId) {
      final indexes = key.split('-').map(int.parse).toList();
      final ownerColor = _playerColor(ownerId);
      if (ownerColor == null || indexes.length < 2) return;
      paint
        ..style = PaintingStyle.stroke
        ..color = ownerColor
        ..strokeWidth = 10;
      canvas.drawLine(
        points[indexes.first],
        points[indexes.last],
        paint,
      );
    });

    for (var index = 0; index < points.length; index++) {
      final ownerIndex = pointOwners[index];
      paint
        ..style = PaintingStyle.fill
        ..color = ownerIndex >= 0 && ownerIndex < players.length
            ? colors[ownerIndex % colors.length]
            : Colors.white;
      canvas.drawCircle(points[index], 14, paint);

      paint
        ..style = PaintingStyle.stroke
        ..color = Colors.black54
        ..strokeWidth = 3;
      canvas.drawCircle(points[index], 14, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) => true;
}
