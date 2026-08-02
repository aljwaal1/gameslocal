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
  const LineGameScreen({super.key, required this.kind, this.networkCore});
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
  final LineGameKind kind;
  HttpServer? _server;
  final _players = <String, _WebPlayer>{};
  final _sockets = <String, WebSocket>{};
  final players = StreamController<List<_WebPlayer>>.broadcast();
  final events = StreamController<_WebEvent>.broadcast();

  Future<String> start() async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 40446, shared: true);
    _server!.listen(_request);
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
    for (final i in interfaces) {
      for (final a in i.addresses) {
        if (!a.address.startsWith('169.254.')) return 'http://${a.address}:40446';
      }
    }
    return 'http://0.0.0.0:40446';
  }

  Future<void> _request(HttpRequest r) async {
    if (r.uri.path == '/ws' && WebSocketTransformer.isUpgradeRequest(r)) {
      _socket(await WebSocketTransformer.upgrade(r));
      return;
    }
    r.response.headers.contentType = ContentType.html;
    r.response.write(_html(kind));
    await r.response.close();
  }

  void _socket(WebSocket s) {
    String? id;
    s.listen((raw) {
      try {
        final m = (jsonDecode(raw.toString()) as Map).map((k, v) => MapEntry(k.toString(), v));
        if (m['type'] == 'join') {
          id = 'web-${DateTime.now().microsecondsSinceEpoch}';
          final p = _WebPlayer(id!, (m['name'] ?? 'آيفون').toString());
          _players[id!] = p;
          _sockets[id!] = s;
          s.add(jsonEncode({'type': 'joined', 'id': id, 'name': p.name}));
          players.add(_players.values.toList());
        } else if (id != null) {
          events.add(_WebEvent(id!, (m['type'] ?? '').toString(), Map<String, dynamic>.from(m)));
        }
      } catch (_) {}
    }, onDone: () => _remove(id), onError: (_) => _remove(id));
  }

  void _remove(String? id) {
    if (id == null) return;
    _players.remove(id);
    _sockets.remove(id);
    players.add(_players.values.toList());
  }

  void broadcast(Map<String, dynamic> m) {
    final e = jsonEncode(m);
    for (final s in _sockets.values) {
      try { s.add(e); } catch (_) {}
    }
  }

  Future<void> dispose() async {
    for (final s in _sockets.values) { await s.close(); }
    await _server?.close(force: true);
    await players.close();
    await events.close();
  }

  static String _html(LineGameKind kind) {
    final title = kind == LineGameKind.sheikhBeard ? 'لحية الشيخ' : 'المربعات';
    final game = kind.name;
    return '''<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><title>$title</title><style>*{box-sizing:border-box}body{font-family:-apple-system,sans-serif;margin:0;background:#f6f3ff;color:#241a2e;padding:18px}.card{background:#fff;border-radius:22px;padding:16px;margin:10px 0;box-shadow:0 8px 25px #3b17601a}h1{text-align:center}input,button{width:100%;font-size:18px;padding:13px;border-radius:14px;margin:6px 0}input{border:1px solid #d8cdea}button{border:0;background:#6f2dbd;color:#fff;font-weight:800}.hidden{display:none}canvas{width:100%;aspect-ratio:1;background:white;border-radius:18px;touch-action:none}.scores{display:flex;gap:8px;flex-wrap:wrap}.pill{flex:1;min-width:110px;background:#eee8ff;border-radius:14px;padding:10px;text-align:center}</style></head><body><section id="join" class="card"><h1>$title</h1><input id="name" placeholder="اسم اللاعب"><button id="joinBtn">دخول</button></section><section id="game" class="hidden"><div class="card"><div id="status">بانتظار المضيف...</div><div id="scores" class="scores"></div></div><canvas id="board" width="700" height="700"></canvas></section><script>const kind='$game';let ws,id,state={};const c=document.getElementById('board'),x=c.getContext('2d');document.getElementById('joinBtn').onclick=()=>{const n=document.getElementById('name').value.trim();if(!n)return;ws=new WebSocket(`ws://${location.host}/ws`);ws.onopen=()=>ws.send(JSON.stringify({type:'join',name:n}));ws.onmessage=e=>{const m=JSON.parse(e.data);if(m.type==='joined'){id=m.id;document.getElementById('join').classList.add('hidden');document.getElementById('game').classList.remove('hidden')}else if(m.type==='state'){state=m;draw()}}};c.addEventListener('pointerdown',e=>{if(!ws||!state.turnId||state.turnId!==id)return;const r=c.getBoundingClientRect(),px=(e.clientX-r.left)*700/r.width,py=(e.clientY-r.top)*700/r.height;if(kind==='sheikhBeard'){let best=-1,d=1e9;(state.points||[]).forEach((p,i)=>{const q=(p.x-px)**2+(p.y-py)**2;if(q<d){d=q;best=i}});if(best>=0&&d<900)ws.send(JSON.stringify({type:'move',index:best}))}else{let best=null,d=1e9;(state.edges||[]).forEach((ed,i)=>{if(ed.owner)return;const a=state.points[ed.a],b=state.points[ed.b],vx=b.x-a.x,vy=b.y-a.y,t=Math.max(0,Math.min(1,((px-a.x)*vx+(py-a.y)*vy)/(vx*vx+vy*vy))),q=(px-(a.x+t*vx))**2+(py-(a.y+t*vy))**2;if(q<d){d=q;best=i}});if(best!==null&&d<500)ws.send(JSON.stringify({type:'move',index:best}))}});function draw(){x.clearRect(0,0,700,700);document.getElementById('status').textContent=state.message||'';document.getElementById('scores').innerHTML=(state.players||[]).map(p=>`<div class="pill">${p.name}<br><b>${p.score||0}</b></div>`).join('');(state.lines||[]).forEach(l=>{const a=state.points[l.a],b=state.points[l.b];x.strokeStyle=l.color;x.lineWidth=9;x.beginPath();x.moveTo(a.x,a.y);x.lineTo(b.x,b.y);x.stroke()});(state.edges||[]).forEach(ed=>{const a=state.points[ed.a],b=state.points[ed.b];x.strokeStyle=ed.color||'#ddd';x.lineWidth=ed.owner?8:3;x.beginPath();x.moveTo(a.x,a.y);x.lineTo(b.x,b.y);x.stroke()});(state.points||[]).forEach(p=>{x.fillStyle=p.color||'#fff';x.strokeStyle='#382747';x.lineWidth=3;x.beginPath();x.arc(p.x,p.y,13,0,Math.PI*2);x.fill();x.stroke()})}</script></body></html>''';
  }
}

