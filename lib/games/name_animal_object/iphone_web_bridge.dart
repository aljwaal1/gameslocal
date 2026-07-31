import 'dart:async';
import 'dart:convert';
import 'dart:io';

class IphoneWebPlayer {
  const IphoneWebPlayer({required this.id, required this.name});
  final String id;
  final String name;
}

class IphoneWebSubmission {
  const IphoneWebSubmission({
    required this.playerId,
    required this.playerName,
    required this.round,
    required this.answers,
  });

  final String playerId;
  final String playerName;
  final int round;
  final Map<String, String> answers;
}

class IphoneWebBridge {
  static const int port = 40445;

  HttpServer? _server;
  final Map<String, WebSocket> _sockets = <String, WebSocket>{};
  final Map<String, IphoneWebPlayer> _players = <String, IphoneWebPlayer>{};
  final StreamController<List<IphoneWebPlayer>> _playersController =
      StreamController<List<IphoneWebPlayer>>.broadcast();
  final StreamController<IphoneWebSubmission> _submissionsController =
      StreamController<IphoneWebSubmission>.broadcast();

  Stream<List<IphoneWebPlayer>> get players => _playersController.stream;
  Stream<IphoneWebSubmission> get submissions => _submissionsController.stream;
  List<IphoneWebPlayer> get connectedPlayers =>
      List<IphoneWebPlayer>.unmodifiable(_players.values);

  Future<String> start() async {
    await stop();
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
    _server!.listen(_handleRequest);
    return 'http://${await _localAddress()}:$port';
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.uri.path == '/ws' && WebSocketTransformer.isUpgradeRequest(request)) {
      final WebSocket socket = await WebSocketTransformer.upgrade(request);
      _attachSocket(socket);
      return;
    }

