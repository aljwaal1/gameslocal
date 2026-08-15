import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    return const _WorldPenaltyShell(
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
    return const _WorldPenaltyShell(
      title: 'ركلات الترجيح',
      subtitle: 'WORLD PENALTY ARENA',
      championsMode: false,
    );
  }
}

class _WorldPenaltyShell extends StatefulWidget {
  const _WorldPenaltyShell({
    required this.title,
    required this.subtitle,
    required this.championsMode,
  });

  final String title;
  final String subtitle;
  final bool championsMode;

  @override
  State<_WorldPenaltyShell> createState() => _WorldPenaltyShellState();
}

class _WorldPenaltyShellState extends State<_WorldPenaltyShell> {
  late WorldPenaltyFlameGame _game;
  Offset? _dragStart;
  Offset? _dragNow;

  @override
  void initState() {
    super.initState();
    _game = WorldPenaltyFlameGame(championsMode: widget.championsMode);
  }

  @override
  void dispose() {
    _game.hud.dispose();
    super.dispose();
  }

  void _restart() {
    setState(() {
      _game.hud.dispose();
      _game = WorldPenaltyFlameGame(championsMode: widget.championsMode);
      _dragStart = null;
      _dragNow = null;
    });
  }

  Offset _normalizedAim(Offset point, Size size) {
    final left = size.width * .14;
    final right = size.width * .86;
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
      backgroundColor: const Color(0xFF02070C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07111B),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(
              widget.subtitle,
              style: const TextStyle(
                fontSize: 9,
                letterSpacing: 2.2,
                color: Color(0xFF7DD3FC),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'مباراة جديدة',
            onPressed: _restart,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            ValueListenableBuilder<WorldPenaltyHud>(
              valueListenable: _game.hud,
              builder: (context, hud, _) => _ScoreHud(hud: hud),
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
                          _game.setPreview(
                            _normalizedAim(details.localPosition, size),
                            .48,
                            0,
                          );
                        },
                        onPanUpdate: (details) {
                          if (_dragStart == null || !_game.canShoot) return;
                          _dragNow = details.localPosition;
                          final delta = _dragNow! - _dragStart!;
                          final power = (.48 + delta.distance / (size.height * .42))
                              .clamp(.48, 1.0)
                              .toDouble();
                          final curve = (delta.dx / size.width * 2.1)
                              .clamp(-.52, .52)
                              .toDouble();
                          _game.setPreview(
                            _normalizedAim(_dragNow!, size),
                            power,
                            curve,
                          );
                        },
                        onPanEnd: (_) {
                          if (_dragStart == null || _dragNow == null || !_game.canShoot) {
                            _dragStart = null;
                            _dragNow = null;
                            return;
                          }
                          final delta = _dragNow! - _dragStart!;
                          final power = (.48 + delta.distance / (size.height * .42))
                              .clamp(.48, 1.0)
                              .toDouble();
                          final curve = (delta.dx / size.width * 2.1)
                              .clamp(-.52, .52)
                              .toDouble();
                          _game.shoot(
                            aim: _normalizedAim(_dragNow!, size),
                            power: power,
                            curve: curve,
                          );
                          _dragStart = null;
                          _dragNow = null;
                        },
                        onTapDown: (details) {
                          if (!_game.canDive) return;
                          _game.chooseDive(_normalizedAim(details.localPosition, size));
                        },
                        child: GameWidget<WorldPenaltyFlameGame>(game: _game),
                      ),
                      ValueListenableBuilder<WorldPenaltyHud>(
                        valueListenable: _game.hud,
                        builder: (context, hud, _) {
                          return Positioned(
                            left: 14,
                            right: 14,
                            bottom: 12,
                            child: _ActionPanel(hud: hud),
                          );
                        },
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

class _ScoreHud extends StatelessWidget {
  const _ScoreHud({required this.hud});

  final WorldPenaltyHud hud;

  @override
  Widget build(BuildContext context) {
    Widget attempts(List<WorldPenaltyOutcome> values) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final value in values.take(7))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Icon(
                value == WorldPenaltyOutcome.goal
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                size: 13,
                color: value == WorldPenaltyOutcome.goal
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFFF87171),
              ),
            ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF07111B),
        border: Border(bottom: BorderSide(color: Color(0x2238BDF8))),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('أنت', style: TextStyle(color: Colors.white70, fontSize: 11)),
                Text(
                  '${hud.playerGoals}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                attempts(hud.playerResults),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: const Color(0xFF0E2030),
              border: Border.all(color: const Color(0x4438BDF8)),
            ),
            child: Text(
              hud.suddenDeath ? 'SUDDEN DEATH' : 'PENALTIES',
              style: const TextStyle(
                color: Color(0xFF7DD3FC),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                const Text('الروبوت', style: TextStyle(color: Colors.white70, fontSize: 11)),
                Text(
                  '${hud.robotGoals}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                attempts(hud.robotResults),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({required this.hud});

  final WorldPenaltyHud hud;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
      decoration: BoxDecoration(
        color: const Color(0xE608121C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x3348C5FF)),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            hud.message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 7),
          if (hud.phase == WorldPenaltyPhase.aiming)
            Row(
              children: <Widget>[
                const Text('POWER', style: TextStyle(color: Colors.white54, fontSize: 9)),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: hud.power,
                      minHeight: 7,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        hud.power > .93
                            ? const Color(0xFFFB7185)
                            : const Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(hud.power * 100).round()}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          if (hud.phase == WorldPenaltyPhase.saving)
            const Text(
              'اضغط داخل المرمى في اللحظة المناسبة لتحديد جهة قفز الحارس',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFFDE68A), fontSize: 11),
            ),
        ],
      ),
    );
  }
}