class _LineGameScreenState extends State<LineGameScreen> {
  static const colors = <Color>[Color(0xffe63946), Color(0xff277da1), Color(0xff2a9d8f), Color(0xfff4a261)];
  final points = <Offset>[];
  final owners = <int>[];
  final scores = <String, int>{};
  final claimedLines = <String, String>{};
  final edges = <List<int>>[];
  final edgeOwners = <String?>[];
  final boxes = <List<int>>[];
  final webPlayers = <_WebPlayer>[];
  StreamSubscription? netSub, webPlayerSub, webEventSub;
  _LineWebBridge? bridge;
  String url = '';
  int turn = 0;

  bool get host => widget.networkCore?.state.mode == LocalNetworkMode.host;
  List<Map<String, String>> get players {
    final out = <Map<String, String>>[];
    for (final p in widget.networkCore?.state.players ?? const <LocalPlayer>[]) { out.add({'id': p.id, 'name': p.name}); }
    for (final p in webPlayers) { out.add({'id': p.id, 'name': p.name}); }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _buildBoard();
    netSub = widget.networkCore?.messages.listen(_networkMessage);
    if (host) _startWeb();
  }

  void _buildBoard() {
    if (widget.kind == LineGameKind.sheikhBeard) {
      const rows = 7;
      for (var r = 0; r < rows; r++) {
        final count = r + 1;
        final y = 80.0 + r * 85;
        final start = 350.0 - (count - 1) * 43;
        for (var c = 0; c < count; c++) points.add(Offset(start + c * 86, y));
      }
      owners.addAll(List.filled(points.length, -1));
    } else {
      const n = 6;
      for (var r = 0; r < n; r++) for (var c = 0; c < n; c++) points.add(Offset(75 + c * 110, 75 + r * 110));
      owners.addAll(List.filled(points.length, -1));
      for (var r = 0; r < n; r++) for (var c = 0; c < n - 1; c++) edges.add([r*n+c, r*n+c+1]);
      for (var r = 0; r < n - 1; r++) for (var c = 0; c < n; c++) edges.add([r*n+c, (r+1)*n+c]);
      edgeOwners.addAll(List.filled(edges.length, null));
      for (var r=0;r<n-1;r++) for(var c=0;c<n-1;c++) boxes.add([r*n+c,r*n+c+1,(r+1)*n+c,(r+1)*n+c+1]);
    }
  }

