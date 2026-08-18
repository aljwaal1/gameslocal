from pathlib import Path
import re

# Native Name/Animal/Object: real shared sounds instead of SystemSound.
p = Path('lib/games/name_animal_object/name_animal_object_game.dart')
s = p.read_text(encoding='utf-8')
s = s.replace("import 'package:flutter/services.dart';\n", "")
s = re.sub(r"\n  void _sound\(\[SystemSoundType type = SystemSoundType.click\]\) \{.*?\n  \}\n", "\n", s, count=1, flags=re.S)
s = s.replace("    _sound();\n    setState(() => _stage = _Stage.waiting);", "    GameFeedback.tap();\n    setState(() => _stage = _Stage.waiting);", 1)
s = s.replace("    _sound(SystemSoundType.alert);\n  }\n\n  void _handleNetworkMessage", "    GameFeedback.move();\n  }\n\n  void _handleNetworkMessage", 1)
s = s.replace("    _sound(SystemSoundType.alert);\n    _timer = Timer.periodic", "    GameFeedback.move();\n    _timer = Timer.periodic", 1)
s = s.replace("    _sound();\n    _network?.sendMove", "    GameFeedback.tap();\n    _network?.sendMove", 1)
s = s.replace("    _sound(SystemSoundType.alert);", "    GameFeedback.win();", 1)
if '_sound(' in s or 'SystemSoundType' in s or 'SystemSound.play' in s:
    raise SystemExit('old name-game sound path remains')
p.write_text(s, encoding='utf-8')

# Four-player domino: remove both horizontal scrollers with flexible fixed layout.
p = Path('lib/games/domino/domino_four_player_game.dart')
s = p.read_text(encoding='utf-8')
if "../../core/audio_feedback.dart" not in s:
    s = s.replace("import 'package:flutter/material.dart';\n", "import 'package:flutter/material.dart';\n\nimport '../../core/audio_feedback.dart';\n", 1)
s = s.replace("      setState(() => message = 'هذه القطعة لا تناسب طرفي السلسلة');", "      GameFeedback.error();\n      setState(() => message = 'هذه القطعة لا تناسب طرفي السلسلة');", 1)
s = s.replace("        message = 'فاز اللاعب ${turns.currentPlayer + 1}!';", "        message = 'فاز اللاعب ${turns.currentPlayer + 1}!';\n        GameFeedback.win();", 1)
s = s.replace("      turns.next();\n      message = 'دور اللاعب ${turns.currentPlayer + 1}';", "      turns.next();\n      message = 'دور اللاعب ${turns.currentPlayer + 1}';\n      GameFeedback.move();", 1)
s = s.replace("      setState(() => message = 'لديك قطعة صالحة، لا يمكنك التمرير');", "      GameFeedback.error();\n      setState(() => message = 'لديك قطعة صالحة، لا يمكنك التمرير');", 1)
s = s.replace("      message = 'تم التمرير — دور اللاعب ${turns.currentPlayer + 1}';", "      message = 'تم التمرير — دور اللاعب ${turns.currentPlayer + 1}';\n      GameFeedback.tap();", 1)
pattern = re.compile(r'''\s*Expanded\(\s*child: SingleChildScrollView\(.*?\),\s*\),\s*const Divider\(\),\s*Text\(\s*gameFinished.*?\),\s*SizedBox\(\s*height: 96,\s*child: ListView\(.*?\),\s*\),''', re.S)
replacement = r'''
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: <Color>[Color(0xFF083D39), Color(0xFF0F766E)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(color: Color(0x330F172A), blurRadius: 14, offset: Offset(0, 6)),
                      ],
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: 390,
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            runAlignment: WrapAlignment.center,
                            spacing: 2,
                            runSpacing: 2,
                            children: <Widget>[
                              for (final tile in board) _tile(tile, false, compact: true),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                gameFinished ? 'انتهت اللعبة' : 'قطع اللاعب ${turns.currentPlayer + 1}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (final tile in hands[turns.currentPlayer])
                          _tile(tile, !gameFinished, compact: true),
                      ],
                    ),
                  ),
                ),
              ),'''
