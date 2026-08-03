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
*{box-sizing:border-box}body{margin:0;background:#f5f1ff;color:#251633;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;padding:18px}
.card{background:#fff;border-radius:22px;padding:16px;margin:10px 0;box-shadow:0 10px 28px #3b176018}h1{text-align:center}
input,button{width:100%;font-size:18px;padding:14px;border-radius:14px;margin:6px 0}input{border:1px solid #d8cdea}button{border:0;background:#6f2dbd;color:#fff;font-weight:900}
.hidden{display:none}.board{display:grid;grid-template-columns:repeat(3,1fr);gap:10px}.cell{aspect-ratio:1;border:0;border-radius:20px;background:#eee8ff;color:#6f2dbd;font-size:12vw;font-weight:900}
.cell:disabled{opacity:1}.score{display:flex;gap:8px}.pill{flex:1;background:#f0ebfb;border-radius:14px;padding:10px;text-align:center}.status{text-align:center;font-weight:900;font-size:18px}
</style>
</head>
<body>
<section id="join" class="card"><h1>إكس أو</h1><input id="name" placeholder="اسم اللاعب"><button id="joinBtn">دخول اللعبة</button></section>
<section id="game" class="hidden"><div class="card"><div id="status" class="status">بانتظار المضيف...</div><div class="score"><div class="pill">X<br><b id="xScore">0</b></div><div class="pill">تعادل<br><b id="draws">0</b></div><div class="pill">O<br><b id="oScore">0</b></div></div></div><div class="card"><div id="board" class="board"></div><button id="reset">جولة جديدة</button></div></section>
<script>
let ws,id,state={};const board=document.getElementById('board');
for(let i=0;i<9;i++){const b=document.createElement('button');b.className='cell';b.dataset.i=i;b.onclick=()=>{if(ws&&state.turnId===id&&!state.finished)ws.send(JSON.stringify({type:'move',index:i}));};board.appendChild(b);}
document.getElementById('joinBtn').onclick=()=>{const name=document.getElementById('name').value.trim();if(!name)return;ws=new WebSocket(`ws://\${location.host}/ws`);ws.onopen=()=>ws.send(JSON.stringify({type:'join',name}));ws.onmessage=e=>{const m=JSON.parse(e.data);if(m.type==='joined'){id=m.id;document.getElementById('join').classList.add('hidden');document.getElementById('game').classList.remove('hidden');}else if(m.type==='state'){state=m;draw();}};};
document.getElementById('reset').onclick=()=>{if(ws)ws.send(JSON.stringify({type:'reset'}));};
function draw(){document.getElementById('status').textContent=state.message||'';document.getElementById('xScore').textContent=state.xWins||0;document.getElementById('oScore').textContent=state.oWins||0;document.getElementById('draws').textContent=state.draws||0;[...board.children].forEach((b,i)=>{b.textContent=(state.cells||[])[i]||'';b.disabled=!!b.textContent||state.turnId!==id||state.finished;});}
</script></body></html>''';
