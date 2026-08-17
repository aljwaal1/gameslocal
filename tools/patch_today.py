from pathlib import Path
import re

p = Path('lib/games/line_games/line_games.dart')
s = p.read_text(encoding='utf-8')
old = '''      // A triangular board has three straight-line axes. Only real lines
      // of three or more points can score.
      for (var row = 0; row < rows; row++) {
        final line = List<int>.generate(
          row + 1,
          (index) => rowStarts[row] + index,
        );
        if (line.length >= 3) _sheikhLines.add(line);
      }

      // First diagonal direction.
      for (var column = 0; column < rows; column++) {
        final line = <int>[];
        for (var row = column; row < rows; row++) {
          line.add(rowStarts[row] + column);
        }
        if (line.length >= 3) _sheikhLines.add(line);
      }

      // Second diagonal direction (the previously missing cross axis).
      for (var diagonal = 0; diagonal < rows; diagonal++) {
        final line = <int>[];
        for (var row = diagonal; row < rows; row++) {
          final column = row - diagonal;
          line.add(rowStarts[row] + column);
        }
        if (line.length >= 3) _sheikhLines.add(line);
      }
'''
new = '''      // Every visible contiguous 3-point segment scores independently.
      // This covers horizontal and both diagonal/cross axes.
      void addTriples(List<int> axis) {
        if (axis.length < 3) return;
        for (var start = 0; start <= axis.length - 3; start++) {
          _sheikhLines.add(axis.sublist(start, start + 3));
        }
      }

      for (var row = 0; row < rows; row++) {
        addTriples(List<int>.generate(
          row + 1,
          (index) => rowStarts[row] + index,
        ));
      }

      for (var column = 0; column < rows; column++) {
        final axis = <int>[];
        for (var row = column; row < rows; row++) {
          axis.add(rowStarts[row] + column);
        }
        addTriples(axis);
      }

      for (var diagonal = 0; diagonal < rows; diagonal++) {
        final axis = <int>[];
        for (var row = diagonal; row < rows; row++) {
          axis.add(rowStarts[row] + (row - diagonal));
        }
        addTriples(axis);
      }
'''
if old not in s:
    raise SystemExit('Sheikh block not found')
s = s.replace(old, new, 1)
s = s.replace(
    '      _claimedSheikhLines[key] = playerId;\n      gained += line.length;',
    '      _claimedSheikhLines[key] = playerId;\n      gained++;',
    1,
)

js = "const ctx=canvas.getContext('2d');\n"
if js in s:
    s = s.replace(js, """const ctx=canvas.getContext('2d');
let audioCtx=null,lastScoreTotal=0;
function beep(freq=660,duration=.07,gain=.055){
  try{
    audioCtx=audioCtx||new (window.AudioContext||window.webkitAudioContext)();
    const o=audioCtx.createOscillator(),g=audioCtx.createGain();
    o.frequency.value=freq;g.gain.value=gain;o.connect(g);g.connect(audioCtx.destination);o.start();
    g.gain.exponentialRampToValueAtTime(.001,audioCtx.currentTime+duration);o.stop(audioCtx.currentTime+duration);
  }catch(e){}
}
""", 1)
move = "ws.send(JSON.stringify({type:'move',index:best}));"
for _ in range(2):
    i = s.find(move)
    if i < 0:
        break
    s = s[:i] + "beep(720,.055,.045);\n      " + s[i:]
    # protect the inserted occurrence from the next search
    s = s[:i+1] + s[i+1:].replace(move, '__SECOND_MOVE__', 1) if _ == 0 else s
if '__SECOND_MOVE__' in s:
    s = s.replace('__SECOND_MOVE__', move, 1)
score_anchor = "document.getElementById('scores').innerHTML=(state.players||[])"
if score_anchor in s:
    s = s.replace(score_anchor, """const scoreTotal=(state.players||[]).reduce((n,p)=>n+(p.score||0),0);
  if(scoreTotal>lastScoreTotal)beep(1040,.14,.075);
  lastScoreTotal=scoreTotal;
  """ + score_anchor, 1)
p.write_text(s, encoding='utf-8')

p = Path('lib/games/football/photo_penalty_game_v3.dart')
s = p.read_text(encoding='utf-8')
s = s.replace("import '../../core/network/local_network_core.dart';", "import '../../core/audio_feedback.dart';\nimport '../../core/network/local_network_core.dart';", 1)
s = s.replace('    HapticFeedback.lightImpact();\n    await _animateShot();', '    GameFeedback.kick();\n    await _animateShot();', 1)
s = s.replace('    HapticFeedback.mediumImpact();\n    await _animateShot();', '    GameFeedback.kick();\n    await _animateShot();', 1)