s, count = pattern.subn(replacement, s, count=1)
if count != 1:
    raise SystemExit(f'domino 4p scroll region matches={count}')
s = s.replace("  Widget _tile(_Tile tile, bool playable) => Padding(\n        padding: const EdgeInsets.all(4),", "  Widget _tile(_Tile tile, bool playable, {bool compact = false}) => Padding(\n        padding: EdgeInsets.all(compact ? 2 : 4),", 1)
s = s.replace("            width: 54,\n            height: 76,", "            width: compact ? 40 : 54,\n            height: compact ? 58 : 76,", 1)
s = s.replace("style: const TextStyle(fontSize: 22, color: Colors.black),", "style: TextStyle(fontSize: compact ? 16 : 22, color: const Color(0xFF0F172A), fontWeight: FontWeight.w900),", 2)
if 'SingleChildScrollView(' in s or 'ListView(' in s:
    raise SystemExit('domino 4p scroller remains')
p.write_text(s, encoding='utf-8')

# XO browser: fixed viewport + reusable WebAudio.
p = Path('lib/games/xo/xo_iphone_bridge.dart')
s = p.read_text(encoding='utf-8')
s = s.replace('*{box-sizing:border-box}body{margin:0;background:#f5f1ff;color:#251633;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;padding:18px}', '*{box-sizing:border-box}html,body{height:100%;overflow:hidden}body{margin:0;background:linear-gradient(145deg,#eef9f8,#f4efff);color:#0f172a;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;padding:10px;display:flex;align-items:center;justify-content:center}', 1)
s = s.replace('.card{background:#fff;border-radius:22px;padding:16px;margin:10px 0;box-shadow:0 10px 28px #3b176018}h1{text-align:center}', '.card{background:#fff;border-radius:22px;padding:12px;margin:6px 0;box-shadow:0 10px 28px #0f172a18}h1{text-align:center;margin:5px}', 1)
s = s.replace('button{border:0;background:#6f2dbd;color:#fff;font-weight:900}', 'button{border:0;background:linear-gradient(135deg,#0f766e,#6d28d9);color:#fff;font-weight:900}', 1)
s = s.replace('.hidden{display:none}.board{display:grid;grid-template-columns:repeat(3,1fr);gap:10px}.cell{aspect-ratio:1;border:0;border-radius:20px;background:#eee8ff;color:#6f2dbd;font-size:12vw;font-weight:900}', '.hidden{display:none}#join,#game{width:min(94vw,520px);max-height:96vh}.board{display:grid;grid-template-columns:repeat(3,1fr);gap:7px;width:min(72vh,90vw,430px);margin:auto}.cell{aspect-ratio:1;border:1px solid #0f172a12;border-radius:18px;background:linear-gradient(145deg,#fff,#edf7ff);color:#6d28d9;font-size:clamp(40px,12vw,68px);font-weight:900;box-shadow:0 5px 12px #0f172a14}', 1)
s = s.replace("let ws,id,state={};const board=document.getElementById('board');", "let ws,id,state={},prevFinished=false,ac=null;const board=document.getElementById('board');function audio(){try{ac=ac||new(window.AudioContext||window.webkitAudioContext)();if(ac.state==='suspended')ac.resume();return ac}catch(e){return null}}function tone(f=680,d=.07,g=.055,t='sine'){const a=audio();if(!a)return;const o=a.createOscillator(),v=a.createGain();o.type=t;o.frequency.value=f;v.gain.setValueAtTime(g,a.currentTime);v.gain.exponentialRampToValueAtTime(.001,a.currentTime+d);o.connect(v).connect(a.destination);o.start();o.stop(a.currentTime+d)}function sfx(k){if(k==='win'){tone(740,.08,.06);setTimeout(()=>tone(980,.13,.07),70)}else if(k==='move')tone(620,.055,.045,'triangle');else tone(440,.04,.03)}document.addEventListener('pointerdown',audio,{once:true});", 1)
s = s.replace("b.onclick=()=>{if(ws&&state.turnId===id&&!state.finished)ws.send(JSON.stringify({type:'move',index:i}));};", "b.onclick=()=>{if(ws&&state.turnId===id&&!state.finished){sfx('move');ws.send(JSON.stringify({type:'move',index:i}));}};", 1)
s = s.replace("document.getElementById('joinBtn').onclick=()=>{const name=", "document.getElementById('joinBtn').onclick=()=>{audio();tone(520,.05,.035);const name=", 1)
s = s.replace("function draw(){document.getElementById('status').textContent=state.message||'';", "function draw(){if(state.finished&&!prevFinished)sfx('win');prevFinished=!!state.finished;document.getElementById('status').textContent=state.message||'';", 1)
p.write_text(s, encoding='utf-8')

