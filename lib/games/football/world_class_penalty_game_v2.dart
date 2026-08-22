import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/audio_feedback.dart';
import '../../core/network/local_network_core.dart';
import 'elite_penalty_game_v2.dart' as legacy;

class ChampionsPenaltyGameScreen extends StatelessWidget {
  const ChampionsPenaltyGameScreen({super.key, this.networkCore});
  final LocalNetworkCore? networkCore;

  @override
  Widget build(BuildContext context) {
    if (networkCore != null) {
      return legacy.ChampionsPenaltyGameScreen(networkCore: networkCore);
    }
    return const _PenaltyShell(
      title: 'ركلات الأبطال',
      subtitle: 'CHAMPIONS NIGHT',
      championsMode: true,
    );
  }
}

class ProPenaltyShootoutGameScreen extends StatelessWidget {
  const ProPenaltyShootoutGameScreen({super.key, this.networkCore});
  final LocalNetworkCore? networkCore;

  @override
  Widget build(BuildContext context) {
    if (networkCore != null) {
      return legacy.ProPenaltyShootoutGameScreen(networkCore: networkCore);
    }
    return const _PenaltyShell(
      title: 'ركلات الترجيح',
      subtitle: 'WORLD PENALTY ARENA',
      championsMode: false,
    );
  }
}

class _PenaltyShell extends StatefulWidget {
  const _PenaltyShell({
    required this.title,
    required this.subtitle,
    required this.championsMode,
  });

  final String title;
  final String subtitle;
  final bool championsMode;

  @override
  State<_PenaltyShell> createState() => _PenaltyShellState();
}

class _PenaltyShellState extends State<_PenaltyShell> {
  late CinematicPenaltyGame _game;
  Offset? _dragStart;
  Offset? _dragNow;

  @override
  void initState() {
    super.initState();
    _game = CinematicPenaltyGame(championsMode: widget.championsMode);
  }

  @override
  void dispose() {
    _game.hud.dispose();
    super.dispose();
  }

  void _restart() {
    setState(() {
      _game.hud.dispose();
      _game = CinematicPenaltyGame(championsMode: widget.championsMode);
      _dragStart = null;
      _dragNow = null;
    });
  }

