import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/local_network_core.dart';
import '../../core/network/network_message.dart';

class ChampionsPenaltyGameScreen extends StatelessWidget {
  const ChampionsPenaltyGameScreen({super.key, this.networkCore});

  final LocalNetworkCore? networkCore;

  @override
  Widget build(BuildContext context) => _ElitePenaltyGame(
        networkCore: networkCore,
        title: 'ركلات الأبطال',
        subtitle: 'تسديد وتحكم بالحارس',
        actionName: 'eliteChampionsPenalty',
        humanKeeperVsRobot: true,
      );
}

class ProPenaltyShootoutGameScreen extends StatelessWidget {
  const ProPenaltyShootoutGameScreen({super.key, this.networkCore});

  final LocalNetworkCore? networkCore;

  @override
  Widget build(BuildContext context) => _ElitePenaltyGame(
        networkCore: networkCore,
        title: 'ركلات الترجيح',
        subtitle: 'Penalty Arena Elite',
        actionName: 'eliteProPenalty',
        humanKeeperVsRobot: false,
      );
}

enum _Phase { ready, shooting, saving, flying, result, finished }
enum _Outcome { goal, save, post, miss }

class _ElitePenaltyGame extends StatefulWidget {
  const _ElitePenaltyGame({
    required this.networkCore,
    required this.title,
    required this.subtitle,
    required this.actionName,
    required this.humanKeeperVsRobot,
  });

  final LocalNetworkCore? networkCore;
  final String title;
  final String subtitle;
  final String actionName;
  final bool humanKeeperVsRobot;

  @override
  State<_ElitePenaltyGame> createState() => _ElitePenaltyGameState();
}