  Future<void> _startWeb() async {
    bridge = _LineWebBridge(widget.kind);
    webPlayerSub = bridge!.players.stream.listen((p) { setState(() { webPlayers..clear()..addAll(p); for(final v in p) scores.putIfAbsent(v.id,()=>0); }); _broadcast(); });
    webEventSub = bridge!.events.stream.listen((e) { if(e.type=='move') _move(e.id, (e.data['index'] as num?)?.toInt() ?? -1); });
    url = await bridge!.start();
    if (mounted) setState(() {});
  }

  String get myId => widget.networkCore?.localPlayerId ?? 'local';
  String get turnId => players.isEmpty ? '' : players[turn % players.length]['id']!;

  void _networkMessage(NetworkMessage m) {
    if (m.type != NetworkMessageType.move) return;
    final a = m.payload['action'];
    if (a == 'line_move') _move(m.senderId, (m.payload['index'] as num).toInt(), send: false);
    if (a == 'line_state') _applyState(m.payload);
  }

  void _move(String id, int index, {bool send = true}) {
    if (!host && id == myId) return;
    if (id != turnId || index < 0) return;
    var bonus = false;
    if (widget.kind == LineGameKind.sheikhBeard) {
      if (index >= owners.length || owners[index] >= 0) return;
      final pi = players.indexWhere((p) => p['id'] == id);
      owners[index] = pi;
      final before = claimedLines.length;
      _detectSheikhLines(pi);
      final gained = claimedLines.length - before;
      if (gained > 0) { scores[id] = (scores[id] ?? 0) + gained; bonus = true; GameFeedback.win(); } else { GameFeedback.tap(); }
    } else {
      if (index >= edges.length || edgeOwners[index] != null) return;
      edgeOwners[index] = id;
      final gained = _completedBoxes(id);
      if (gained > 0) { scores[id] = (scores[id] ?? 0) + gained; bonus = true; GameFeedback.win(); } else { GameFeedback.move(); }
    }
    if (!bonus && players.isNotEmpty) turn = (turn + 1) % players.length;
    if (send && id == myId) widget.networkCore?.sendMove({'action':'line_move','index':index}, senderId: myId);
    _broadcast();
    setState(() {});
  }

  void _detectSheikhLines(int owner) {
    const rows = 7;
    final lines = <List<int>>[];
    var start=0;
    for(var r=0;r<rows;r++){ lines.add(List.generate(r+1,(i)=>start+i)); start+=r+1; }
    for(var c=0;c<rows;c++){ final l=<int>[]; var s=0; for(var r=0;r<rows;r++){ if(c<=r) l.add(s+c); s+=r+1; } if(l.length>=3) lines.add(l); }
    for(var d=0;d<rows;d++){ final l=<int>[]; var s=0; for(var r=0;r<rows;r++){ final c=r-d; if(c>=0) l.add(s+c); s+=r+1; } if(l.length>=3) lines.add(l); }
    for(final l in lines){ if(l.every((i)=>owners[i]==owner)){ final k=l.join('-'); claimedLines.putIfAbsent(k,()=>players[owner]['id']!); } }
  }

  int _completedBoxes(String id) {
    var gained=0;
    for(final b in boxes){
      final needed=<int>[];
      for(var i=0;i<edges.length;i++){ final e=edges[i]; if((e[0]==b[0]&&e[1]==b[1])||(e[0]==b[2]&&e[1]==b[3])||(e[0]==b[0]&&e[1]==b[2])||(e[0]==b[1]&&e[1]==b[3])) needed.add(i); }
      if(needed.length==4&&needed.every((i)=>edgeOwners[i]!=null)){ final key='b${b[0]}'; if(!claimedLines.containsKey(key)){claimedLines[key]=id;gained++;} }
    }
    return gained;
  }