enum WorldPenaltyPhase { aiming, flying, result, saving, finished }

enum WorldPenaltyOutcome { goal, save, post, miss }

class WorldPenaltyHud {
  const WorldPenaltyHud({
    required this.phase,
    required this.message,
    required this.power,
    required this.playerGoals,
    required this.robotGoals,
    required this.playerResults,
    required this.robotResults,
    required this.suddenDeath,
  });

  final WorldPenaltyPhase phase;
  final String message;
  final double power;
  final int playerGoals;
  final int robotGoals;
  final List<WorldPenaltyOutcome> playerResults;
  final List<WorldPenaltyOutcome> robotResults;
  final bool suddenDeath;
}

class WorldPenaltyFlameGame extends FlameGame {
  WorldPenaltyFlameGame({required this.championsMode})
      : hud = ValueNotifier<WorldPenaltyHud>(
          const WorldPenaltyHud(
            phase: WorldPenaltyPhase.aiming,
            message: 'اسحب من الكرة نحو زاوية المرمى',
            power: .62,
            playerGoals: 0,
            robotGoals: 0,
            playerResults: <WorldPenaltyOutcome>[],
            robotResults: <WorldPenaltyOutcome>[],
            suddenDeath: false,
          ),
        );

  final bool championsMode;
  final ValueNotifier<WorldPenaltyHud> hud;
  final math.Random _random = math.Random();

  WorldPenaltyPhase phase = WorldPenaltyPhase.aiming;
  WorldPenaltyOutcome outcome = WorldPenaltyOutcome.goal;
  Offset aim = const Offset(.5, .30);
  Offset actualAim = const Offset(.5, .30);
  Offset keeperTarget = const Offset(.5, .58);
  Offset chosenDive = const Offset(.5, .58);
  double power = .62;
  double curve = 0;
  double flight = 0;
  double resultClock = 0;
  double ambient = 0;
  double _shotDuration = 1.05;
  int playerGoals = 0;
  int robotGoals = 0;
  int playerShots = 0;
  int robotShots = 0;
  final List<WorldPenaltyOutcome> playerResults = <WorldPenaltyOutcome>[];
  final List<WorldPenaltyOutcome> robotResults = <WorldPenaltyOutcome>[];

  bool get canShoot => phase == WorldPenaltyPhase.aiming;
  bool get canDive => phase == WorldPenaltyPhase.saving;
  bool get suddenDeath => playerShots >= 5 && robotShots >= 5;