# Checkers browser: fixed viewport + move/capture/win sounds.
p = Path('lib/games/checkers/checkers_iphone_web.dart')
s = p.read_text(encoding='utf-8')
s = s.replace('*{box-sizing:border-box}body{margin:0;padding:14px;background:#101820;color:#fff;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}', '*{box-sizing:border-box}html,body{height:100%;overflow:hidden}body{margin:0;padding:8px;background:linear-gradient(145deg,#071a18,#172554);color:#fff;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}', 1)
s = s.replace('.card{background:#192734;border-radius:20px;padding:14px;margin-bottom:12px}', '.card{background:#102a34;border:1px solid #ffffff16;border-radius:18px;padding:9px;margin-bottom:7px}', 1)
s = s.replace('.board{display:grid;grid-template-columns:repeat(8,1fr);aspect-ratio:1;border:5px solid #6b4f2a;border-radius:10px;overflow:hidden}', '.board{display:grid;grid-template-columns:repeat(8,1fr);width:min(82vh,96vw,620px);aspect-ratio:1;border:5px solid #ffb703;border-radius:14px;overflow:hidden;margin:auto;box-shadow:0 12px 30px #0008}', 1)
s = s.replace("let ws,id,state={};const board=document.getElementById('board');", "let ws,id,state={},prevFinished=false,prevCount=32,ac=null;const board=document.getElementById('board');function audio(){try{ac=ac||new(window.AudioContext||window.webkitAudioContext)();if(ac.state==='suspended')ac.resume();return ac}catch(e){return null}}function tone(f=600,d=.06,g=.05){const a=audio();if(!a)return;const o=a.createOscillator(),v=a.createGain();o.frequency.value=f;v.gain.setValueAtTime(g,a.currentTime);v.gain.exponentialRampToValueAtTime(.001,a.currentTime+d);o.connect(v).connect(a.destination);o.start();o.stop(a.currentTime+d)}function sfx(k){if(k==='win'){tone(720,.08,.06);setTimeout(()=>tone(980,.14,.07),70)}else if(k==='capture'){tone(340,.08,.07);setTimeout(()=>tone(520,.08,.05),55)}else tone(620,.05,.04)}document.addEventListener('pointerdown',audio,{once:true});", 1)
s = s.replace("document.getElementById('joinBtn').onclick=()=>{const name=", "document.getElementById('joinBtn').onclick=()=>{audio();tone(500,.05,.035);const name=", 1)
s = s.replace("if(state.canPlay&&!state.finished)ws.send(JSON.stringify({type:'tap',row:r,col:c}))", "if(state.canPlay&&!state.finished){sfx('move');ws.send(JSON.stringify({type:'tap',row:r,col:c}))}", 1)
s = s.replace("function draw(){document.getElementById('status').textContent=state.message||'';", "function draw(){const count=(state.redCount||0)+(state.blackCount||0);if(count<prevCount)sfx('capture');if(state.finished&&!prevFinished)sfx('win');prevCount=count;prevFinished=!!state.finished;document.getElementById('status').textContent=state.message||'';", 1)
p.write_text(s, encoding='utf-8')