  Offset _aimFromPoint(Offset point, Size size) {
    final left = size.width * .15;
    final right = size.width * .85;
    final top = size.height * .12;
    final bottom = size.height * .46;
    return Offset(
      ((point.dx - left) / (right - left)).clamp(.02, .98).toDouble(),
      ((point.dy - top) / (bottom - top)).clamp(.03, .97).toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF03080E),
      appBar: AppBar(
        toolbarHeight: 64,
        elevation: 0,
        backgroundColor: const Color(0xFF050D16),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
            ),
            Text(
              widget.subtitle,
              style: const TextStyle(
                color: Color(0xFF6DD5FA),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.8,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(onPressed: _restart, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            ValueListenableBuilder<PenaltyHud>(
              valueListenable: _game.hud,
              builder: (context, hud, _) => _ScoreBar(hud: hud),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.biggest;
                  return Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (details) {
                          if (!_game.canShoot) return;
                          _dragStart = details.localPosition;
                          _dragNow = details.localPosition;
                          _game.preview(_aimFromPoint(details.localPosition, size), .55, 0);
                        },
                        onPanUpdate: (details) {
                          if (_dragStart == null || !_game.canShoot) return;
                          _dragNow = details.localPosition;
                          final delta = _dragNow! - _dragStart!;
                          final power = (.52 + delta.distance / (size.height * .38))
                              .clamp(.52, 1.0)
                              .toDouble();
                          final curve = (delta.dx / size.width * 1.65)
                              .clamp(-.45, .45)
                              .toDouble();
                          _game.preview(_aimFromPoint(_dragNow!, size), power, curve);
                        },
                        onPanEnd: (_) {
                          if (_dragStart == null || _dragNow == null || !_game.canShoot) {
                            _dragStart = null;
                            _dragNow = null;
                            return;
                          }
                          final delta = _dragNow! - _dragStart!;
                          final power = (.52 + delta.distance / (size.height * .38))
                              .clamp(.52, 1.0)
                              .toDouble();
                          final curve = (delta.dx / size.width * 1.65)
                              .clamp(-.45, .45)
                              .toDouble();
                          _game.shoot(
                            aim: _aimFromPoint(_dragNow!, size),
                            power: power,
                            curve: curve,
                          );
                          _dragStart = null;
                          _dragNow = null;
                        },
                        onTapDown: (details) {
                          if (!_game.canDive) return;
                          _game.chooseDive(_aimFromPoint(details.localPosition, size));
                        },
                        child: GameWidget<CinematicPenaltyGame>(game: _game),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 14,
                        child: ValueListenableBuilder<PenaltyHud>(
                          valueListenable: _game.hud,
                          builder: (context, hud, _) => _HintCard(hud: hud),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.hud});
  final PenaltyHud hud;

  @override
  Widget build(BuildContext context) {
    Widget side(String label, int goals, List<PenaltyOutcome> results, CrossAxisAlignment align) {
      return Expanded(
        child: Column(
          crossAxisAlignment: align,
          children: <Widget>[
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            Text(
              '$goals',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 29,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final item in results.take(7))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      item == PenaltyOutcome.goal
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      size: 13,
                      color: item == PenaltyOutcome.goal
                          ? const Color(0xFF47E58A)
                          : const Color(0xFFFF6B6B),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF050D16),
        border: Border(bottom: BorderSide(color: Color(0x1838BDF8))),
      ),
      child: Row(
        children: <Widget>[
          side('أنت', hud.playerGoals, hud.playerResults, CrossAxisAlignment.start),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x3556C8FF)),
              color: const Color(0xFF0B1723),
            ),
            child: Text(
              hud.suddenDeath ? 'SUDDEN DEATH' : 'PENALTIES',
              style: const TextStyle(
                color: Color(0xFF77D7FF),
                fontWeight: FontWeight.w900,
                fontSize: 9,
                letterSpacing: 1.5,
              ),
            ),
          ),
          side('الروبوت', hud.robotGoals, hud.robotResults, CrossAxisAlignment.end),
        ],
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.hud});
  final PenaltyHud hud;

  @override
  Widget build(BuildContext context) {
    final accent = hud.phase == PenaltyPhase.saving
        ? const Color(0xFFFFD166)
        : const Color(0xFF66D9FF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xD8071019),
        border: Border.all(color: accent.withAlpha(65)),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x77000000), blurRadius: 22, offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        children: <Widget>[
          Icon(
            hud.phase == PenaltyPhase.saving
                ? Icons.sports_handball_rounded
                : Icons.sports_soccer_rounded,
            color: accent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hud.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          if (hud.phase == PenaltyPhase.aiming)
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accent.withAlpha(90), width: 3),
                color: const Color(0xFF0E1D29),
              ),
              child: Text(
                '${(hud.power * 100).round()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum PenaltyPhase { aiming, flying, result, saving, finished }
enum PenaltyOutcome { goal, save, post, miss }

class PenaltyHud {
  const PenaltyHud({
    required this.phase,
    required this.message,
    required this.power,
    required this.playerGoals,
    required this.robotGoals,
    required this.playerResults,
    required this.robotResults,
    required this.suddenDeath,
  });

  final PenaltyPhase phase;
  final String message;
  final double power;
  final int playerGoals;
  final int robotGoals;
  final List<PenaltyOutcome> playerResults;
  final List<PenaltyOutcome> robotResults;
  final bool suddenDeath;
}

class CinematicPenaltyGame extends FlameGame {
  CinematicPenaltyGame({required this.championsMode})
      : hud = ValueNotifier<PenaltyHud>(
          const PenaltyHud(
            phase: PenaltyPhase.aiming,
            message: 'اسحب من الكرة نحو زاوية المرمى',
            power: .62,
            playerGoals: 0,
            robotGoals: 0,
            playerResults: <PenaltyOutcome>[],
            robotResults: <PenaltyOutcome>[],
            suddenDeath: false,
          ),
        );

  final bool championsMode;
  final ValueNotifier<PenaltyHud> hud;
  final math.Random _random = math.Random();
  ui.Image? _keeperReadyImage;
  ui.Image? _keeperDiveImage;
  ui.Image? _playerReadyImage;
  ui.Image? _playerRunImage;
  ui.Image? _playerKickImage;

  PenaltyPhase phase = PenaltyPhase.aiming;
  PenaltyOutcome outcome = PenaltyOutcome.goal;
  Offset aim = const Offset(.5, .28);
  Offset actualAim = const Offset(.5, .28);
  Offset keeperTarget = const Offset(.5, .58);
  Offset chosenDive = const Offset(.5, .58);
  double power = .62;
  double curve = 0;
  double flight = 0;
  double resultClock = 0;
  double ambient = 0;
  double shotDuration = .92;
  int playerGoals = 0;
  int robotGoals = 0;
  int playerShots = 0;
  int robotShots = 0;
  final List<PenaltyOutcome> playerResults = <PenaltyOutcome>[];
  final List<PenaltyOutcome> robotResults = <PenaltyOutcome>[];

  bool get canShoot => phase == PenaltyPhase.aiming;
  bool get canDive => phase == PenaltyPhase.saving;
  bool get suddenDeath => playerShots >= 5 && robotShots >= 5;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _keeperReadyImage =
        await _loadAssetImage('assets/football/keeper_pro_v2.png');
    _keeperDiveImage =
        await _loadAssetImage('assets/football/keeper_dive_pro_v2.png');
    _playerReadyImage =
        await _loadAssetImage('assets/football/player_ready_pro_v2.png');
    _playerRunImage =
        await _loadAssetImage('assets/football/player_run_pro_v2.png');
    _playerKickImage =
        await _loadAssetImage('assets/football/player_kick_pro_v2.png');
  }

  Future<ui.Image> _loadAssetImage(String path) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  void preview(Offset target, double newPower, double newCurve) {
    if (!canShoot) return;
    aim = target;
    power = newPower;
    curve = newCurve;
    _syncHud();
  }

  void shoot({required Offset aim, required double power, required double curve}) {
    if (!canShoot) return;
    this.aim = aim;
    this.power = power;
    this.curve = curve;

    final overPower = math.max(0.0, power - .92);
    final spread = .016 + overPower * .46;
    actualAim = Offset(
      (aim.dx + (_random.nextDouble() - .5) * spread + curve * .032)
          .clamp(-.08, 1.08)
          .toDouble(),
      (aim.dy + (_random.nextDouble() - .5) * spread * .76)
          .clamp(-.08, 1.08)
          .toDouble(),
    );

    final reads = _random.nextDouble() < ((championsMode ? .24 : .31) + (1 - power) * .16);
    keeperTarget = reads
        ? Offset(
            (actualAim.dx + (_random.nextDouble() - .5) * .10).clamp(.04, .96).toDouble(),
            (actualAim.dy + (_random.nextDouble() - .5) * .12).clamp(.08, .92).toDouble(),
          )
        : Offset(.10 + _random.nextDouble() * .80, .15 + _random.nextDouble() * .70);

    final distance = (actualAim - keeperTarget).distance;
    final outside = actualAim.dx < -.015 || actualAim.dx > 1.015 || actualAim.dy < -.035 || actualAim.dy > 1.03;
    final nearFrame = actualAim.dx < .024 || actualAim.dx > .976 || actualAim.dy < .024;
    if (outside) {
      outcome = PenaltyOutcome.miss;
    } else if (nearFrame && _random.nextDouble() < .17 + overPower * .62) {
      outcome = PenaltyOutcome.post;
    } else if (distance < (.17 - power * .035) && _random.nextDouble() < .78) {
      outcome = PenaltyOutcome.save;
    } else {
      outcome = PenaltyOutcome.goal;
    }

    shotDuration = (1.06 - power * .25).clamp(.76, .94).toDouble();
    flight = 0;
    phase = PenaltyPhase.flying;
    GameFeedback.kick(GameAudioTheme.football);
    HapticFeedback.lightImpact();
    _syncHud(message: power > .94 ? 'قذيفة قوية...' : 'تسديدة...');
  }

  void chooseDive(Offset dive) {
    if (!canDive) return;
    chosenDive = dive;
    keeperTarget = dive;

    final robotPower = .69 + _random.nextDouble() * .28;
    actualAim = Offset(.07 + _random.nextDouble() * .86, .07 + _random.nextDouble() * .82);
    aim = actualAim;
    power = robotPower;
    curve = (_random.nextDouble() - .5) * .42;
    final distance = (actualAim - chosenDive).distance;
    final risk = _random.nextDouble();

    if (risk < .03) {
      outcome = PenaltyOutcome.miss;
    } else if ((actualAim.dx < .06 || actualAim.dx > .94) && risk < .13) {
      outcome = PenaltyOutcome.post;
    } else if (distance < .13 || (distance < .22 && _random.nextDouble() < .64)) {
      outcome = PenaltyOutcome.save;
    } else {
      outcome = PenaltyOutcome.goal;
    }

    shotDuration = (1.04 - robotPower * .22).clamp(.78, .94).toDouble();
    flight = 0;
    phase = PenaltyPhase.flying;
    GameFeedback.kick(GameAudioTheme.football);
    HapticFeedback.mediumImpact();
    _syncHud(message: 'المنافس يسدد...');
  }

  @override
  void update(double dt) {
    super.update(dt);
    ambient += dt;
    if (phase == PenaltyPhase.flying) {
      flight += dt / shotDuration;
      if (flight >= 1) {
        flight = 1;
        _finishFlight();
      }
    } else if (phase == PenaltyPhase.result) {
      resultClock += dt;
      if (resultClock >= 1.15) _advanceTurn();
    }
  }

  void _finishFlight() {
    final robotWasShooting = robotShots < playerShots;
    if (robotWasShooting) {
      robotShots++;
      robotResults.add(outcome);
      if (outcome == PenaltyOutcome.goal) robotGoals++;
    } else {
      playerShots++;
      playerResults.add(outcome);
      if (outcome == PenaltyOutcome.goal) playerGoals++;
    }

    resultClock = 0;
    phase = PenaltyPhase.result;
    switch (outcome) {
      case PenaltyOutcome.goal:
        GameFeedback.goal(GameAudioTheme.football);
        HapticFeedback.heavyImpact();
        _syncHud(message: championsMode ? 'هــــدف عالمي!' : 'هــــدف!');
      case PenaltyOutcome.save:
        GameFeedback.save(GameAudioTheme.football);
        HapticFeedback.mediumImpact();
        _syncHud(message: 'تصـــدٍ مذهل!');
      case PenaltyOutcome.post:
        GameFeedback.post(GameAudioTheme.football);
        HapticFeedback.heavyImpact();
        _syncHud(message: 'في القائم!');
      case PenaltyOutcome.miss:
        GameFeedback.error(GameAudioTheme.football);
        HapticFeedback.mediumImpact();
        _syncHud(message: 'خارج المرمى!');
    }
  }

  void _advanceTurn() {
    if (_isFinished()) {
      phase = PenaltyPhase.finished;
      if (playerGoals > robotGoals) {
        GameFeedback.win(GameAudioTheme.football);
        _syncHud(message: '🏆 أنت البطل');
      } else {
        GameFeedback.lose(GameAudioTheme.football);
        _syncHud(message: 'انتهت المباراة — الروبوت يفوز');
      }
      return;
    }
    if (playerShots == robotShots) {
      phase = PenaltyPhase.aiming;
      aim = const Offset(.5, .28);
      actualAim = aim;
      keeperTarget = const Offset(.5, .58);
      power = .62;
      curve = 0;
      _syncHud(message: suddenDeath ? 'الحسم المفاجئ — دورك' : 'اسحب من الكرة نحو زاوية المرمى');
    } else {
      phase = PenaltyPhase.saving;
      keeperTarget = const Offset(.5, .58);
      chosenDive = keeperTarget;
      _syncHud(message: 'أنت الحارس — اختر جهة القفز');
    }
  }

  bool _isFinished() {
    if (playerShots < 5 || robotShots < 5) return false;
    if (playerShots != robotShots) return false;
    return playerGoals != robotGoals;
  }

  void _syncHud({String? message}) {
    final current = hud.value;
    hud.value = PenaltyHud(
      phase: phase,
      message: message ?? current.message,
      power: power,
      playerGoals: playerGoals,
      robotGoals: robotGoals,
      playerResults: List<PenaltyOutcome>.unmodifiable(playerResults),
      robotResults: List<PenaltyOutcome>.unmodifiable(robotResults),
      suddenDeath: suddenDeath,
    );
  }

  Rect _goalRect(double w, double h) => Rect.fromLTRB(w * .15, h * .14, w * .85, h * .43);

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    if (w <= 0 || h <= 0) return;

    final impact = phase == PenaltyPhase.result
        ? (1 - resultClock.clamp(0.0, 1.0))
        : 0.0;
    final shake = outcome == PenaltyOutcome.post ? impact * 4.2 : impact * 1.3;
    canvas.save();
    canvas.translate(math.sin(resultClock * 52) * shake, 0);
    _drawSkyAndStadium(canvas, w, h);
    _drawPitch(canvas, w, h);
    _drawGoal(canvas, w, h);
    _drawKeeper(canvas, w, h);
    _drawPlayer(canvas, w, h);
    _drawBall(canvas, w, h);
    _drawFx(canvas, w, h);
    canvas.restore();
    super.render(canvas);
  }

  void _drawSkyAndStadium(Canvas canvas, double w, double h) {
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF02060B), Color(0xFF071724), Color(0xFF0B2530)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), sky);