  void setPreview(Offset target, double newPower, double newCurve) {
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

    final overPower = math.max(0.0, power - .91);
    final weakPower = math.max(0.0, .64 - power);
    final spread = .018 + overPower * .46 + weakPower * .18;
    actualAim = Offset(
      (aim.dx + (_random.nextDouble() - .5) * spread + curve * .035)
          .clamp(-.07, 1.07)
          .toDouble(),
      (aim.dy + (_random.nextDouble() - .5) * spread * .78)
          .clamp(-.10, 1.10)
          .toDouble(),
    );

    final readChance = (championsMode ? .24 : .31) + (1 - power) * .18;
    final reads = _random.nextDouble() < readChance;
    keeperTarget = reads
        ? Offset(
            (actualAim.dx + (_random.nextDouble() - .5) * .10).clamp(.04, .96).toDouble(),
            (actualAim.dy + (_random.nextDouble() - .5) * .12).clamp(.08, .92).toDouble(),
          )
        : Offset(
            (.10 + _random.nextDouble() * .80),
            (.14 + _random.nextDouble() * .70),
          );

    final keeperDistance = (actualAim - keeperTarget).distance;
    final saveRadius = (.19 - power * .055).clamp(.11, .17).toDouble();
    final outside = actualAim.dx < -.015 ||
        actualAim.dx > 1.015 ||
        actualAim.dy < -.04 ||
        actualAim.dy > 1.025;
    final nearPostX = actualAim.dx < .025 || actualAim.dx > .975;
    final nearBar = actualAim.dy < .025;
    final postChance = (nearPostX || nearBar) ? (.16 + overPower * .75) : 0.0;

    if (outside) {
      outcome = WorldPenaltyOutcome.miss;
    } else if (_random.nextDouble() < postChance) {
      outcome = WorldPenaltyOutcome.post;
    } else if (keeperDistance < saveRadius && _random.nextDouble() < .78) {
      outcome = WorldPenaltyOutcome.save;
    } else {
      outcome = WorldPenaltyOutcome.goal;
    }

    _shotDuration = (1.18 - power * .32).clamp(.78, 1.05).toDouble();
    flight = 0;
    phase = WorldPenaltyPhase.flying;
    HapticFeedback.lightImpact();
    _syncHud(message: power > .94 ? 'قذيفة قوية...' : 'تسديدة...');
  }

  void chooseDive(Offset dive) {
    if (!canDive) return;
    chosenDive = dive;
    keeperTarget = dive;

    final robotPower = .68 + _random.nextDouble() * .29;
    final risk = _random.nextDouble();
    final robotAim = Offset(
      .07 + _random.nextDouble() * .86,
      .07 + _random.nextDouble() * .82,
    );
    actualAim = robotAim;
    aim = robotAim;
    power = robotPower;
    curve = (_random.nextDouble() - .5) * .55;

    final distance = (actualAim - chosenDive).distance;
    final excellentRead = distance < .13;
    final goodRead = distance < .22;
    final missChance = robotPower > .95 ? .075 : .025;
    final postChance = (robotAim.dx < .06 || robotAim.dx > .94) ? .11 : .025;

    if (risk < missChance) {
      outcome = WorldPenaltyOutcome.miss;
    } else if (risk < missChance + postChance) {
      outcome = WorldPenaltyOutcome.post;
    } else if (excellentRead || (goodRead && _random.nextDouble() < .66)) {
      outcome = WorldPenaltyOutcome.save;
    } else {
      outcome = WorldPenaltyOutcome.goal;
    }

    _shotDuration = (1.14 - robotPower * .28).clamp(.80, 1.04).toDouble();
    flight = 0;
    phase = WorldPenaltyPhase.flying;
    HapticFeedback.mediumImpact();
    _syncHud(message: 'المنافس يسدد...');
  }

  @override
  void update(double dt) {
    super.update(dt);
    ambient += dt;

    if (phase == WorldPenaltyPhase.flying) {
      flight += dt / _shotDuration;
      if (flight >= 1) {
        flight = 1;
        _finishFlight();
      }
    } else if (phase == WorldPenaltyPhase.result) {
      resultClock += dt;
      if (resultClock >= 1.15) {
        _advanceTurn();
      }
    }
  }

