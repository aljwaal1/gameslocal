import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio_feedback.dart';
import '../../core/network/local_network_core.dart';
import 'elite_penalty_game_v2.dart' as legacy;
import 'penalty_shootout_game.dart' show FootballTeam, footballTeams;
import 'realistic_football_sprite.dart';

class ChampionsPenaltyGameScreen extends StatelessWidget {
  const ChampionsPenaltyGameScreen({super.key, this.networkCore});
  final LocalNetworkCore? networkCore;

  @override
  Widget build(BuildContext context) {
    if (networkCore != null) {
      return legacy.ChampionsPenaltyGameScreen(networkCore: networkCore);
    }
    return const _PhotoPenaltyGame(
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
    return const _PhotoPenaltyGame(
      title: 'ركلات الترجيح',
      subtitle: 'WORLD PENALTY ARENA',
      championsMode: false,
    );
  }
}

enum _PenaltyPhase { aiming, saving, flying, result, finished }
enum _PenaltyOutcome { goal, save, post, miss }

class _PhotoPenaltyGame extends StatefulWidget {
  const _PhotoPenaltyGame({
    required this.title,
    required this.subtitle,
    required this.championsMode,
  });

  final String title;
  final String subtitle;
  final bool championsMode;

  @override
  State<_PhotoPenaltyGame> createState() => _PhotoPenaltyGameState();
}

class _PhotoPenaltyGameState extends State<_PhotoPenaltyGame>
    with TickerProviderStateMixin {
  final math.Random _random = math.Random();
  late final AnimationController _shot;
  late final AnimationController _ambient;

  _PenaltyPhase _phase = _PenaltyPhase.aiming;
  _PenaltyOutcome _outcome = _PenaltyOutcome.goal;
  Offset _target = const Offset(.5, .30);
  Offset _keeper = const Offset(.5, .56);
  double _power = .72;
  int _playerGoals = 0;
  int _robotGoals = 0;
  int _playerShots = 0;
  int _robotShots = 0;
  final List<_PenaltyOutcome> _playerResults = <_PenaltyOutcome>[];
  final List<_PenaltyOutcome> _robotResults = <_PenaltyOutcome>[];
  String _message = 'اسحب من الكرة نحو زاوية المرمى';
  Offset? _dragStart;
  Offset? _dragNow;

  FootballTeam get _playerTeam => footballTeams.first;
  FootballTeam get _robotTeam => footballTeams[1];
  bool get _suddenDeath => _playerShots >= 5 && _robotShots >= 5;
  bool get _playerIsShooting => _playerShots == _robotShots;

  @override
  void initState() {
    super.initState();
    _shot = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1180),
    )..addListener(() => setState(() {}));
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )
      ..repeat()
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _shot.dispose();
    _ambient.dispose();
    super.dispose();
  }

  void _restart() {
    _shot.stop();
    _shot.value = 0;
    setState(() {
      _phase = _PenaltyPhase.aiming;
      _outcome = _PenaltyOutcome.goal;
      _target = const Offset(.5, .30);
      _keeper = const Offset(.5, .56);
      _power = .72;
      _playerGoals = 0;
      _robotGoals = 0;
      _playerShots = 0;
      _robotShots = 0;
      _playerResults.clear();
      _robotResults.clear();
      _message = 'اسحب من الكرة نحو زاوية المرمى';
    });
  }

  Rect _goalRect(Size size) {
    return Rect.fromLTRB(
      size.width * .12,
      size.height * .17,
      size.width * .88,
      size.height * .49,
    );
  }

  Offset _normalizeToGoal(Offset point, Size size) {
    final goal = _goalRect(size);
    return Offset(
      ((point.dx - goal.left) / goal.width).clamp(.02, .98).toDouble(),
      ((point.dy - goal.top) / goal.height).clamp(.03, .97).toDouble(),
    );
  }

  Future<void> _shootPlayer(Offset aim, double power) async {
    if (_phase != _PenaltyPhase.aiming) return;
    final spread = .015 + math.max(0.0, power - .90) * .30;
    final actual = Offset(
      (aim.dx + (_random.nextDouble() - .5) * spread).clamp(-.06, 1.06).toDouble(),
      (aim.dy + (_random.nextDouble() - .5) * spread).clamp(-.06, 1.06).toDouble(),
    );
    final keeper = Offset(
      .09 + _random.nextDouble() * .82,
      .10 + _random.nextDouble() * .76,
    );
    final distance = (actual - keeper).distance;
    final outside = actual.dx < 0 || actual.dx > 1 || actual.dy < 0 || actual.dy > 1;
    final nearFrame = actual.dx < .025 || actual.dx > .975 || actual.dy < .025;

    _PenaltyOutcome result;
    if (outside) {
      result = _PenaltyOutcome.miss;
    } else if (nearFrame && _random.nextDouble() < .14) {
      result = _PenaltyOutcome.post;
    } else if (distance < (.17 - power * .035) && _random.nextDouble() < .76) {
      result = _PenaltyOutcome.save;
    } else {
      result = _PenaltyOutcome.goal;
    }

    setState(() {
      _target = actual;
      _keeper = keeper;
      _power = power;
      _outcome = result;
      _phase = _PenaltyPhase.flying;
      _message = power > .93 ? 'قذيفة قوية...' : 'التسديدة انطلقت...';
    });
    GameFeedback.kick();
    await _animateShot();

    if (!mounted) return;
    setState(() {
      _playerShots++;
      _playerResults.add(result);
      if (result == _PenaltyOutcome.goal) _playerGoals++;
      _phase = _PenaltyPhase.result;
      _message = _resultText(result);
    });
    switch (result) {
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
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    _advanceTurn();
  }

  Future<void> _shootRobot(Offset dive) async {
    if (_phase != _PenaltyPhase.saving) return;
    final target = Offset(
      .07 + _random.nextDouble() * .86,
      .07 + _random.nextDouble() * .82,
    );
    final power = .70 + _random.nextDouble() * .27;
    final distance = (target - dive).distance;
    final risk = _random.nextDouble();

    _PenaltyOutcome result;
    if (risk < .03) {
      result = _PenaltyOutcome.miss;
    } else if ((target.dx < .055 || target.dx > .945) && risk < .12) {
      result = _PenaltyOutcome.post;
    } else if (distance < .13 || (distance < .22 && _random.nextDouble() < .62)) {
      result = _PenaltyOutcome.save;
    } else {
      result = _PenaltyOutcome.goal;
    }

    setState(() {
      _target = target;
      _keeper = dive;
      _power = power;
      _outcome = result;
      _phase = _PenaltyPhase.flying;
      _message = 'المنافس يسدد...';
    });
    GameFeedback.kick();
    await _animateShot();

    if (!mounted) return;
    setState(() {
      _robotShots++;
      _robotResults.add(result);
      if (result == _PenaltyOutcome.goal) _robotGoals++;
      _phase = _PenaltyPhase.result;
      _message = result == _PenaltyOutcome.save ? 'تصـــدٍ رائع!' : _resultText(result);
    });
    switch (result) {
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
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    _advanceTurn();
  }

  Future<void> _animateShot() async {
    _shot.value = 0;
    await _shot.forward();
  }

  String _resultText(_PenaltyOutcome result) {
    return switch (result) {
      _PenaltyOutcome.goal => widget.championsMode ? 'هــــدف عالمي!' : 'هــــدف!',
      _PenaltyOutcome.save => 'تصـــدٍ مذهل!',
      _PenaltyOutcome.post => 'في القائم!',
      _PenaltyOutcome.miss => 'خارج المرمى!',
    };
  }

  bool _finished() {
    if (_playerShots < 5 || _robotShots < 5) return false;
    if (_playerShots != _robotShots) return false;
    return _playerGoals != _robotGoals;
  }

  void _advanceTurn() {
    _shot.value = 0;
    if (_finished()) {
      setState(() {
        _phase = _PenaltyPhase.finished;
        _message = _playerGoals > _robotGoals
            ? '🏆 أنت البطل'
            : 'انتهت المباراة — الروبوت يفوز';
      });
      return;
    }

    setState(() {
      _target = const Offset(.5, .30);
      _keeper = const Offset(.5, .56);
      _power = .72;
      if (_playerIsShooting) {
        _phase = _PenaltyPhase.aiming;
        _message = _suddenDeath
            ? 'الحسم المفاجئ — اسحب نحو الزاوية'
            : 'اسحب من الكرة نحو زاوية المرمى';
      } else {
        _phase = _PenaltyPhase.saving;
        _message = 'أنت الحارس — اختر جهة القفز';
      }
    });
  }

  FootballSpritePose _keeperPose() {
    if (_phase == _PenaltyPhase.aiming || _phase == _PenaltyPhase.saving) {
      return FootballSpritePose.keeperReady;
    }
    return _shot.value < .52
        ? FootballSpritePose.keeperReady
        : FootballSpritePose.keeperDive;
  }

  Widget _scoreSide(
    String label,
    int score,
    List<_PenaltyOutcome> results,
    CrossAxisAlignment alignment,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: alignment,
        children: <Widget>[
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          Text(
            '$score',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 30,
              height: 1,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final result in results.take(7))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    result == _PenaltyOutcome.goal
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: result == _PenaltyOutcome.goal
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFFF87171),
                    size: 13,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02050A),
      appBar: AppBar(
        toolbarHeight: 62,
        elevation: 0,
        backgroundColor: const Color(0xFF050A10),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            Text(
              widget.subtitle,
              style: const TextStyle(
                color: Color(0xFF7DD3FC),
                fontSize: 9,
                letterSpacing: 2.7,
                fontWeight: FontWeight.w800,
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
            Container(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 11),
              color: const Color(0xFF050A10),
              child: Row(
                children: <Widget>[
                  _scoreSide('أنت', _playerGoals, _playerResults, CrossAxisAlignment.start),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: const Color(0xFF0D1722),
                      border: Border.all(color: const Color(0x4438BDF8)),
                    ),
                    child: Text(
                      _suddenDeath ? 'SUDDEN DEATH' : 'PENALTIES',
                      style: const TextStyle(
                        color: Color(0xFF7DD3FC),
                        fontSize: 9,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _scoreSide('الروبوت', _robotGoals, _robotResults, CrossAxisAlignment.end),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.biggest;
                  final goal = _goalRect(size);
                  final ballStart = Offset(size.width * .50, size.height * .79);
                  final targetPx = Offset(
                    goal.left + goal.width * _target.dx,
                    goal.top + goal.height * _target.dy,
                  );
                  final flightT = Curves.easeInCubic.transform(_shot.value);
                  final ball = Offset.lerp(ballStart, targetPx, flightT)!;
                  final keeperX = goal.left + goal.width * _keeper.dx;
                  final keeperY = goal.top + goal.height * _keeper.dy;
                  final keeperT = Curves.easeOutCubic.transform(_shot.value);
                  final keeperPos = Offset.lerp(goal.center, Offset(keeperX, keeperY), keeperT)!;

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (details) {
                      if (_phase != _PenaltyPhase.aiming) return;
                      _dragStart = details.localPosition;
                      _dragNow = details.localPosition;
                    },
                    onPanUpdate: (details) {
                      if (_dragStart == null || _phase != _PenaltyPhase.aiming) return;
                      setState(() => _dragNow = details.localPosition);
                    },
                    onPanEnd: (_) {
                      if (_dragStart == null || _dragNow == null || _phase != _PenaltyPhase.aiming) {
                        _dragStart = null;
                        _dragNow = null;
                        return;
                      }
                      final delta = _dragNow! - _dragStart!;
                      final aim = _normalizeToGoal(_dragNow!, size);
                      final power = (.58 + delta.distance / (size.height * .42))
                          .clamp(.58, 1.0)
                          .toDouble();
                      _dragStart = null;
                      _dragNow = null;
                      _shootPlayer(aim, power);
                    },
                    onTapDown: (details) {
                      if (_phase == _PenaltyPhase.saving && goal.contains(details.localPosition)) {
                        _shootRobot(_normalizeToGoal(details.localPosition, size));
                      }
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        Image.asset(
                          'assets/football/pro_penalty_arena.jpg',
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                          isAntiAlias: true,
                        ),
                        const DecoratedBox(
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
                        ),
                        if (_phase == _PenaltyPhase.aiming || _phase == _PenaltyPhase.saving)
                          Positioned(
                            left: ballStart.dx - 31,
                            top: ballStart.dy - 31,
                            child: const _PenaltySpotBall(),
                          ),
                        Positioned(
                          left: keeperPos.dx - size.width * .26,
                          top: keeperPos.dy - size.height * .19,
                          width: size.width * .52,
                          height: size.height * .38,
                          child: Transform.rotate(
                            angle: (_keeper.dx - .5) * .50 * keeperT,
                            child: RealisticFootballSprite(
                              pose: _keeperPose(),
                              primary: widget.championsMode
                                  ? const Color(0xFFFFB020)
                                  : const Color(0xFF38BDF8),
                              secondary: const Color(0xFF0F172A),
                              mirror: _keeper.dx < .5,
                              alignment: const Alignment(0, -.05),
                            ),
                          ),
                        ),
                        if (_phase == _PenaltyPhase.aiming)
                          Positioned.fromRect(
                            rect: goal,
                            child: IgnorePointer(
                              child: CustomPaint(painter: _GoalGridPainter()),
                            ),
                          ),
                        if (_phase == _PenaltyPhase.aiming && _dragNow != null)
                          Positioned(
                            left: _dragNow!.dx - 22,
                            top: _dragNow!.dy - 22,
                            child: const IgnorePointer(child: _AimMarker()),
                          ),
                        if (_phase == _PenaltyPhase.flying || _phase == _PenaltyPhase.result)
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
                          ),
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: const Color(0xDA050A10),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0x3338BDF8)),
                              boxShadow: const <BoxShadow>[
                                BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 8)),
                              ],
                            ),
                            child: Text(
                              _message,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _phase == _PenaltyPhase.saving
                                    ? const Color(0xFFFDE68A)
                                    : Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _PhotoBall extends StatelessWidget {
  const _PhotoBall();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-.35, -.42),
          colors: <Color>[Colors.white, Color(0xFFE2E8F0), Color(0xFF64748B)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(3, 6)),
        ],
      ),
      child: const Icon(Icons.sports_soccer, size: 24, color: Color(0xFF111827)),
    );
  }
}

class _AimMarker extends StatelessWidget {
  const _AimMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0x2238BDF8),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x9938BDF8), blurRadius: 12),
        ],
      ),
      child: const Icon(Icons.add, color: Colors.white, size: 22),
    );
  }
}

class _GoalGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(78)
      ..strokeWidth = 1;
    for (var i = 1; i < 7; i++) {
      canvas.drawLine(Offset(size.width * i / 7, 0), Offset(size.width * i / 7, size.height), paint);
    }
    for (var i = 1; i < 5; i++) {
      canvas.drawLine(Offset(0, size.height * i / 5), Offset(size.width, size.height * i / 5), paint);
    }
    final frame = Paint()
      ..color = Colors.white.withAlpha(225)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(2)), frame);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
