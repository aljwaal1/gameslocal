from pathlib import Path
import re

# Restore offline / robot entry in the room screen even for games with browser QR.
p = Path('lib/core/game_room.dart')
s = p.read_text(encoding='utf-8')
old = """              if (!_supportsBrowserQr) ...<Widget>[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _openGame(useNetwork: false),
                  icon: const Icon(Icons.smart_toy_rounded),
                  label: const Text('اللعب بدون شبكة'),
                ),
              ],"""
new = """              if (!_isNameGame) ...<Widget>[
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFF0F766E), Color(0xFF6D28D9)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(color: Color(0x260F172A), blurRadius: 14, offset: Offset(0, 6)),
                    ],
                  ),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: () => _openGame(useNetwork: false),
                    icon: const Icon(Icons.smart_toy_rounded),
                    label: const Text(
                      'اللعب مع الروبوت / محليًا',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],"""
if old not in s:
    raise SystemExit('game_room offline block not found')
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')

# Enlarge every native QR used by active games. Keep it responsive so it does
# not overflow narrow phones.
qr_files = [
    Path('lib/games/xo/xo_game.dart'),
    Path('lib/games/checkers/checkers_game.dart'),
    Path('lib/games/line_games/line_games.dart'),
    Path('lib/games/name_animal_object/name_animal_object_game.dart'),
]
for path in qr_files:
    text = path.read_text(encoding='utf-8')
    before = text
    # Most dialogs were 190/200/220 px. Use screen-relative size instead.
    text = re.sub(
        r"size:\s*(?:180|190|200|210|220|230|240)(?:\.0)?,",
        "size: (MediaQuery.sizeOf(context).shortestSide * .80).clamp(280.0, 360.0).toDouble(),",
        text,
    )
    if text == before:
        print(f'NOTE: no fixed QR size replaced in {path}')
    path.write_text(text, encoding='utf-8')

# Football: cover the flat lower area with a coherent pitch treatment and make
# the ball less oversized relative to the goal.
p = Path('lib/games/football/photo_penalty_game_v3.dart')
s = p.read_text(encoding='utf-8')
needle = """                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                Color(0x33000000),
                                Colors.transparent,
                                Color(0xB0000000),
                              ],
                              stops: <double>[0, .55, 1],
                            ),
                          ),
                        ),"""
replacement = """                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                Color(0x44000000),
                                Color(0x16000000),
                                Color(0xCC0A3B2E),
                                Color(0xFF075E42),
                              ],
                              stops: <double>[0, .43, .64, 1],
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(painter: _PitchPerspectivePainter()),
                          ),
                        ),"""
if needle not in s:
    raise SystemExit('football backdrop block not found')
s = s.replace(needle, replacement, 1)
s = s.replace("left: ballStart.dx - 31,\n                            top: ballStart.dy - 31,\n                            child: const _PenaltySpotBall(),",
              "left: ballStart.dx - 23,\n                            top: ballStart.dy - 23,\n                            child: const _PenaltySpotBall(),", 1)
s = s.replace("width: 62,\n      height: 62,", "width: 46,\n      height: 46,", 1)
s = s.replace("width: 32,\n      height: 32,", "width: 28,\n      height: 28,", 1)
s = s.replace("child: const Icon(Icons.sports_soccer, size: 24", "child: const Icon(Icons.sports_soccer, size: 21", 1)
# Append a perspective field painter once.
marker = "class _GoalGridPainter extends CustomPainter {"
if marker not in s:
    raise SystemExit('goal painter marker not found')
painter = r'''class _PitchPerspectivePainter extends CustomPainter {
  const _PitchPerspectivePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: .16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final glow = Paint()
      ..color = const Color(0xFF2DD4BF).withValues(alpha: .08)
      ..style = PaintingStyle.fill;

    final horizon = size.height * .50;
    final bottom = size.height * 1.02;
    final center = size.width / 2;
    for (var i = -4; i <= 4; i++) {
      final xTop = center + i * size.width * .055;
      final xBottom = center + i * size.width * .19;
      canvas.drawLine(Offset(xTop, horizon), Offset(xBottom, bottom), line);
    }
    for (var i = 0; i < 5; i++) {
      final t = i / 4;
      final y = horizon + (bottom - horizon) * (t * t);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center, size.height * .78), width: size.width * .42, height: size.height * .13),
      glow,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

'''
s = s.replace(marker, painter + marker, 1)
p.write_text(s, encoding='utf-8')

print('Robot option restored, QR enlarged, football pitch refined.')