  void _finishFlight() {
    final robotWasShooting = robotShots < playerShots;
    if (robotWasShooting) {
      robotShots++;
      robotResults.add(outcome);
      if (outcome == WorldPenaltyOutcome.goal) robotGoals++;
    } else {
      playerShots++;
      playerResults.add(outcome);
      if (outcome == WorldPenaltyOutcome.goal) playerGoals++;
    }

    resultClock = 0;
    phase = WorldPenaltyPhase.result;
    switch (outcome) {
      case WorldPenaltyOutcome.goal:
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
        _syncHud(message: championsMode ? 'هــــدف عالمي!' : 'هــــدف!');
      case WorldPenaltyOutcome.save:
        HapticFeedback.mediumImpact();
        _syncHud(message: 'تصـــدٍ مذهل!');
      case WorldPenaltyOutcome.post:
        HapticFeedback.heavyImpact();
        _syncHud(message: 'في القائم!');
      case WorldPenaltyOutcome.miss:
        HapticFeedback.mediumImpact();
        _syncHud(message: 'خارج المرمى!');
    }
  }

  void _advanceTurn() {
    if (_isFinished()) {
      phase = WorldPenaltyPhase.finished;
      _syncHud(
        message: playerGoals > robotGoals
            ? '🏆 انتصار مستحق — أنت البطل'
            : 'انتهت المباراة — الروبوت يفوز',
      );
      return;
    }

    if (playerShots == robotShots) {
      phase = WorldPenaltyPhase.aiming;
      aim = const Offset(.5, .30);
      actualAim = aim;
      keeperTarget = const Offset(.5, .58);
      power = .62;
      curve = 0;
      _syncHud(message: suddenDeath ? 'الحسم المفاجئ — دورك للتسديد' : 'اسحب من الكرة نحو زاوية المرمى');
    } else {
      phase = WorldPenaltyPhase.saving;
      chosenDive = const Offset(.5, .58);
      keeperTarget = chosenDive;
      _syncHud(message: 'أنت الحارس — اقرأ التسديدة واختر جهة القفز');
    }
  }

  bool _isFinished() {
    if (playerShots < 5 || robotShots < 5) return false;
    if (playerShots != robotShots) return false;
    return playerGoals != robotGoals;
  }

  void _syncHud({String? message}) {
    final current = hud.value;
    hud.value = WorldPenaltyHud(
      phase: phase,
      message: message ?? current.message,
      power: power,
      playerGoals: playerGoals,
      robotGoals: robotGoals,
      playerResults: List<WorldPenaltyOutcome>.unmodifiable(playerResults),
      robotResults: List<WorldPenaltyOutcome>.unmodifiable(robotResults),
      suddenDeath: suddenDeath,
    );
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    if (w <= 0 || h <= 0) return;

    final shake = phase == WorldPenaltyPhase.result
        ? math.sin(resultClock * 50) * (1 - resultClock.clamp(0.0, 1.0)) *
            (outcome == WorldPenaltyOutcome.post ? 4.0 : 1.6)
        : 0.0;
    canvas.save();
    canvas.translate(shake, -shake * .35);

    _drawStadium(canvas, w, h);
    _drawPitch(canvas, w, h);
    _drawGoal(canvas, w, h);
    _drawKeeper(canvas, w, h);
    _drawPlayer(canvas, w, h);
    _drawBall(canvas, w, h);
    _drawAtmosphere(canvas, w, h);

    canvas.restore();
    super.render(canvas);
  }