# Name browser: fixed viewport, non-scroll result table, reusable WebAudio context.
p = Path('lib/games/name_animal_object/iphone_web_bridge.dart')
s = p.read_text(encoding='utf-8')
s = s.replace(':root{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:#20152f;background:#f6f3ff}*{box-sizing:border-box}body{margin:0;padding:max(18px,env(safe-area-inset-top)) 14px 30px;min-height:100vh}', ':root{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:#0f172a;background:#f4f7fb}*{box-sizing:border-box}html,body{height:100%;overflow:hidden}body{margin:0;padding:max(8px,env(safe-area-inset-top)) 8px max(8px,env(safe-area-inset-bottom));height:100dvh}', 1)
s = s.replace('.card{background:#fff;border-radius:22px;padding:17px;margin:11px 0;box-shadow:0 10px 28px #3c17651a}.hero{background:linear-gradient(135deg,#6f2dbd,#148f77);color:#fff;text-align:center}.letter{font-size:72px;font-weight:900}', '.card{background:#fff;border-radius:18px;padding:10px;margin:6px 0;box-shadow:0 8px 22px #0f172a18}.hero{background:linear-gradient(135deg,#6d28d9,#0f766e);color:#fff;text-align:center}.letter{font-size:clamp(42px,9vh,68px);font-weight:900}', 1)
s = s.replace('.table-wrap{overflow:auto;border:1px solid #ddd3ef;border-radius:16px}table{border-collapse:collapse;min-width:720px;width:100%;background:#fff}', '.table-wrap{overflow:hidden;border:1px solid #ddd3ef;border-radius:16px;max-height:60vh}table{border-collapse:collapse;width:100%;background:#fff;font-size:clamp(7px,2vw,12px);table-layout:fixed}', 1)
s = s.replace('th,td{border:1px solid #ddd3ef;padding:11px;text-align:center;white-space:nowrap}', 'th,td{border:1px solid #ddd3ef;padding:4px 2px;text-align:center;white-space:normal;overflow:hidden;text-overflow:ellipsis}', 1)
s = s.replace('.hidden{display:none}.muted', '.hidden{display:none}#join,#wait,#play,#results{max-height:100%;overflow:hidden}#play,#results{height:100%;display:flex;flex-direction:column}#play.hidden,#results.hidden{display:none}#fields{flex:1;min-height:0;display:flex;flex-direction:column;justify-content:center}#fields input{padding:8px 10px;margin:2px 0 4px}.muted', 1)
s = s.replace("const cats=['اسم','حيوان','جماد','نبات','بلاد'];let ws,playerId,currentRound=0,timer,currentProposal='';\nconst beep=(f=650,d=.12)=>{try{const a=new(window.AudioContext||window.webkitAudioContext)(),o=a.createOscillator(),g=a.createGain();o.frequency.value=f;o.connect(g);g.connect(a.destination);g.gain.value=.08;o.start();o.stop(a.currentTime+d)}catch(e){}};", "const cats=['اسم','حيوان','جماد','نبات','بلاد'];let ws,playerId,currentRound=0,timer,currentProposal='',ac=null;function audio(){try{ac=ac||new(window.AudioContext||window.webkitAudioContext)();if(ac.state==='suspended')ac.resume();return ac}catch(e){return null}}const beep=(f=650,d=.12,gain=.07)=>{const a=audio();if(!a)return;const o=a.createOscillator(),g=a.createGain();o.frequency.value=f;o.connect(g);g.connect(a.destination);g.gain.setValueAtTime(gain,a.currentTime);g.gain.exponentialRampToValueAtTime(.001,a.currentTime+d);o.start();o.stop(a.currentTime+d)};document.addEventListener('pointerdown',audio,{once:true});", 1)
s = s.replace('function join(){const name=', 'function join(){audio();beep(520,.05,.035);const name=', 1)
p.write_text(s, encoding='utf-8')

# Strict native no-scroll contract.
active = [
 'lib/games/xo/xo_game.dart','lib/games/checkers/checkers_game.dart','lib/games/chess/chess_game.dart',
 'lib/games/cards/cards_game.dart','lib/games/domino/domino_game.dart','lib/games/domino/domino_four_player_game.dart',
 'lib/games/line_games/line_games.dart','lib/games/name_animal_object/name_animal_object_game.dart',
 'lib/games/football/photo_penalty_game_v3.dart']
for f in active:
    data = Path(f).read_text(encoding='utf-8')
    if 'SingleChildScrollView(' in data or 'ListView(' in data:
        raise SystemExit(f'scroller remains in {f}')
print('v2 final pass applied')