class _ElitePenaltyGameState extends State<_ElitePenaltyGame>
    with TickerProviderStateMixin {
  final math.Random _random = math.Random();
  late final AnimationController _shot;
  late final AnimationController _stadium;
  StreamSubscription<NetworkMessage>? _networkSub;

  _Phase _phase = _Phase.ready;
  _Outcome _outcome = _Outcome.goal;
  Offset _aim = const Offset(.5, .34);
  Offset _keeper = const Offset(.5, .56);
  Offset? _dragStart;
  Offset? _dragNow;
  double _power = .72;
  double _curve = 0;
  int _turn = 0;
  int _leftGoals = 0;
  int _rightGoals = 0;
  int _leftShots = 0;
  int _rightShots = 0;
  bool _connectionLost = false;
  final List<_Outcome> _leftResults = <_Outcome>[];
  final List<_Outcome> _rightResults = <_Outcome>[];
  String _message = 'اسحب من الكرة إلى زاوية المرمى';

  bool get _network => widget.networkCore != null;
  bool get _isHost => widget.networkCore?.state.mode == LocalNetworkMode.host;
  bool get _localTurn => !_network || (_turn.isEven == _isHost);
  bool get _leftTurn => _turn.isEven;
  bool get _finished {
    if (_leftShots < 5 || _rightShots < 5) return false;
    if (_leftShots != _rightShots) return false;
    return _leftGoals != _rightGoals;
  }

  String get _localId {
    final players = widget.networkCore?.state.players ?? const <LocalPlayer>[];
    final own = players.where((p) => p.isHost == _isHost);
    return own.isNotEmpty ? own.first.id : (_isHost ? 'host' : 'guest');
  }

  @override
  void initState() {
    super.initState();
    _shot = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1650),
    );
    _stadium = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    if (_network) {
      _networkSub = widget.networkCore!.messages.listen(_onNetwork);
    }
  }

  @override
  void dispose() {
    _networkSub?.cancel();
    _shot.dispose();
    _stadium.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _phase = _Phase.ready;
      _turn = 0;
      _leftGoals = 0;
      _rightGoals = 0;
      _leftShots = 0;
      _rightShots = 0;
      _leftResults.clear();
      _rightResults.clear();
      _connectionLost = false;
      _aim = const Offset(.5, .34);
      _keeper = const Offset(.5, .56);
      _power = .72;
      _curve = 0;
      _message = 'اسحب من الكرة إلى زاوية المرمى';
      _shot.reset();
    });
  }

  void _beginDrag(DragStartDetails details, Size size) {
    if (_phase != _Phase.ready || !_localTurn || _connectionLost) return;
    final ball = Offset(size.width * .5, size.height * .82);
    if ((details.localPosition - ball).distance > size.width * .18) return;
    setState(() {
      _phase = _Phase.shooting;
      _dragStart = details.localPosition;
      _dragNow = details.localPosition;
    });
    HapticFeedback.selectionClick();
  }

  void _updateDrag(DragUpdateDetails details, Size size) {
    if (_phase != _Phase.shooting || _dragStart == null) return;
    final p = details.localPosition;
    final goal = _goalRect(size);
    final raw = p - _dragStart!;
    final distance = raw.distance;
    final normalized = Offset(
      ((p.dx - goal.left) / goal.width).clamp(.015, .985).toDouble(),
      ((p.dy - goal.top) / goal.height).clamp(.025, .975).toDouble(),
    );
    setState(() {
      _dragNow = p;
      _aim = normalized;
      _power = (.38 + distance / (size.height * .43)).clamp(.42, 1.0);
      _curve = (raw.dx / (size.width * .55)).clamp(-1.0, 1.0);
    });
  }

  void _endDrag(DragEndDetails details) {
    if (_phase != _Phase.shooting || _dragStart == null) return;
    _dragStart = null;
    _dragNow = null;
    unawaited(_takeShot(_aim, _power, _curve, local: true));
  }

  Rect _goalRect(Size size) => Rect.fromLTRB(
        size.width * .105,
        size.height * .115,
        size.width * .895,
        size.height * .455,
      );

  Future<void> _takeShot(
    Offset requested,
    double power,
    double curve, {
    required bool local,
  }) async {
    if (_phase != _Phase.shooting && _phase != _Phase.ready) return;

    final overPower = ((power - .90) / .10).clamp(0.0, 1.0);
    final underPower = ((.58 - power) / .16).clamp(0.0, 1.0);
    final skillNoise = .012 + overPower * .065 + underPower * .035;
    final actual = Offset(
      requested.dx + (_random.nextDouble() - .5) * skillNoise + curve * .018,
      requested.dy + (_random.nextDouble() - .5) * skillNoise,
    );

    final edgeX = (actual.dx - .5).abs();
    final nearPost = edgeX > .455 || actual.dy < .035;
    final missRisk = overPower * .13 + (actual.dy < .04 ? .08 : 0);
    final postRisk = nearPost ? .13 + power * .05 : .012;

    final keeperRead = .22 + (1 - power) * .20;
    final reads = _random.nextDouble() < keeperRead;
    final predicted = reads
        ? Offset(
            (actual.dx + (_random.nextDouble() - .5) * .12).clamp(.06, .94),
            (actual.dy + (_random.nextDouble() - .5) * .14).clamp(.08, .88),
          )
        : Offset(
            .10 + _random.nextDouble() * .80,
            .12 + _random.nextDouble() * .70,
          );

    final reach = .165 + (1 - power) * .055;
    final saveDistance = (actual - predicted).distance;
    final saveChance = saveDistance < reach
        ? (.76 - power * .20).clamp(.38, .64)
        : saveDistance < reach * 1.38
            ? .18
            : .035;

    late final _Outcome outcome;
    if (_random.nextDouble() < missRisk) {
      outcome = _Outcome.miss;
    } else if (_random.nextDouble() < postRisk) {
      outcome = _Outcome.post;
    } else if (_random.nextDouble() < saveChance) {
      outcome = _Outcome.save;
    } else {
      outcome = _Outcome.goal;
    }

    final turn = _turn;
    await _animate(
      target: Offset(actual.dx.clamp(-.06, 1.06), actual.dy.clamp(-.05, 1.03)),
      keeper: predicted,
      power: power,
      curve: curve,
      outcome: outcome,
      local: local,
    );

    if (_network && local) {
      widget.networkCore!.sendMove(<String, dynamic>{
        'action': widget.actionName,
        'turn': turn,
        'tx': actual.dx,
        'ty': actual.dy,
        'kx': predicted.dx,
        'ky': predicted.dy,
        'power': power,
        'curve': curve,
        'outcome': outcome.name,
      }, senderId: _localId);
    }
  }

  Future<void> _animate({
    required Offset target,
    required Offset keeper,
    required double power,
    required double curve,
    required _Outcome outcome,
    required bool local,
  }) async {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.flying;
      _aim = target;
      _keeper = keeper;
      _power = power;
      _curve = curve;
      _outcome = outcome;
      _message = local ? 'التسديدة تنطلق...' : 'المنافس يسدد...';
    });
    HapticFeedback.lightImpact();
    try {
      await _shot.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted) return;

    final wasLeft = _leftTurn;
    setState(() {
      final goal = outcome == _Outcome.goal;
      if (wasLeft) {
        _leftShots++;
        _leftResults.add(outcome);
        if (goal) _leftGoals++;
      } else {
        _rightShots++;
        _rightResults.add(outcome);
        if (goal) _rightGoals++;
      }
      _turn++;
      _phase = _Phase.result;
      _message = switch (outcome) {
        _Outcome.goal => 'هــــدف! ⚽',
        _Outcome.save => 'تصـــدٍ رائع! 🧤',
        _Outcome.post => 'في القائم! 💥',
        _Outcome.miss => 'خارج المرمى!',
      };
    });

    if (outcome == _Outcome.goal) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    } else {
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);
    }

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    _shot.reset();

    if (_finished) {
      setState(() {
        _phase = _Phase.finished;
        _message = _leftGoals > _rightGoals ? '🏆 فاز اللاعب 1' : '🏆 فاز المنافس';
      });
      return;
    }

    if (!_network && _turn.isOdd) {
      if (widget.humanKeeperVsRobot) {
        setState(() {
          _phase = _Phase.saving;
          _message = 'أنت الحارس — اسحب نحو جهة القفز';
          _keeper = const Offset(.5, .56);
        });
      } else {
        setState(() {
          _phase = _Phase.flying;
          _message = 'المنافس يجهز التسديدة...';
        });
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (mounted) await _robotShot();
      }
    } else {
      setState(() {
        _phase = _Phase.ready;
        _message = _network && !_localTurn
            ? 'بانتظار اللاعب الآخر'
            : 'اسحب من الكرة إلى زاوية المرمى';
      });
    }
  }

  Future<void> _robotShot({Offset? forcedKeeper}) async {
    final target = Offset(
      .08 + _random.nextDouble() * .84,
      .07 + _random.nextDouble() * .76,
    );
    final power = .64 + _random.nextDouble() * .34;
    final curve = (_random.nextDouble() - .5) * .65;

    if (forcedKeeper == null) {
      setState(() => _phase = _Phase.ready);
      await _takeShot(target, power, curve, local: false);
      return;
    }

    final actual = Offset(
      target.dx + (_random.nextDouble() - .5) * .035,
      target.dy + (_random.nextDouble() - .5) * .035,
    );
    final d = (actual - forcedKeeper).distance;
    final saved = d < .19 && _random.nextDouble() < .73;
    final edge = (actual.dx - .5).abs() > .47 || actual.dy < .025;
    final outcome = saved
        ? _Outcome.save
        : edge && _random.nextDouble() < .22
            ? _Outcome.post
            : _Outcome.goal;
    await _animate(
      target: actual,
      keeper: forcedKeeper,
      power: power,
      curve: curve,
      outcome: outcome,
      local: false,
    );
  }

  void _keeperPanEnd(DragEndDetails details, Size size) {
    if (_phase != _Phase.saving) return;
    final velocity = details.velocity.pixelsPerSecond;
    final dx = (velocity.dx / 1300).clamp(-.44, .44);
    final dy = (velocity.dy / 1500).clamp(-.34, .25);
    final dive = Offset((.5 + dx).clamp(.06, .94), (.52 + dy).clamp(.08, .88));
    setState(() {
      _keeper = dive;
      _phase = _Phase.flying;
      _message = 'الحارس يقفز...';
    });
    unawaited(_robotShot(forcedKeeper: dive));
  }

  void _onNetwork(NetworkMessage message) {
    if (!mounted || message.senderId == _localId) return;
    if (message.type == NetworkMessageType.disconnect) {
      setState(() {
        _connectionLost = true;
        _message = 'انقطع اتصال اللاعب الآخر';
      });
      return;
    }
    if (message.type != NetworkMessageType.move ||
        message.payload['action'] != widget.actionName) return;
    final turn = (message.payload['turn'] as num?)?.toInt();
    if (turn != _turn) return;
    final tx = (message.payload['tx'] as num?)?.toDouble();
    final ty = (message.payload['ty'] as num?)?.toDouble();
    final kx = (message.payload['kx'] as num?)?.toDouble();
    final ky = (message.payload['ky'] as num?)?.toDouble();
    final power = (message.payload['power'] as num?)?.toDouble();
    final curve = (message.payload['curve'] as num?)?.toDouble();
    final outcomeName = message.payload['outcome']?.toString();
    if (tx == null || ty == null || kx == null || ky == null || power == null || curve == null) return;
    final outcome = _Outcome.values.where((e) => e.name == outcomeName).firstOrNull;
    if (outcome == null) return;
    unawaited(_animate(
      target: Offset(tx, ty),
      keeper: Offset(kx, ky),
      power: power,
      curve: curve,
      outcome: outcome,
      local: false,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02070C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07131D),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(widget.subtitle, style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ],
        ),
        actions: <Widget>[
          IconButton(onPressed: _reset, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _ScoreBar(
              leftGoals: _leftGoals,
              rightGoals: _rightGoals,
              left: _leftResults,
              right: _rightResults,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: _phase == _Phase.result && _outcome == _Outcome.goal
                      ? const Color(0xFF087F5B)
                      : const Color(0xFF0D1B28),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.sports_soccer, color: Color(0xFFFFD166), size: 19),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final size = c.biggest;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (d) => _phase == _Phase.saving
                          ? null
                          : _beginDrag(d, size),
                      onPanUpdate: (d) => _updateDrag(d, size),
                      onPanEnd: (d) => _phase == _Phase.saving
                          ? _keeperPanEnd(d, size)
                          : _endDrag(d),
                      child: AnimatedBuilder(
                        animation: Listenable.merge(<Listenable>[_shot, _stadium]),
                        builder: (context, _) => CustomPaint(
                          painter: _ElitePenaltyPainter(
                            progress: _shot.value,
                            ambient: _stadium.value,
                            aim: _aim,
                            keeper: _keeper,
                            power: _power,
                            curve: _curve,
                            phase: _phase,
                            outcome: _outcome,
                            dragPoint: _dragNow,
                            goalRect: _goalRect(size),
                          ),
                          size: size,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_phase == _Phase.finished)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: FilledButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('مباراة جديدة'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({
    required this.leftGoals,
    required this.rightGoals,
    required this.left,
    required this.right,
  });

  final int leftGoals;
  final int rightGoals;
  final List<_Outcome> left;
  final List<_Outcome> right;

  Widget _resultDot(_Outcome result) {
    final goal = result == _Outcome.goal;
    return Icon(
      goal ? Icons.check_circle_rounded : Icons.cancel_rounded,
      size: 14,
      color: goal ? Colors.greenAccent : Colors.redAccent,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1722),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: _side('أنت', leftGoals, left)),
          Text('$leftGoals  -  $rightGoals',
              style: const TextStyle(color: Color(0xFFFFD166), fontSize: 26, fontWeight: FontWeight.w900)),
          Expanded(child: _side('المنافس', rightGoals, right)),
        ],
      ),
    );
  }

  Widget _side(String name, int goals, List<_Outcome> results) {
    return Column(
      children: <Widget>[
        Text(name, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Wrap(spacing: 1, children: results.map(_resultDot).toList(growable: false)),
      ],
    );
  }
}

class _ElitePenaltyPainter extends CustomPainter {
  const _ElitePenaltyPainter({
    required this.progress,
    required this.ambient,
    required this.aim,
    required this.keeper,
    required this.power,
    required this.curve,
    required this.phase,
    required this.outcome,
    required this.dragPoint,
    required this.goalRect,
  });

  final double progress;
  final double ambient;
  final Offset aim;
  final Offset keeper;
  final double power;
  final double curve;
  final _Phase phase;
  final _Outcome outcome;
  final Offset? dragPoint;
  final Rect goalRect;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..isAntiAlias = true;
    final whole = Offset.zero & size;
    p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xFF02050A), Color(0xFF0A2030), Color(0xFF0A6648)],
      stops: <double>[0, .42, 1],
    ).createShader(whole);
    canvas.drawRRect(RRect.fromRectAndRadius(whole, const Radius.circular(24)), p);
    p.shader = null;

    _stadiumLights(canvas, size, p);
    _pitch(canvas, size, p);
    _goal(canvas, p);

    final target = Offset(goalRect.left + aim.dx * goalRect.width, goalRect.top + aim.dy * goalRect.height);
    final keeperTarget = Offset(goalRect.left + keeper.dx * goalRect.width, goalRect.top + keeper.dy * goalRect.height);
    final keeperT = Curves.easeOutCubic.transform(((progress - .34) / .48).clamp(0.0, 1.0));
    final keeperPos = Offset.lerp(goalRect.center + Offset(0, goalRect.height * .17), keeperTarget, keeperT)!;
    _keeperBody(canvas, keeperPos, keeperT, p, size);

    final ballStart = Offset(size.width * .5, size.height * .80);
    final flight = Curves.easeInCubic.transform(((progress - .26) / .62).clamp(0.0, 1.0));
    final mid = Offset(size.width * (.5 + curve * .055), size.height * .48);
    final ballPos = _quadratic(ballStart, mid, target, flight);
    final radius = math.max(4.8, size.width * .047 * (1 - flight * .74));

    if (flight > .03) {
      p.style = PaintingStyle.stroke;
      p.strokeWidth = 2.2;
      p.color = Colors.white.withOpacity(.18 * (1 - flight));
      final trail = Path()..moveTo(ballStart.dx, ballStart.dy)..quadraticBezierTo(mid.dx, mid.dy, ballPos.dx, ballPos.dy);
      canvas.drawPath(trail, p);
    }
    _ball(canvas, ballPos, radius, p, progress * 12);

    if (phase == _Phase.shooting && dragPoint != null) {
      p.style = PaintingStyle.stroke;
      p.strokeWidth = 2.4;
      p.color = const Color(0xFFFFD166);
      canvas.drawLine(ballStart, dragPoint!, p);
      canvas.drawCircle(target, 17, p);
      _powerMeter(canvas, size, p);
    }

    if (phase == _Phase.flying && progress > .76) {
      _impact(canvas, target, p);
    }
  }

  Offset _quadratic(Offset a, Offset b, Offset c, double t) {
    final u = 1 - t;
    return Offset(
      u * u * a.dx + 2 * u * t * b.dx + t * t * c.dx,
      u * u * a.dy + 2 * u * t * b.dy + t * t * c.dy,
    );
  }

  void _stadiumLights(Canvas canvas, Size size, Paint p) {
    for (var i = 0; i < 70; i++) {
      final x = (i * 53.0) % size.width;
      final row = i % 5;
      final y = 15 + row * 12.0;
      final pulse = .45 + .45 * math.sin(ambient * math.pi * 2 + i * .73);
      p.color = Color.lerp(const Color(0xFF7AD7FF), const Color(0xFFFFE08A), pulse)!;
      canvas.drawCircle(Offset(x, y), 1.5 + pulse, p);
    }
    p.color = Colors.white.withOpacity(.06);
    canvas.drawOval(Rect.fromCenter(center: Offset(size.width * .5, size.height * .25), width: size.width * .9, height: size.height * .28), p);
  }

  void _pitch(Canvas canvas, Size size, Paint p) {
    final field = Path()
      ..moveTo(size.width * .03, size.height)
      ..lineTo(size.width * .97, size.height)
      ..lineTo(size.width * .78, size.height * .43)
      ..lineTo(size.width * .22, size.height * .43)
      ..close();
    p.color = const Color(0xFF128354);
    p.style = PaintingStyle.fill;
    canvas.drawPath(field, p);
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 2;
    p.color = Colors.white70;
    canvas.drawPath(field, p);
    canvas.drawOval(Rect.fromCenter(center: Offset(size.width * .5, size.height * .81), width: size.width * .018, height: size.width * .009), p);
  }

  void _goal(Canvas canvas, Paint p) {
    p.style = PaintingStyle.fill;
    p.color = const Color(0x99121B24);
    canvas.drawRect(goalRect, p);
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 5.2;
    p.color = Colors.white;
    canvas.drawRect(goalRect, p);
    p.strokeWidth = .85;
    p.color = Colors.white30;
    for (var i = 1; i < 12; i++) {
      final x = goalRect.left + goalRect.width * i / 12;
      canvas.drawLine(Offset(x, goalRect.top), Offset(x, goalRect.bottom), p);
    }
    for (var i = 1; i < 7; i++) {
      final y = goalRect.top + goalRect.height * i / 7;
      canvas.drawLine(Offset(goalRect.left, y), Offset(goalRect.right, y), p);
    }
  }

  void _keeperBody(Canvas canvas, Offset c, double dive, Paint p, Size size) {
    final s = size.width * .050;
    final lean = (keeper.dx - .5) * 1.2;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(lean * dive);
    p.style = PaintingStyle.stroke;
    p.strokeCap = StrokeCap.round;
    p.strokeWidth = s * .36;
    p.color = const Color(0xFFFFB703);
    canvas.drawLine(Offset(0, -s * .85), Offset(0, s * .9), p);
    canvas.drawLine(Offset(0, -s * .35), Offset(-s * (1.35 + dive * .35), -s * .05), p);
    canvas.drawLine(Offset(0, -s * .35), Offset(s * (1.35 + dive * .35), -s * .05), p);
    p.color = const Color(0xFF152D40);
    canvas.drawLine(Offset(0, s * .85), Offset(-s * .7, s * 1.65), p);
    canvas.drawLine(Offset(0, s * .85), Offset(s * .7, s * 1.65), p);
    p.style = PaintingStyle.fill;
    p.color = const Color(0xFFFFD2A6);
    canvas.drawCircle(Offset(0, -s * 1.35), s * .48, p);
    p.color = Colors.white;
    canvas.drawCircle(Offset(-s * (1.48 + dive * .35), -s * .05), s * .28, p);
    canvas.drawCircle(Offset(s * (1.48 + dive * .35), -s * .05), s * .28, p);
    canvas.restore();
  }

  void _ball(Canvas canvas, Offset c, double r, Paint p, double spin) {
    p.style = PaintingStyle.fill;
    p.color = Colors.black.withOpacity(.28);
    canvas.drawOval(Rect.fromCenter(center: c + Offset(2, r * .45), width: r * 2.1, height: r * .65), p);
    p.color = Colors.white;
    canvas.drawCircle(c, r, p);
    p.color = const Color(0xFF101820);
    canvas.drawCircle(c, r * .31, p);
    for (var i = 0; i < 5; i++) {
      final a = spin + i * math.pi * 2 / 5;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r * .62, r * .14, p);
    }
  }

  void _powerMeter(Canvas canvas, Size size, Paint p) {
    final w = size.width * .55;
    final rect = Rect.fromCenter(center: Offset(size.width * .5, size.height * .93), width: w, height: 13);
    p.style = PaintingStyle.fill;
    p.color = Colors.black54;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), p);
    final fill = Rect.fromLTWH(rect.left, rect.top, rect.width * power, rect.height);
    p.color = power > .92 ? Colors.redAccent : const Color(0xFFFFD166);
    canvas.drawRRect(RRect.fromRectAndRadius(fill, const Radius.circular(8)), p);
  }

  void _impact(Canvas canvas, Offset target, Paint p) {
    final t = ((progress - .76) / .24).clamp(0.0, 1.0);
    if (outcome == _Outcome.goal) {
      p.style = PaintingStyle.stroke;
      p.strokeWidth = 2.5;
      p.color = Colors.white.withOpacity((1 - t) * .55);
      canvas.drawCircle(target, 18 + t * 24, p);
    } else if (outcome == _Outcome.post) {
      p.style = PaintingStyle.fill;
      p.color = const Color(0xFFFFD166).withOpacity(1 - t);
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        final a0 = target + Offset(math.cos(a), math.sin(a)) * 9;
        final a1 = target + Offset(math.cos(a), math.sin(a)) * (18 + t * 20);
        canvas.drawLine(a0, a1, p..strokeWidth = 2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ElitePenaltyPainter oldDelegate) => true;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
