import '../../core/iphone_game_bridge.dart';

IphoneGameBridge createXoIphoneBridge() {
  return IphoneGameBridge(
    port: 40449,
    html: _xoHtml,
  );
}

const String _xoHtml = '''<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>إكس أو</title>
<style>
*{box-sizing:border-box}html,body{height:100%;overflow:hidden}body{margin:0;background:linear-gradient(145deg,#eef9f8,#f4efff);color:#0f172a;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;padding:10px;display:flex;align-items:center;justify-content:center}
.card{background:#fff;border-radius:22px;padding:12px;margin:6px 0;box-shadow:0 10px 28px #0f172a18}h1{text-align:center;margin:5px}.hidden{display:none}#join,#game{width:min(94vw,520px);max-height:96vh}
input,button{width:100%;font-size:18px;padding:14px;border-radius:14px;margin:6px 0}input{border:1px solid #d8cdea}button{border:0;background:linear-gradient(135deg,#0f766e,#6d28d9);color:#fff;font-weight:900}
.board{display:grid;grid-template-columns:repeat(3,1fr);gap:7px;width:min(72vh,90vw,430px);margin:auto}.cell{aspect-ratio:1;border:1px solid #0f172a12;border-radius:18px;background:linear-gradient(145deg,#fff,#edf7ff);color:#6d28d9;font-size:clamp(40px,12vw,68px);font-weight:900;box-shadow:0 5px 12px #0f172a14}
.cell:disabled{opacity:1}.score{display:flex;gap:8px}.pill{flex:1;background:#f0ebfb;border-radius:14px;padding:10px;text-align:center}.status{text-align:center;font-weight:900;font-size:18px}
</style>
</head>
<body>
<section id="join" class="card"><h1>إكس أو</h1><input id="name" placeholder="اسم اللاعب"><button id="joinBtn">دخول اللعبة</button></section>
<section id="game" class="hidden"><div class="card"><div id="status" class="status">بانتظار المضيف...</div><div class="score"><div class="pill">X<br><b id="xScore">0</b></div><div class="pill">تعادل<br><b id="draws">0</b></div><div class="pill">O<br><b id="oScore">0</b></div></div></div><div class="card"><div id="board" class="board"></div><button id="reset">جولة جديدة</button></div></section>
<script>
let ws,id,state={},prevFinished=false,ac=null;const board=document.getElementById('board');function audio(){try{ac=ac||new(window.AudioContext||window.webkitAudioContext)();if(ac.state==='suspended')ac.resume();return ac}catch(e){return null}}function tone(f=680,d=.07,g=.055,t='sine'){const a=audio();if(!a)return;const o=a.createOscillator(),v=a.createGain();o.type=t;o.frequency.value=f;v.gain.setValueAtTime(g,a.currentTime);v.gain.exponentialRampToValueAtTime(.001,a.currentTime+d);o.connect(v).connect(a.destination);o.start();o.stop(a.currentTime+d)}function sfx(k){if(k==='win'){tone(740,.08,.06);setTimeout(()=>tone(980,.13,.07),70)}else if(k==='move')tone(620,.055,.045,'triangle');else tone(440,.04,.03)}document.addEventListener('pointerdown',audio,{once:true});
for(let i=0;i<9;i++){const b=document.createElement('button');b.className='cell';b.dataset.i=i;b.onclick=()=>{if(ws&&state.turnId===id&&!state.finished){sfx('move');ws.send(JSON.stringify({type:'move',index:i}));}};board.appendChild(b);}
document.getElementById('joinBtn').onclick=()=>{audio();tone(520,.05,.035);const name=document.getElementById('name').value.trim();if(!name)return;ws=new WebSocket(`ws://\${location.host}/ws`);ws.onopen=()=>ws.send(JSON.stringify({type:'join',name}));ws.onmessage=e=>{const m=JSON.parse(e.data);if(m.type==='joined'){id=m.id;document.getElementById('join').classList.add('hidden');document.getElementById('game').classList.remove('hidden');}else if(m.type==='state'){state=m;draw();}};};
document.getElementById('reset').onclick=()=>{if(ws)ws.send(JSON.stringify({type:'reset'}));};
function draw(){if(state.finished&&!prevFinished)sfx('win');prevFinished=!!state.finished;document.getElementById('status').textContent=state.message||'';document.getElementById('xScore').textContent=state.xWins||0;document.getElementById('oScore').textContent=state.oWins||0;document.getElementById('draws').textContent=state.draws||0;[...board.children].forEach((b,i)=>{b.textContent=(state.cells||[])[i]||'';b.disabled=!!b.textContent||state.turnId!==id||state.finished;});}
</script></body></html>''';