    if (request.uri.path == '/manifest.json') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(<String, Object>{
        'name': 'اسم حيوان جماد',
        'short_name': 'حيوان جماد',
        'start_url': '/',
        'display': 'standalone',
        'background_color': '#f6f3ff',
        'theme_color': '#6f2dbd',
        'lang': 'ar',
        'dir': 'rtl',
      }));
      await request.response.close();
      return;
    }

    request.response.headers.contentType = ContentType.html;
    request.response.write(_html);
    await request.response.close();
  }

  void _attachSocket(WebSocket socket) {
    String? playerId;
    socket.listen((dynamic raw) {
      try {
        final Object? decoded = jsonDecode(raw.toString());
        if (decoded is! Map<String, dynamic>) return;
        final String type = (decoded['type'] ?? '').toString();
        if (type == 'join') {
          final String name = (decoded['name'] ?? '').toString().trim();
          playerId = 'web-${DateTime.now().microsecondsSinceEpoch}';
          final IphoneWebPlayer player = IphoneWebPlayer(
            id: playerId!,
            name: name.isEmpty ? 'لاعب آيفون' : name,
          );
          _players[player.id] = player;
          _sockets[player.id] = socket;
          socket.add(jsonEncode(<String, Object>{
            'type': 'joined',
            'playerId': player.id,
            'name': player.name,
          }));
          _emitPlayers();
        } else if (type == 'submit' && playerId != null) {
          final Map<dynamic, dynamic> rawAnswers =
              decoded['answers'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{};
          _submissionsController.add(IphoneWebSubmission(
            playerId: playerId!,
            playerName: _players[playerId]?.name ?? 'لاعب آيفون',
            round: (decoded['round'] as num?)?.toInt() ?? 0,
            answers: rawAnswers.map(
              (dynamic key, dynamic value) =>
                  MapEntry<String, String>(key.toString(), value.toString()),
            ),
          ));
        }
      } catch (_) {}
    }, onDone: () => _remove(playerId), onError: (_) => _remove(playerId));
  }

  void _remove(String? id) {
    if (id == null) return;
    _players.remove(id);
    _sockets.remove(id);
    _emitPlayers();
  }

  void _emitPlayers() {
    if (!_playersController.isClosed) {
      _playersController.add(connectedPlayers);
    }
  }

  void broadcast(Map<String, dynamic> message) {
    final String encoded = jsonEncode(message);
    for (final WebSocket socket in List<WebSocket>.from(_sockets.values)) {
      try {
        socket.add(encoded);
      } catch (_) {}
    }
  }

  Future<String> _localAddress() async {
    final List<NetworkInterface> interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    for (final NetworkInterface interface in interfaces) {
      for (final InternetAddress address in interface.addresses) {
        if (!address.isLoopback) return address.address;
      }
    }
    return '0.0.0.0';
  }

  Future<void> stop() async {
    for (final WebSocket socket in _sockets.values) {
      await socket.close();
    }
    _sockets.clear();
    _players.clear();
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> dispose() async {
    await stop();
    await _playersController.close();
    await _submissionsController.close();
  }

  static const String _html = r'''<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes"><meta name="apple-mobile-web-app-status-bar-style" content="default">
<meta name="theme-color" content="#6f2dbd"><link rel="manifest" href="/manifest.json">
<title>اسم حيوان جماد</title>
<style>
:root{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:#20152f;background:#f6f3ff}*{box-sizing:border-box}body{margin:0;padding:max(20px,env(safe-area-inset-top)) 16px 28px;min-height:100vh}.card{background:white;border-radius:24px;padding:18px;margin:12px 0;box-shadow:0 10px 30px #3c17651a}.hero{background:linear-gradient(135deg,#6f2dbd,#148f77);color:white;text-align:center}.letter{font-size:74px;font-weight:900}.row{display:grid;grid-template-columns:1fr 1fr 1fr;gap:8px}.pill{padding:12px;border-radius:16px;background:#eee8ff;text-align:center;font-weight:800}input{width:100%;font-size:18px;padding:15px;border:1px solid #ddd3ef;border-radius:16px;margin:6px 0 10px}button{width:100%;border:0;border-radius:16px;padding:15px;font-size:18px;font-weight:900;background:#6f2dbd;color:white}.hidden{display:none}.answer{padding:10px;border-bottom:1px solid #eee}.muted{color:#746b7e;text-align:center}</style>
</head><body>
<section id="join" class="card hero"><h1>اسم • حيوان • جماد</h1><p>اكتب اسمك ثم ادخل الغرفة</p><input id="name" placeholder="اسم اللاعب"><button onclick="join()">دخول اللعبة</button></section>
<section id="wait" class="card hidden"><h2>تم الاتصال ✅</h2><p class="muted">بانتظار المضيف لبدء الحرف...</p></section>
<section id="play" class="hidden"><div class="card hero"><div id="letter" class="letter">؟</div><div class="row"><div class="pill">الجولة <span id="round">0</span></div><div class="pill">الوقت <span id="time">60</span></div><div class="pill">متصل</div></div></div><div class="card" id="fields"></div><button id="submit" onclick="submitAnswers()">تسليم الإجابات</button></section>
<section id="results" class="hidden"><div class="card hero"><h2 id="resultTitle">النتائج</h2></div><div class="card" id="answerList"></div><div class="card" id="ranking"></div><p class="muted">بانتظار الحرف التالي...</p></section>
<script>
const cats=['اسم','حيوان','جماد','نبات','بلاد'];let ws,playerId,currentRound=0,timer;
function show(id){['join','wait','play','results'].forEach(x=>document.getElementById(x).classList.toggle('hidden',x!==id))}
function join(){const name=document.getElementById('name').value.trim();if(!name)return;ws=new WebSocket(`ws://${location.host}/ws`);ws.onopen=()=>ws.send(JSON.stringify({type:'join',name}));ws.onmessage=e=>handle(JSON.parse(e.data));ws.onclose=()=>{alert('انقطع الاتصال بالمضيف');show('join')}}
function handle(m){if(m.type==='joined'){playerId=m.playerId;show('wait')}if(m.type==='round_start'){currentRound=m.round;document.getElementById('round').textContent=m.round;document.getElementById('letter').textContent=m.letter;document.getElementById('fields').innerHTML=cats.map(c=>`<label>${c}</label><input data-cat="${c}" placeholder="${c} يبدأ بحرف ${m.letter}">`).join('');document.getElementById('submit').disabled=false;startTimer(m.seconds||60);show('play')}if(m.type==='results'){clearInterval(timer);document.getElementById('resultTitle').textContent=`نتيجة حرف ${m.letter}`;const answers=m.answers||{};document.getElementById('answerList').innerHTML=cats.map(c=>`<h3>${c}</h3>${Object.entries(answers).map(([id,a])=>`<div class="answer"><b>${(m.names||{})[id]||'لاعب'}:</b> ${(a||{})[c]||'—'}</div>`).join('')}`).join('');const scores=m.scores||{};document.getElementById('ranking').innerHTML='<h3>الترتيب</h3>'+Object.keys(scores).sort((a,b)=>scores[b]-scores[a]).map((id,i)=>`<div class="answer">${i+1}. ${(m.names||{})[id]||'لاعب'} — <b>${scores[id]}</b></div>`).join('');show('results')}}
function startTimer(s){clearInterval(timer);let n=s;document.getElementById('time').textContent=n;timer=setInterval(()=>{n--;document.getElementById('time').textContent=n;if(n<=0){clearInterval(timer);submitAnswers()}},1000)}
function submitAnswers(){if(!ws||ws.readyState!==1)return;const answers={};document.querySelectorAll('[data-cat]').forEach(i=>answers[i.dataset.cat]=i.value.trim());ws.send(JSON.stringify({type:'submit',round:currentRound,answers}));document.getElementById('submit').disabled=true;document.getElementById('submit').textContent='تم التسليم — بانتظار الآخرين'}
</script></body></html>''';
}
