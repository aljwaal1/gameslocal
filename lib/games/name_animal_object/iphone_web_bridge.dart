import 'dart:async';
import 'dart:convert';
import 'dart:io';

class IphoneWebPlayer {
  const IphoneWebPlayer({required this.id, required this.name});
  final String id;
  final String name;
}

class IphoneWebEvent {
  const IphoneWebEvent({
    required this.playerId,
    required this.playerName,
    required this.type,
    required this.data,
  });
  final String playerId;
  final String playerName;
  final String type;
  final Map<String, dynamic> data;
}

class IphoneWebBridge {
  static const int port = 40445;
  HttpServer? _server;
  final Map<String, WebSocket> _sockets = <String, WebSocket>{};
  final Map<String, IphoneWebPlayer> _players = <String, IphoneWebPlayer>{};
  final _playersController =
      StreamController<List<IphoneWebPlayer>>.broadcast();
  final _eventsController = StreamController<IphoneWebEvent>.broadcast();

  Stream<List<IphoneWebPlayer>> get players => _playersController.stream;
  Stream<IphoneWebEvent> get events => _eventsController.stream;

  Future<String> start() async {
    await stop();
    _server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      port,
      shared: true,
    );
    _server!.listen(_handleRequest);
    return 'http://${await _localAddress()}:$port';
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.uri.path == '/ws' &&
        WebSocketTransformer.isUpgradeRequest(request)) {
      _attachSocket(await WebSocketTransformer.upgrade(request));
      return;
    }
    if (request.uri.path == '/manifest.json') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object>{
          'name': 'اسم حيوان جماد',
          'short_name': 'حيوان جماد',
          'start_url': '/',
          'display': 'standalone',
          'background_color': '#f6f3ff',
          'theme_color': '#6f2dbd',
          'lang': 'ar',
          'dir': 'rtl',
        }),
      );
    } else {
      request.response.headers.contentType = ContentType.html;
      request.response.write(_html);
    }
    await request.response.close();
  }

  void _attachSocket(WebSocket socket) {
    String? playerId;
    socket.listen(
      (dynamic raw) {
        try {
          final dynamic decoded = jsonDecode(raw.toString());
          if (decoded is! Map) return;
          final Map<String, dynamic> msg = decoded.map(
            (dynamic k, dynamic v) => MapEntry(k.toString(), v),
          );
          final String type = (msg['type'] ?? '').toString();
          if (type == 'join') {
            final String name = (msg['name'] ?? '').toString().trim();
            playerId = 'web-${DateTime.now().microsecondsSinceEpoch}';
            final player = IphoneWebPlayer(
              id: playerId!,
              name: name.isEmpty ? 'لاعب آيفون' : name,
            );
            _players[player.id] = player;
            _sockets[player.id] = socket;
            socket.add(
              jsonEncode({
                'type': 'joined',
                'playerId': player.id,
                'name': player.name,
              }),
            );
            _emitPlayers();
            return;
          }
          if (playerId == null) return;
          _eventsController.add(
            IphoneWebEvent(
              playerId: playerId!,
              playerName: _players[playerId]?.name ?? 'لاعب آيفون',
              type: type,
              data: msg,
            ),
          );
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
    _emitPlayers();
  }

  void _emitPlayers() => _playersController.add(
        List<IphoneWebPlayer>.unmodifiable(_players.values),
      );

  void broadcast(Map<String, dynamic> message) {
    final String encoded = jsonEncode(message);
    for (final WebSocket socket in List<WebSocket>.from(_sockets.values)) {
      try {
        socket.add(encoded);
      } catch (_) {}
    }
  }

  Future<String> _localAddress() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback && !address.address.startsWith('169.254.'))
          return address.address;
      }
    }
    return '0.0.0.0';
  }

  Future<void> stop() async {
    for (final socket in _sockets.values) {
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
    await _eventsController.close();
  }

  static const String _html =
      r'''<!doctype html><html lang="ar" dir="rtl"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes"><meta name="theme-color" content="#6f2dbd"><link rel="manifest" href="/manifest.json">
<title>اسم حيوان جماد</title><style>
:root{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:#0f172a;background:#f4f7fb}*{box-sizing:border-box}html,body{height:100%;overflow:hidden}body{margin:0;padding:max(8px,env(safe-area-inset-top)) 8px max(8px,env(safe-area-inset-bottom));height:100dvh}.card{background:#fff;border-radius:18px;padding:10px;margin:6px 0;box-shadow:0 8px 22px #0f172a18}.hero{background:linear-gradient(135deg,#6d28d9,#0f766e);color:#fff;text-align:center}.letter{font-size:clamp(42px,9vh,68px);font-weight:900}.row{display:grid;grid-template-columns:repeat(3,1fr);gap:7px}.pill{padding:11px;border-radius:14px;background:#eee8ff;text-align:center;font-weight:800}input{width:100%;font-size:18px;padding:14px;border:1px solid #ddd3ef;border-radius:14px;margin:5px 0 9px}button{width:100%;border:0;border-radius:15px;padding:14px;font-size:17px;font-weight:900;background:#6f2dbd;color:white}.hidden{display:none}#join,#wait,#play,#results{max-height:100%;overflow:hidden}#play,#results{height:100%;display:flex;flex-direction:column}#play.hidden,#results.hidden{display:none}#fields{flex:1;min-height:0;display:flex;flex-direction:column;justify-content:center}#fields input{padding:8px 10px;margin:2px 0 4px}.muted{color:#746b7e;text-align:center}.table-wrap{overflow:hidden;border:1px solid #ddd3ef;border-radius:16px;max-height:60vh}table{border-collapse:collapse;width:100%;background:#fff;font-size:clamp(7px,2vw,12px);table-layout:fixed}th,td{border:1px solid #ddd3ef;padding:4px 2px;text-align:center;white-space:normal;overflow:hidden;text-overflow:ellipsis}th{background:#eee8ff;position:sticky;top:0}.score{font-weight:900;color:#148f77}.danger{background:#c62828}.vote{display:flex;gap:8px}.vote button{width:auto;flex:1}.ok{background:#148f77}
</style></head><body>
<section id="join" class="card hero"><h1>اسم • حيوان • جماد</h1><p>اكتب اسمك ثم ادخل الغرفة</p><input id="name" placeholder="اسم اللاعب"><button onclick="join()">دخول اللعبة</button></section>
<section id="wait" class="card hidden"><h2>تم الاتصال ✅</h2><p class="muted">بانتظار المضيف...</p></section>
<section id="play" class="hidden"><div class="card hero"><div id="letter" class="letter">؟</div><div class="row"><div class="pill">الجولة <span id="round">0</span></div><div class="pill">الوقت <span id="time">60</span></div><div class="pill">متصل</div></div></div><div class="card" id="fields"></div><button id="submit" onclick="submitAnswers()">إنهاء وتسليم للجميع</button></section>
<section id="results" class="hidden"><div class="card hero"><h2 id="resultTitle">النتائج</h2></div><div class="card table-wrap"><table id="resultsTable"></table></div><div class="card" id="ranking"></div><p class="muted">بانتظار الحرف التالي...</p></section>
<div id="proposal" class="card hidden"><h3>طلب تعديل نقاط</h3><p id="proposalText"></p><div class="vote"><button class="ok" onclick="vote(true)">موافقة</button><button class="danger" onclick="vote(false)">رفض</button></div></div>
<script>
const cats=['اسم','حيوان','جماد','نبات','بلاد'];let ws,playerId,currentRound=0,timer,currentProposal='',ac=null;function audio(){try{ac=ac||new(window.AudioContext||window.webkitAudioContext)();if(ac.state==='suspended')ac.resume();return ac}catch(e){return null}}const beep=(f=650,d=.12,gain=.07)=>{const a=audio();if(!a)return;const o=a.createOscillator(),g=a.createGain();o.frequency.value=f;o.connect(g);g.connect(a.destination);g.gain.setValueAtTime(gain,a.currentTime);g.gain.exponentialRampToValueAtTime(.001,a.currentTime+d);o.start();o.stop(a.currentTime+d)};document.addEventListener('pointerdown',audio,{once:true});
function show(id){['join','wait','play','results'].forEach(x=>document.getElementById(x).classList.toggle('hidden',x!==id))}
function join(){audio();beep(520,.05,.035);const name=document.getElementById('name').value.trim();if(!name)return;ws=new WebSocket(`ws://${location.host}/ws`);ws.onopen=()=>ws.send(JSON.stringify({type:'join',name}));ws.onmessage=e=>handle(JSON.parse(e.data));ws.onclose=()=>{alert('انقطع الاتصال بالمضيف');show('join')}}
function handle(m){if(m.type==='joined'){playerId=m.playerId;beep(800);show('wait')}if(m.type==='round_start'){currentRound=m.round;document.getElementById('round').textContent=m.round;document.getElementById('letter').textContent=m.letter;document.getElementById('fields').innerHTML=cats.map(c=>`<label>${c}</label><input data-cat="${c}" placeholder="${c} يبدأ بحرف ${m.letter}">`).join('');document.getElementById('submit').disabled=false;document.getElementById('submit').textContent='إنهاء وتسليم للجميع';startTimer(m.seconds||60);beep(900,.2);show('play')}if(m.type==='round_stop'){submitAnswers(false)}if(m.type==='results'){clearInterval(timer);beep(1100,.25);renderResults(m)}if(m.type==='score_proposal'){currentProposal=m.proposalId;document.getElementById('proposalText').textContent=`تعديل نقاط ${m.playerName} من ${m.oldPoints} إلى ${m.newPoints}`;document.getElementById('proposal').classList.remove('hidden');beep(500,.2)}if(m.type==='score_applied'){document.getElementById('proposal').classList.add('hidden');beep(1000,.2)}}
function renderResults(m){document.getElementById('resultTitle').textContent=`نتيجة حرف ${m.letter}`;const ids=Object.keys(m.names||{}),answers=m.answers||{},points=m.points||{};document.getElementById('resultsTable').innerHTML='<tr><th>اللاعب</th>'+cats.map(c=>`<th>${c}</th>`).join('')+'<th>نقاط الجولة</th><th>المجموع</th></tr>'+ids.map(id=>'<tr><th>'+((m.names||{})[id]||'لاعب')+'</th>'+cats.map(c=>`<td>${((answers[id]||{})[c]||'—')}</td>`).join('')+`<td class="score">${points[id]||0}</td><td class="score">${(m.scores||{})[id]||0}</td></tr>`).join('');const scores=m.scores||{};document.getElementById('ranking').innerHTML='<h3>الترتيب</h3>'+Object.keys(scores).sort((a,b)=>scores[b]-scores[a]).map((id,i)=>`<p>${i+1}. ${(m.names||{})[id]||'لاعب'} — <b>${scores[id]}</b></p>`).join('');show('results')}
function startTimer(s){clearInterval(timer);let n=s;document.getElementById('time').textContent=n;timer=setInterval(()=>{n--;document.getElementById('time').textContent=n;if(n<=0){clearInterval(timer);submitAnswers(true)}},1000)}
function submitAnswers(endAll=true){if(!ws||ws.readyState!==1||document.getElementById('submit').disabled)return;const answers={};document.querySelectorAll('[data-cat]').forEach(i=>answers[i.dataset.cat]=i.value.trim());ws.send(JSON.stringify({type:'submit',round:currentRound,answers,endAll}));document.getElementById('submit').disabled=true;document.getElementById('submit').textContent='تم التسليم';beep(720)}
function vote(approve){if(currentProposal&&ws&&ws.readyState===1)ws.send(JSON.stringify({type:'score_vote',proposalId:currentProposal,approve}));document.getElementById('proposal').classList.add('hidden')}
</script></body></html>''';
}