  Map<String,dynamic> _state() {
    final ps=<Map<String,dynamic>>[];
    for(var i=0;i<players.length;i++){ final p=players[i]; ps.add({'id':p['id'],'name':p['name'],'score':scores[p['id']]??0,'color':'#${colors[i%4].value.toRadixString(16).substring(2)}'}); }
    final ls=<Map<String,dynamic>>[];
    claimedLines.forEach((k,v){ if(!k.startsWith('b')){ final a=k.split('-').map(int.parse).toList(); ls.add({'a':a.first,'b':a.last,'color':ps.firstWhere((p)=>p['id']==v)['color']}); }});
    return {'type':'state','kind':widget.kind.name,'turnId':turnId,'message':players.isEmpty?'بانتظار اللاعبين':'الدور: ${players[turn%players.length]['name']}','players':ps,'points':List.generate(points.length,(i)=>{'x':points[i].dx,'y':points[i].dy,'color':owners[i]<0?null:ps[owners[i]]['color']}),'lines':ls,'edges':List.generate(edges.length,(i)=>{'a':edges[i][0],'b':edges[i][1],'owner':edgeOwners.isEmpty?null:edgeOwners[i],'color':edgeOwners.isEmpty||edgeOwners[i]==null?null:ps.firstWhere((p)=>p['id']==edgeOwners[i])['color']})};
  }

  void _broadcast() {
    final s=_state(); bridge?.broadcast(s); if(host) widget.networkCore?.sendMove({'action':'line_state',...s},senderId:myId);
  }

  void _applyState(Map<String,dynamic> m) { setState(() {}); }

  @override
  void dispose() { netSub?.cancel(); webPlayerSub?.cancel(); webEventSub?.cancel(); bridge?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text(widget.kind==LineGameKind.sheikhBeard?'لحية الشيخ':'المربعات')),body: Column(children:[if(host&&url.isNotEmpty) Card(child:Padding(padding:const EdgeInsets.all(12),child:Row(children:[QrImageView(data:url,size:90),const SizedBox(width:12),Expanded(child:SelectableText('$url\nافتحه من Safari على نفس الشبكة'))]))),Padding(padding:const EdgeInsets.all(8),child:Wrap(spacing:8,children:[for(var i=0;i<players.length;i)Chip(avatar:CircleAvatar(backgroundColor:colors[i%4]),label:Text('${players[i]['name']}: ${scores[players[i]['id']]??0}'))])),Expanded(child:LayoutBuilder(builder:(context,c)=>GestureDetector(onTapDown:(d){if(turnId!=myId)return;final scale=math.min(c.maxWidth,c.maxHeight)/700, p=d.localPosition/scale;if(widget.kind==LineGameKind.sheikhBeard){var best=-1,dist=999999.0;for(var i=0;i<points.length;i++){final q=(points[i]-p).distanceSquared;if(q<dist){dist=q;best=i;}}if(dist<900)_move(myId,best);}else{var best=-1,dist=999999.0;for(var i=0;i<edges.length;i++){if(edgeOwners[i]!=null)continue;final a=points[edges[i][0]],b=points[edges[i][1]],ab=b-a,t=((p-a).dx*ab.dx+(p-a).dy*ab.dy)/ab.distanceSquared,t2=t.clamp(0.0,1.0),q=(p-(a+ab*t2)).distanceSquared;if(q<dist){dist=q;best=i;}}if(dist<500)_move(myId,best);}},child:CustomPaint(size:Size.square(math.min(c.maxWidth,c.maxHeight)),painter:_LinePainter(points,owners,edges,edgeOwners,claimedLines,players,colors))))]));
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.points,this.owners,this.edges,this.edgeOwners,this.lines,this.players,this.colors);
  final List<Offset> points; final List<int> owners; final List<List<int>> edges; final List<String?> edgeOwners; final Map<String,String> lines; final List<Map<String,String>> players; final List<Color> colors;
  @override void paint(Canvas canvas,Size size){ final s=size.width/700; canvas.scale(s); final p=Paint()..strokeCap=StrokeCap.round; for(var i=0;i<edges.length;i++){p.color=edgeOwners[i]==null?Colors.black12:colors[players.indexWhere((x)=>x['id']==edgeOwners[i])%4];p.strokeWidth=edgeOwners[i]==null?3:9;canvas.drawLine(points[edges[i][0]],points[edges[i][1]],p);} lines.forEach((k,v){if(k.startsWith('b'))return;final a=k.split('-').map(int.parse).toList();p.color=colors[players.indexWhere((x)=>x['id']==v)%4];p.strokeWidth=10;canvas.drawLine(points[a.first],points[a.last],p);}); for(var i=0;i<points.length;i++){p.style=PaintingStyle.fill;p.color=owners[i]<0?Colors.white:colors[owners[i]%4];canvas.drawCircle(points[i],14,p);p.style=PaintingStyle.stroke;p.color=Colors.black54;p.strokeWidth=3;canvas.drawCircle(points[i],14,p);} }
  @override bool shouldRepaint(covariant _LinePainter old)=>true;
}