sound_switch = '''    switch (result) {
      case _PenaltyOutcome.goal:
        GameFeedback.goal();
        break;
      case _PenaltyOutcome.save:
        GameFeedback.save();
        break;
      case _PenaltyOutcome.post:
        GameFeedback.post();
        break;
      case _PenaltyOutcome.miss:
        GameFeedback.error();
        break;
    }
'''
for marker in [
    "      _message = _resultText(result);\n    });\n",
    "      _message = result == _PenaltyOutcome.save ? 'تصـــدٍ رائع!' : _resultText(result);\n    });\n",
]:
    if marker not in s:
        raise SystemExit('football result marker not found')
    s = s.replace(marker, marker + sound_switch, 1)

shooter = re.compile(r'''\n                        Positioned\(\n                          left: -size\.width \* \.08,\n                          bottom: size\.height \* \.05,\n                          width: size\.width \* \.64,\n                          height: size\.height \* \.54,\n                          child: Opacity\(.*?\n                        \),''', re.S)
s, n = shooter.subn('', s, count=1)
if n != 1:
    raise SystemExit('football shooter layer not found')
s = s.replace('                  final shooter = _playerIsShooting ? _playerTeam : _robotTeam;\n', '', 1)
s = re.sub(r'\n  FootballSpritePose _playerPose\(\) \{.*?\n  \}\n\n  FootballSpritePose _keeperPose', '\n  FootballSpritePose _keeperPose', s, count=1, flags=re.S)

keeper = '''                        Positioned(
                          left: keeperPos.dx - size.width * .26,'''
if keeper not in s:
    raise SystemExit('keeper anchor missing')
s = s.replace(keeper, '''                        if (_phase == _PenaltyPhase.aiming || _phase == _PenaltyPhase.saving)
                          Positioned(
                            left: ballStart.dx - 31,
                            top: ballStart.dy - 31,
                            child: const _PenaltySpotBall(),
                          ),
''' + keeper, 1)

old_ball = '''                        if (_phase == _PenaltyPhase.flying || _phase == _PenaltyPhase.result)
                          Positioned(
                            left: ball.dx - 16,
                            top: ball.dy - 16,
                            child: Transform.rotate(
                              angle: _shot.value * math.pi * 8,
                              child: const _PhotoBall(),
                            ),
                          ),'''
new_ball = '''                        if (_phase == _PenaltyPhase.flying || _phase == _PenaltyPhase.result)
                          Positioned(
                            left: ball.dx - (30 - flightT * 16),
                            top: ball.dy - (30 - flightT * 16),
                            child: Transform.scale(
                              scale: 1.85 - flightT * .85,
                              child: Transform.rotate(
                                angle: _shot.value * math.pi * 9,
                                child: const _PhotoBall(),
                              ),
                            ),
                          ),'''
if old_ball not in s:
    raise SystemExit('flying ball block missing')
s = s.replace(old_ball, new_ball, 1)

anchor = '\nclass _PhotoBall extends StatelessWidget {'
spot = '''
class _PenaltySpotBall extends StatelessWidget {
  const _PenaltySpotBall();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(color: Color(0xAA000000), blurRadius: 18, offset: Offset(5, 12)),
          BoxShadow(color: Color(0x5538BDF8), blurRadius: 24),
        ],
      ),
      child: const _PhotoBall(),
    );
  }
}
'''
if anchor not in s:
    raise SystemExit('photo ball anchor missing')
s = s.replace(anchor, spot + anchor, 1)

old_grid = '''    for (var i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(size.width * i / 3, 0),
        Offset(size.width * i / 3, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(0, size.height * i / 3),
        Offset(size.width, size.height * i / 3),
        paint,
      );
    }'''
new_grid = '''    for (var i = 1; i < 7; i++) {
      canvas.drawLine(Offset(size.width * i / 7, 0), Offset(size.width * i / 7, size.height), paint);
    }
    for (var i = 1; i < 5; i++) {
      canvas.drawLine(Offset(0, size.height * i / 5), Offset(size.width, size.height * i / 5), paint);
    }
    final frame = Paint()
      ..color = Colors.white.withAlpha(225)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(2)), frame);'''
if old_grid not in s:
    raise SystemExit('goal grid missing')
s = s.replace(old_grid, new_grid, 1)
if 'HapticFeedback.' not in s:
    s = s.replace("import 'package:flutter/services.dart';\n", '', 1)
p.write_text(s, encoding='utf-8')