    final stand = Path()
      ..moveTo(0, h * .04)
      ..quadraticBezierTo(w * .5, h * .23, w, h * .04)
      ..lineTo(w, h * .35)
      ..quadraticBezierTo(w * .5, h * .26, 0, h * .35)
      ..close();
    canvas.drawPath(stand, Paint()..color = const Color(0xFF050A10));

    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 30; col++) {
        final x = (col + .5) / 30 * w;
        final y = h * (.075 + row * .025) + math.sin(col * .9 + row) * 2;
        final pulse = .5 + .5 * math.sin(ambient * 2.2 + col * .72 + row);
        final c = Color.lerp(
          const Color(0xFF0F5EA8),
          championsMode ? const Color(0xFFFFD166) : const Color(0xFF7EE7FF),
          pulse,
        )!;
        canvas.drawCircle(Offset(x, y), 1.1 + (row % 2) * .25, Paint()..color = c.withAlpha(180));
      }
    }

    final glow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white.withAlpha(210),
          const Color(0xFF6DD5FA).withAlpha(70),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(w * .5, h * .02), radius: w * .58));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * .34), glow);
  }

  void _drawPitch(Canvas canvas, double w, double h) {
    final pitch = Path()
      ..moveTo(w * .02, h)
      ..lineTo(w * .98, h)
      ..lineTo(w * .76, h * .43)
      ..lineTo(w * .24, h * .43)
      ..close();
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF126B44), Color(0xFF0F9C5C), Color(0xFF087044)],
      ).createShader(Rect.fromLTWH(0, h * .43, w, h * .57));
    canvas.drawPath(pitch, paint);

    for (var i = 0; i < 9; i++) {
      final t0 = i / 9;
      final t1 = (i + .5) / 9;
      final y0 = h * (.43 + .57 * t0);
      final y1 = h * (.43 + .57 * t1);
      final left0 = w * (.24 - .22 * t0);
      final right0 = w * (.76 + .22 * t0);
      final left1 = w * (.24 - .22 * t1);
      final right1 = w * (.76 + .22 * t1);
      final stripe = Path()
        ..moveTo(left0, y0)
        ..lineTo(right0, y0)
        ..lineTo(right1, y1)
        ..lineTo(left1, y1)
        ..close();
      canvas.drawPath(stripe, Paint()..color = const Color(0x0EFFFFFF));
    }

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..color = Colors.white.withAlpha(165);
    canvas.drawPath(pitch, line);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * .5, h * .78), width: w * .34, height: h * .12),
      line,
    );
    canvas.drawCircle(Offset(w * .5, h * .79), 2.4, Paint()..color = Colors.white.withAlpha(210));
  }

  void _drawGoal(Canvas canvas, double w, double h) {
    final goal = _goalRect(w, h);
    final depth = h * .055;
    final rearTop = goal.top + depth;
    final rearBottom = goal.bottom + depth * .74;
    final bulge = phase == PenaltyPhase.result && outcome == PenaltyOutcome.goal
        ? math.sin(math.min(1.0, resultClock * 3) * math.pi) * h * .018
        : 0.0;

    final net = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .72
      ..color = Colors.white.withAlpha(82);

    final rear = Rect.fromLTRB(goal.left + w * .025, rearTop, goal.right - w * .025, rearBottom + bulge);
    for (var i = 0; i <= 12; i++) {
      final xFront = goal.left + goal.width * i / 12;
      final xRear = rear.left + rear.width * i / 12;
      canvas.drawLine(Offset(xFront, goal.top), Offset(xRear, rear.top), net);
      canvas.drawLine(Offset(xRear, rear.top), Offset(xRear, rear.bottom), net);
    }
    for (var i = 0; i <= 7; i++) {
      final yFront = goal.top + goal.height * i / 7;
      final yRear = rear.top + rear.height * i / 7;
      canvas.drawLine(Offset(goal.left, yFront), Offset(rear.left, yRear), net);
      canvas.drawLine(Offset(rear.left, yRear), Offset(rear.right, yRear), net);
      canvas.drawLine(Offset(rear.right, yRear), Offset(goal.right, yFront), net);
    }

    final shadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = Colors.black.withAlpha(70);
    canvas.drawLine(Offset(goal.left + 4, goal.bottom + 7), Offset(goal.left + 4, goal.top + 7), shadow);
    canvas.drawLine(Offset(goal.left + 4, goal.top + 7), Offset(goal.right + 4, goal.top + 7), shadow);
    canvas.drawLine(Offset(goal.right + 4, goal.top + 7), Offset(goal.right + 4, goal.bottom + 7), shadow);

    final posts = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Colors.white, Color(0xFFBDEBFF), Colors.white],
      ).createShader(goal);
    final frame = Path()
      ..moveTo(goal.left, goal.bottom)
      ..lineTo(goal.left, goal.top)
      ..lineTo(goal.right, goal.top)
      ..lineTo(goal.right, goal.bottom);
    canvas.drawPath(frame, posts);
  }

  void _drawKeeper(Canvas canvas, double w, double h) {
    final readyImage = _keeperReadyImage;
    final diveImage = _keeperDiveImage;
    if (readyImage == null || diveImage == null) return;

    final goal = _goalRect(w, h);
    final reaction = phase == PenaltyPhase.flying
        ? ((flight - .16) / .58).clamp(0.0, 1.0).toDouble()
        : (phase == PenaltyPhase.result ? 1.0 : 0.0);
    final t = Curves.easeOutCubic.transform(reaction);
    final start = Offset(goal.center.dx, goal.top + goal.height * .67);
    final target = Offset(
      goal.left + keeperTarget.dx * goal.width,
      goal.top + keeperTarget.dy * goal.height,
    );
    final jump = math.sin(t * math.pi) * goal.height * .065;
    final pos = Offset.lerp(start, target, t)! - Offset(0, jump);
    final dir = keeperTarget.dx - .5;
    final reach = dir.abs();
    final lateralDive = (reach / .12).clamp(0.0, 1.0).toDouble();
    final diveBlend = Curves.easeInOut.transform(
          ((reaction - .12) / .42).clamp(0.0, 1.0).toDouble(),
        ) *
        lateralDive;
    final readyHeight = goal.height * .54;
    final readyWidth = readyHeight * .67;
    final diveWidth = goal.height * (1.02 + reach * .16);
    final diveHeight = diveWidth / 1.50;

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(dir * .07 * t);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, goal.height * .29),
        width: readyWidth * (1.18 + reach * t * 1.7),
        height: readyHeight * .10,
      ),
      Paint()
        ..color = Colors.black.withAlpha(100)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    final readySource = Rect.fromLTWH(
      0,
      0,
      readyImage.width.toDouble(),
      readyImage.height.toDouble(),
    );
    final readyDestination = Rect.fromCenter(
      center: Offset(0, -readyHeight * .10),
      width: readyWidth,
      height: readyHeight,
    );
    canvas.drawImageRect(
      readyImage,
      readySource,
      readyDestination,
      Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high
        ..color = Colors.white.withAlpha(((1 - diveBlend) * 255).round()),
    );

    canvas.save();
    if (dir < 0) canvas.scale(-1, 1);
    final diveSource = Rect.fromLTWH(
      0,
      0,
      diveImage.width.toDouble(),
      diveImage.height.toDouble(),
    );
    final diveDestination = Rect.fromCenter(
      center: Offset(0, -diveHeight * .05),
      width: diveWidth,
      height: diveHeight,
    );
    canvas.drawImageRect(
      diveImage,
      diveSource,
      diveDestination,
      Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high
        ..color = Colors.white.withAlpha((diveBlend * 255).round()),
    );
    canvas.restore();
    canvas.restore();
  }

  void _drawPlayer(Canvas canvas, double w, double h) {
    final readyImage = _playerReadyImage;
    final runImage = _playerRunImage;
    final kickImage = _playerKickImage;
    if (readyImage == null || runImage == null || kickImage == null) return;

    final active = phase == PenaltyPhase.flying || phase == PenaltyPhase.result;
    final approach = active
        ? Curves.easeOutCubic.transform((flight / .43).clamp(0.0, 1.0))
        : 0.0;
    final runBlend = active
        ? math.sin((flight / .48).clamp(0.0, 1.0) * math.pi)
        : 0.0;
    final kickBlend = active
        ? Curves.easeOutCubic.transform(
            ((flight - .27) / .28).clamp(0.0, 1.0).toDouble(),
          )
        : 0.0;
    final x = w * (.355 + approach * .105);
    final feetY = h * (.86 - approach * .043);
    final playerHeight = h * (.205 - approach * .018);
    final playerWidth = playerHeight * (2 / 3);

    canvas.save();
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x + playerWidth * .03, feetY + playerHeight * .018),
        width: playerWidth * .82,
        height: playerHeight * .075,
      ),
      Paint()
        ..color = Colors.black.withAlpha(105)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    void drawPose(ui.Image image, double opacity) {
      if (opacity <= 0) return;
      final destination = Rect.fromCenter(
        center: Offset(x, feetY - playerHeight * .5),
        width: playerWidth,
        height: playerHeight,
      );
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        destination,
        Paint()
          ..isAntiAlias = true
          ..filterQuality = FilterQuality.high
          ..color = Colors.white.withAlpha((opacity * 255).round()),
      );
    }

    drawPose(
      readyImage,
      (1 - math.max(runBlend, kickBlend)).clamp(0.0, 1.0).toDouble(),
    );
    drawPose(
      runImage,
      (runBlend * (1 - kickBlend)).clamp(0.0, 1.0).toDouble(),
    );
    drawPose(kickImage, kickBlend);
    canvas.restore();
  }

  void _drawBall(Canvas canvas, double w, double h) {
    final start = Offset(w * .5, h * .805);
    final goal = _goalRect(w, h);
    final target = Offset(goal.left + actualAim.dx * goal.width, goal.top + actualAim.dy * goal.height);
    var t = 0.0;
    if (phase == PenaltyPhase.flying) {
      t = Curves.easeInCubic.transform(flight.clamp(0.0, 1.0));
    } else if (phase == PenaltyPhase.result) {
      t = 1.0;
    }

    Offset ballPosition(double travel) {
      final bend = math.sin(travel * math.pi);
      final base = Offset.lerp(start, target, travel)!;
      return Offset(
        base.dx + bend * curve * w * .14,
        base.dy - bend * h * (.072 + power * .027),
      );
    }

    final pos = ballPosition(t);
    final radius = w * (.041 - t * .025);

    if (t > .03) {
      for (var i = 1; i <= 5; i++) {
        final tt = (t - i * .035).clamp(0.0, 1.0);
        final trailPos = ballPosition(tt);
        canvas.drawCircle(
          trailPos,
          radius * (.76 - i * .08),
          Paint()
            ..color = Colors.white.withAlpha(42 - i * 6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
    }

    canvas.drawOval(
      Rect.fromCenter(center: Offset(pos.dx + radius * .35, pos.dy + radius * 1.05), width: radius * 2.0, height: radius * .65),
      Paint()..color = Colors.black.withAlpha(90),
    );

    final sphere = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-.35, -.45),
        radius: .95,
        colors: const <Color>[Colors.white, Color(0xFFE6EDF3), Color(0xFF9AA7B3)],
      ).createShader(Rect.fromCircle(center: pos, radius: radius));
    canvas.drawCircle(pos, radius, sphere);

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(ambient * 4.6 + t * 13.5);
    final patch = Paint()..color = const Color(0xFF17212B);
    canvas.drawCircle(Offset(0, -radius * .15), radius * .24, patch);
    for (var i = 0; i < 5; i++) {
      final a = i * math.pi * 2 / 5;
      canvas.drawCircle(Offset(math.cos(a) * radius * .58, math.sin(a) * radius * .58), radius * .13, patch);
    }
    canvas.restore();

    if (canShoot) {
      final pulse = .5 + .5 * math.sin(ambient * 4.5);
      canvas.drawCircle(
        pos,
        radius * (1.65 + pulse * .22),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF6DD5FA).withAlpha((80 + pulse * 80).round()),
      );
    }
  }

  void _drawFx(Canvas canvas, double w, double h) {
    if (phase == PenaltyPhase.aiming) {
      final goal = _goalRect(w, h);
      final target = Offset(goal.left + aim.dx * goal.width, goal.top + aim.dy * goal.height);
      final pulse = .5 + .5 * math.sin(ambient * 5);
      canvas.drawCircle(
        target,
        11 + pulse * 5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF6DD5FA).withAlpha((110 + pulse * 80).round()),
      );
      canvas.drawCircle(target, 2.4, Paint()..color = const Color(0xFF9DEAFF));
    }

    if (phase == PenaltyPhase.result && outcome == PenaltyOutcome.goal) {
      final glow = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            (championsMode ? const Color(0xFFFFD166) : const Color(0xFF6DD5FA)).withAlpha(115),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(w * .5, h * .31), radius: w * .5));
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h * .62), glow);
    }
  }
}