  void _drawStadium(Canvas canvas, double w, double h) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF02050A), Color(0xFF071A2A), Color(0xFF0B3340)],
        stops: <double>[0, .48, 1],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bg);

    final bowl = Paint()..color = const Color(0xFF071018);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * .5, h * .18), width: w * 1.45, height: h * .38), bowl);

    final crowd = Paint();
    for (var i = 0; i < 150; i++) {
      final x = (i * 43.7) % w;
      final y = h * .035 + (i % 9) * h * .018;
      final pulse = .5 + .5 * math.sin(ambient * 2.1 + i * .67);
      crowd.color = Color.lerp(
        const Color(0xFF1E40AF),
        championsMode ? const Color(0xFFFDE68A) : const Color(0xFF38BDF8),
        pulse,
      )!.withAlpha(185);
      canvas.drawCircle(Offset(x, y), 1.1 + (i % 3) * .25, crowd);
    }

    final lights = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white.withAlpha(230),
          const Color(0xFF7DD3FC).withAlpha(95),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(w * .5, h * .05), radius: w * .62));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * .40), lights);
  }

  void _drawPitch(Canvas canvas, double w, double h) {
    final field = Path()
      ..moveTo(w * .03, h)
      ..lineTo(w * .97, h)
      ..lineTo(w * .78, h * .42)
      ..lineTo(w * .22, h * .42)
      ..close();
    final fieldPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF087A4A), Color(0xFF0B9B59), Color(0xFF087044)],
      ).createShader(Rect.fromLTWH(0, h * .42, w, h * .58));
    canvas.drawPath(field, fieldPaint);

    final stripe = Paint()..color = const Color(0x1600FFAA);
    for (var i = 0; i < 7; i++) {
      final topY = h * (.45 + i * .078);
      canvas.drawRect(Rect.fromLTWH(0, topY, w, h * .038), stripe);
    }

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.white.withAlpha(155);
    canvas.drawPath(field, line);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * .5, h * .77), width: w * .36, height: h * .14),
      line,
    );
    canvas.drawCircle(Offset(w * .5, h * .79), 2.4, Paint()..color = Colors.white.withAlpha(200));
  }

  Rect _goalRect(double w, double h) => Rect.fromLTRB(w * .14, h * .12, w * .86, h * .46);

  void _drawGoal(Canvas canvas, double w, double h) {
    final goal = _goalRect(w, h);
    final netDepth = h * .045;
    final bulge = phase == WorldPenaltyPhase.result && outcome == WorldPenaltyOutcome.goal
        ? math.sin(math.min(1.0, resultClock * 3.2) * math.pi) * h * .018
        : 0.0;

    final net = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .75
      ..color = Colors.white.withAlpha(78);
    for (var i = 0; i <= 12; i++) {
      final x = goal.left + goal.width * i / 12;
      canvas.drawLine(
        Offset(x, goal.top + netDepth * .16),
        Offset(x + (x - goal.center.dx) * .025, goal.bottom + netDepth + bulge),
        net,
      );
    }
    for (var i = 0; i <= 7; i++) {
      final y = goal.top + goal.height * i / 7;
      final wave = bulge * math.sin(i / 7 * math.pi);
      canvas.drawLine(
        Offset(goal.left, y + wave),
        Offset(goal.right, y + wave),
        net,
      );
    }

    final posts = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6
      ..color = Colors.white;
    final frame = Path()
      ..moveTo(goal.left, goal.bottom)
      ..lineTo(goal.left, goal.top)
      ..lineTo(goal.right, goal.top)
      ..lineTo(goal.right, goal.bottom);
    canvas.drawPath(frame, posts);
    canvas.drawPath(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFBAE6FD),
    );
  }

  void _drawKeeper(Canvas canvas, double w, double h) {
    final goal = _goalRect(w, h);
    final t = phase == WorldPenaltyPhase.flying
        ? Curves.easeOutCubic.transform(flight.clamp(0.0, 1.0))
        : (phase == WorldPenaltyPhase.result ? 1.0 : 0.0);
    final start = Offset(goal.center.dx, goal.top + goal.height * .64);
    final target = Offset(
      goal.left + keeperTarget.dx * goal.width,
      goal.top + keeperTarget.dy * goal.height,
    );
    final pos = Offset.lerp(start, target, t)!;
    final lateral = (keeperTarget.dx - .5).abs();
    final rotation = (keeperTarget.dx - .5) * 1.45 * t;
    final scale = w * (.050 + lateral * .012);

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(rotation);

    final shadow = Paint()..color = Colors.black.withAlpha(80);
    canvas.drawOval(Rect.fromCenter(center: Offset(0, scale * 1.95), width: scale * 3.6, height: scale * .55), shadow);

    final jersey = Paint()
      ..shader = LinearGradient(
        colors: championsMode
            ? const <Color>[Color(0xFFFACC15), Color(0xFFF97316)]
            : const <Color>[Color(0xFF22D3EE), Color(0xFF2563EB)],
      ).createShader(Rect.fromLTWH(-scale, -scale, scale * 2, scale * 3));

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: scale * 1.15, height: scale * 2.15),
      Radius.circular(scale * .35),
    );
    canvas.drawRRect(body, jersey);

    final limb = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = scale * .34
      ..color = championsMode ? const Color(0xFFF59E0B) : const Color(0xFF0EA5E9);
    final reach = 1.55 + lateral * .85;
    canvas.drawLine(Offset(-scale * .35, -scale * .45), Offset(-scale * reach, scale * .02), limb);
    canvas.drawLine(Offset(scale * .35, -scale * .45), Offset(scale * reach, scale * .02), limb);

    final shorts = Paint()..color = const Color(0xFF111827);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, scale * 1.0), width: scale * 1.2, height: scale * .65),
        Radius.circular(scale * .15),
      ),
      shorts,
    );

    final legs = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = scale * .30
      ..color = const Color(0xFF111827);
    canvas.drawLine(Offset(-scale * .30, scale * 1.22), Offset(-scale * .62, scale * 2.0), legs);
    canvas.drawLine(Offset(scale * .30, scale * 1.22), Offset(scale * .62, scale * 2.0), legs);

    final skin = Paint()..color = const Color(0xFFD6A77A);
    canvas.drawCircle(Offset(0, -scale * 1.28), scale * .47, skin);
    final gloves = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(-scale * reach, scale * .02), scale * .27, gloves);
    canvas.drawCircle(Offset(scale * reach, scale * .02), scale * .27, gloves);

    canvas.restore();
  }

  void _drawPlayer(Canvas canvas, double w, double h) {
    final active = phase == WorldPenaltyPhase.flying || phase == WorldPenaltyPhase.result;
    final t = active ? Curves.easeInOut.transform(math.min(1.0, flight * 1.8)) : 0.0;
    final x = w * (.38 + t * .09);
    final y = h * (.83 - t * .015);
    final scale = w * .050;

    canvas.save();
    canvas.translate(x, y);
    final lean = active ? -.16 + t * .32 : -.08;
    canvas.rotate(lean);

    final shadow = Paint()..color = Colors.black.withAlpha(95);
    canvas.drawOval(Rect.fromCenter(center: Offset(scale * .2, scale * 2.5), width: scale * 3.2, height: scale * .48), shadow);

    final kit = Paint()
      ..shader = LinearGradient(
        colors: championsMode
            ? const <Color>[Color(0xFF7C3AED), Color(0xFF2563EB)]
            : const <Color>[Color(0xFFDC2626), Color(0xFF7F1D1D)],
      ).createShader(Rect.fromLTWH(-scale, -scale, scale * 2, scale * 3));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: scale * 1.05, height: scale * 2.15),
        Radius.circular(scale * .30),
      ),
      kit,
    );

    final limb = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = scale * .31
      ..color = championsMode ? const Color(0xFF5B21B6) : const Color(0xFF991B1B);
    canvas.drawLine(Offset(-scale * .34, -scale * .35), Offset(-scale * 1.1, scale * .45), limb);
    canvas.drawLine(Offset(scale * .34, -scale * .35), Offset(scale * 1.0, scale * .28), limb);

    final leg = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = scale * .34
      ..color = const Color(0xFF111827);
    final kick = active ? math.sin(math.min(1.0, flight * 2.5) * math.pi) : 0.0;
    canvas.drawLine(Offset(-scale * .25, scale * 1.05), Offset(-scale * .52, scale * 2.15), leg);
    canvas.drawLine(
      Offset(scale * .25, scale * 1.05),
      Offset(scale * (.55 + kick * 1.15), scale * (2.0 - kick * .85)),
      leg,
    );

    final skin = Paint()..color = const Color(0xFFC98F65);
    canvas.drawCircle(Offset(0, -scale * 1.28), scale * .44, skin);
    canvas.restore();
  }

  void _drawBall(Canvas canvas, double w, double h) {
    final start = Offset(w * .5, h * .80);
    final goal = _goalRect(w, h);
    final target = Offset(
      goal.left + actualAim.dx * goal.width,
      goal.top + actualAim.dy * goal.height,
    );

    double t = 0;
    if (phase == WorldPenaltyPhase.flying) {
      t = Curves.easeInCubic.transform(flight.clamp(0.0, 1.0));
    } else if (phase == WorldPenaltyPhase.result) {
      t = 1;
    }

    final sideBend = math.sin(t * math.pi) * curve * w * .10;
    final lift = math.sin(t * math.pi) * h * (.045 + power * .022);
    final pos = Offset.lerp(start, target, t)! + Offset(sideBend, -lift);
    final radius = math.max(5.2, w * .042 * (1 - t * .69));

    if (phase == WorldPenaltyPhase.flying) {
      final trail = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = radius * .65
        ..color = Colors.white.withAlpha(36);
      for (var i = 1; i <= 6; i++) {
        final tt = math.max(0.0, t - i * .028);
        final p = Offset.lerp(start, target, tt)! +
            Offset(math.sin(tt * math.pi) * curve * w * .10, -math.sin(tt * math.pi) * h * (.045 + power * .022));
        canvas.drawCircle(p, radius * (1 - i * .07), trail);
      }
    }

    final shadow = Paint()..color = Colors.black.withAlpha((85 * (1 - t * .6)).round());
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(pos.dx, math.min(h * .82, pos.dy + radius * 2.2)),
        width: radius * 2.7,
        height: radius * .70,
      ),
      shadow,
    );

    final ball = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-.32, -.38),
        colors: <Color>[Colors.white, Color(0xFFE5E7EB), Color(0xFF9CA3AF)],
      ).createShader(Rect.fromCircle(center: pos, radius: radius));
    canvas.drawCircle(pos, radius, ball);

    final marks = Paint()..color = const Color(0xFF111827);
    final spin = ambient * 8.0 + t * power * 22;
    canvas.drawCircle(pos, radius * .27, marks);
    for (var i = 0; i < 5; i++) {
      final a = spin + i * math.pi * 2 / 5;
      canvas.drawCircle(
        pos + Offset(math.cos(a), math.sin(a)) * radius * .58,
        radius * .11,
        marks,
      );
    }

    if (canShoot) {
      final preview = Offset(
        goal.left + aim.dx * goal.width,
        goal.top + aim.dy * goal.height,
      );
      final targetPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..color = const Color(0xAA7DD3FC);
      canvas.drawCircle(preview, 11, targetPaint);
      canvas.drawCircle(preview, 3, Paint()..color = const Color(0xFF7DD3FC));
    }
  }

  void _drawAtmosphere(Canvas canvas, double w, double h) {
    final dust = Paint();
    for (var i = 0; i < 22; i++) {
      final x = (i * 71.0 + ambient * (8 + i % 4)) % w;
      final y = h * .40 + ((i * 37.0 + ambient * (5 + i % 3)) % (h * .55));
      dust.color = Colors.white.withAlpha(12 + (i % 4) * 5);
      canvas.drawCircle(Offset(x, y), 1.0 + (i % 3) * .45, dust);
    }

    if (phase == WorldPenaltyPhase.result && resultClock < .55) {
      final flashAlpha = ((1 - resultClock / .55) * 95).clamp(0, 95).round();
      final color = switch (outcome) {
        WorldPenaltyOutcome.goal => const Color(0xFF22C55E),
        WorldPenaltyOutcome.save => const Color(0xFF38BDF8),
        WorldPenaltyOutcome.post => const Color(0xFFF59E0B),
        WorldPenaltyOutcome.miss => const Color(0xFFEF4444),
      };
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = color.withAlpha(flashAlpha));
    }
  }
}
