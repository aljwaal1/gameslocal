import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/local_network_core.dart';
import '../../core/network/network_message.dart';

enum _PenaltyPhase { menu, shooting, saving, animating, finished }

class ChampionsPenaltyGameScreen extends StatefulWidget {
  const ChampionsPenaltyGameScreen({super.key, this.networkCore});

  final LocalNetworkCore? networkCore;

  @override
  State<ChampionsPenaltyGameScreen> createState() =>
      _ChampionsPenaltyGameScreenState();
}

class _ChampionsPenaltyGameScreenState extends State<ChampionsPenaltyGameScreen>
    with TickerProviderStateMixin {
  final math.Random _random = math.Random();
  StreamSubscription<NetworkMessage>? _networkSub;
  late final AnimationController _shotController;
  late final AnimationController _crowdController;

  _PenaltyPhase _phase = _PenaltyPhase.menu;
  Offset _aim = const Offset(0.5, 0.32);
  Offset _keeper = const Offset(0.5, 0.55);
  Offset _dragStart = Offset.zero;
  double _power = 0.72;
  bool _dragging = false;
  bool _lastGoal = false;
  bool _isRobotMatch = true;
  bool _connectionLost = false;

  int _turn = 0;
  int _playerOneGoals = 0;
  int _playerTwoGoals = 0;
  int _playerOneShots = 0;
  int _playerTwoShots = 0;
  final List<bool> _playerOneResults = <bool>[];
  final List<bool> _playerTwoResults = <bool>[];

  String _message = 'اختر نمط المباراة';

  bool get _networkGame => widget.networkCore != null;
  bool get _isHost => widget.networkCore?.state.mode == LocalNetworkMode.host;
  bool get _localNetworkTurn => !_networkGame || (_turn.isEven == _isHost);
  bool get _playerOneTurn => _turn.isEven;

  String get _localId {
    final players = widget.networkCore?.state.players ?? const <LocalPlayer>[];
    final matching = players.where((p) => p.isHost == _isHost);
    return matching.isNotEmpty
        ? matching.first.id
        : (_isHost ? 'host' : 'guest');
  }

  bool get _finished {
    if (_playerOneShots < 5 || _playerTwoShots < 5) return false;
    return _playerOneGoals != _playerTwoGoals;
  }

  @override
  void initState() {
    super.initState();
    _shotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    );
    _crowdController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    if (_networkGame) {
      _networkSub = widget.networkCore!.messages.listen(_onNetworkMessage);
    }
  }

  @override
  void dispose() {
    _networkSub?.cancel();
    _shotController.dispose();
    _crowdController.dispose();
    super.dispose();
  }

  void _start(bool robot) {
    setState(() {
      _isRobotMatch = robot;
      _turn = 0;
      _playerOneGoals = 0;
      _playerTwoGoals = 0;
      _playerOneShots = 0;
      _playerTwoShots = 0;
      _playerOneResults.clear();
      _playerTwoResults.clear();
      _connectionLost = false;
      _phase = _PenaltyPhase.shooting;
      _message = 'اسحب من الكرة نحو زاوية المرمى';
      _aim = const Offset(0.5, 0.32);
      _keeper = const Offset(0.5, 0.55);
      _power = 0.72;
    });
    HapticFeedback.mediumImpact();
  }

  int _zone(Offset point) {
    final x = (point.dx.clamp(0.0, 0.999) * 3).floor();
    final y = (point.dy.clamp(0.0, 0.999) * 3).floor();
    return y * 3 + x;
  }

  Offset _zoneCenter(int zone) {
    return Offset((zone % 3 + 0.5) / 3, (zone ~/ 3 + 0.5) / 3);
  }

  void _dragBegin(DragStartDetails details, Size size) {
    if (_phase != _PenaltyPhase.shooting || !_canAct) return;
    _dragStart = details.localPosition;
    _dragging = true;
  }

  void _dragUpdate(DragUpdateDetails details, Size size) {
    if (!_dragging || _phase != _PenaltyPhase.shooting) return;
    final position = details.localPosition;
    final goalLeft = size.width * 0.13;
    final goalRight = size.width * 0.87;
    final goalTop = size.height * 0.13;
    final goalBottom = size.height * 0.49;
    final normalized = Offset(
      ((position.dx - goalLeft) / (goalRight - goalLeft)).clamp(0.02, 0.98),
      ((position.dy - goalTop) / (goalBottom - goalTop)).clamp(0.03, 0.97),
    );
    final distance = (_dragStart - position).distance;
    setState(() {
      _aim = normalized;
      _power = (0.48 + distance / (size.height * 0.44)).clamp(0.48, 1.0);
    });
  }

  void _dragEnd(DragEndDetails details) {
    if (!_dragging || _phase != _PenaltyPhase.shooting) return;
    _dragging = false;
    _takeShot(_aim, _power);
  }

  bool get _canAct {
    if (_connectionLost) return false;
    if (_networkGame) return _localNetworkTurn;
    return true;
  }

  Future<void> _takeShot(Offset target, double power) async {
    if (_phase != _PenaltyPhase.shooting || !_canAct) return;

    final keeperZone = _robotKeeperZone(target, power);
    final keeper = _zoneCenter(keeperZone);
    final shotZone = _zone(target);
    final accuracyError =
        (1.0 - power).abs() * 0.08 + (power > 0.92 ? 0.06 : 0.0);
    final actualTarget = Offset(
      (target.dx + (_random.nextDouble() - 0.5) * accuracyError)
          .clamp(0.01, 0.99),
      (target.dy + (_random.nextDouble() - 0.5) * accuracyError)
          .clamp(0.01, 0.99),
    );
    final distance = (actualTarget - keeper).distance;
    final saved = shotZone == keeperZone &&
        _random.nextDouble() < (0.70 - power * 0.22).clamp(0.30, 0.58);
    final offTarget = power > 0.96 && _random.nextDouble() < 0.13;
    final goal = !saved && !offTarget && distance > 0.07;
    final shotTurn = _turn;

    await _animateShot(
      target: actualTarget,
      keeper: keeper,
      power: power,
      goal: goal,
      shooterIsLocal: true,
    );

    if (_networkGame) {
      widget.networkCore!.sendMove(<String, dynamic>{
        'action': 'championsPenaltyShot',
        'turn': shotTurn,
        'targetX': actualTarget.dx,
        'targetY': actualTarget.dy,
        'keeperX': keeper.dx,
        'keeperY': keeper.dy,
        'power': power,
        'goal': goal,
      }, senderId: _localId);
    }
  }

  int _robotKeeperZone(Offset target, double power) {
    final readChance = (0.18 + (1.0 - power) * 0.25).clamp(0.18, 0.40);
    if (_random.nextDouble() < readChance) return _zone(target);
    return _random.nextInt(9);
  }

  Future<void> _animateShot({
    required Offset target,
    required Offset keeper,
    required double power,
    required bool goal,
    required bool shooterIsLocal,
  }) async {
    if (!mounted) return;
    setState(() {
      _phase = _PenaltyPhase.animating;
      _aim = target;
      _keeper = keeper;
      _power = power;
      _lastGoal = goal;
      _message = shooterIsLocal ? 'تسديدة قوية...' : 'المنافس يسدد...';
    });
    HapticFeedback.lightImpact();
    await _shotController.forward(from: 0);
    if (!mounted) return;

    setState(() {
      if (_playerOneTurn) {
        _playerOneShots++;
        _playerOneResults.add(goal);
        if (goal) _playerOneGoals++;
      } else {
        _playerTwoShots++;
        _playerTwoResults.add(goal);
        if (goal) _playerTwoGoals++;
      }
      _turn++;
      _message = goal ? 'هــــدف عالمي!' : 'الحارس يتصدى!';
    });

    if (goal) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    } else {
      HapticFeedback.mediumImpact();
    }

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    _shotController.reset();

    if (_finished) {
      setState(() {
        _phase = _PenaltyPhase.finished;
        _message = _playerOneGoals > _playerTwoGoals
            ? '🏆 فاز اللاعب الأول'
            : '🏆 فاز ${_isRobotMatch ? 'الروبوت' : 'اللاعب الثاني'}';
      });
      return;
    }

    if (!_networkGame && _isRobotMatch && _turn.isOdd) {
      setState(() {
        _phase = _PenaltyPhase.saving;
        _message = 'أنت الحارس: اضغط جهة القفز';
      });
    } else {
      setState(() {
        _phase = _PenaltyPhase.shooting;
        _message = _networkGame && !_localNetworkTurn
            ? 'بانتظار تسديدة اللاعب الآخر'
            : 'اسحب من الكرة نحو زاوية المرمى';
      });
    }
  }

  Future<void> _chooseDive(Offset normalized) async {
    if (_phase != _PenaltyPhase.saving) return;
    final diveZone = _zone(normalized);
    setState(() {
      _keeper = _zoneCenter(diveZone);
      _message = 'الحارس يقفز...';
    });
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    final robotTargetZone = _random.nextInt(9);
    final target = _zoneCenter(robotTargetZone) +
        Offset(
          (_random.nextDouble() - 0.5) * 0.10,
          (_random.nextDouble() - 0.5) * 0.08,
        );
    final power = 0.67 + _random.nextDouble() * 0.30;
    final saved = diveZone == robotTargetZone && _random.nextDouble() < 0.72;
    final goal = !saved;

    await _animateShot(
      target: target,
      keeper: _zoneCenter(diveZone),
      power: power,
      goal: goal,
      shooterIsLocal: false,
    );
  }

  void _onNetworkMessage(NetworkMessage message) {
    if (!mounted || message.senderId == _localId) return;
    if (message.type == NetworkMessageType.disconnect) {
      setState(() {
        _connectionLost = true;
        _message = 'انقطع اتصال اللاعب الآخر';
      });
      return;
    }
    if (message.type != NetworkMessageType.move) return;
    if (message.payload['action'] != 'championsPenaltyShot') return;
    final turn = (message.payload['turn'] as num?)?.toInt();
    if (turn != _turn) return;
    final tx = (message.payload['targetX'] as num?)?.toDouble();
    final ty = (message.payload['targetY'] as num?)?.toDouble();
    final kx = (message.payload['keeperX'] as num?)?.toDouble();
    final ky = (message.payload['keeperY'] as num?)?.toDouble();
    final power = (message.payload['power'] as num?)?.toDouble();
    final goal = message.payload['goal'];
    if (tx == null ||
        ty == null ||
        kx == null ||
        ky == null ||
        power == null ||
        goal is! bool) return;
    unawaited(_animateShot(
      target: Offset(tx, ty),
      keeper: Offset(kx, ky),
      power: power,
      goal: goal,
      shooterIsLocal: false,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF03070D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF081521),
        foregroundColor: Colors.white,
        title: const Text('ركلات الأبطال'),
        actions: <Widget>[
          IconButton(
            onPressed: _phase == _PenaltyPhase.menu
                ? null
                : () => setState(() => _phase = _PenaltyPhase.menu),
            icon: const Icon(Icons.home_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _phase == _PenaltyPhase.menu ? _menu() : _game(),
      ),
    );
  }

  Widget _menu() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF102F4A), Color(0xFF087F5B)],
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                  color: Colors.black54, blurRadius: 22, offset: Offset(0, 10)),
            ],
          ),
          child: const Column(
            children: <Widget>[
              Icon(Icons.sports_soccer, size: 86, color: Color(0xFFFFD166)),
              SizedBox(height: 12),
              Text(
                'ركلات الأبطال',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 31,
                    fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 7),
              Text(
                'سحب للتسديد • قوة ودقة • تحكم بالحارس • حسم مفاجئ',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (!_networkGame)
          _modeButton(
            icon: Icons.smart_toy_rounded,
            title: 'ضد الروبوت',
            subtitle: 'سدّد ثم العب كحارس واختر جهة القفز',
            onTap: () => _start(true),
          ),
        if (!_networkGame) const SizedBox(height: 12),
        _modeButton(
          icon: Icons.people_alt_rounded,
          title: _networkGame ? 'ابدأ مباراة اللاعبين' : 'لاعبان على الشبكة',
          subtitle: 'خمس ركلات لكل لاعب ثم الحسم المفاجئ',
          onTap: () => _start(false),
        ),
      ],
    );
  }

  Widget _modeButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF0D1B28),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF163248),
                child: Icon(icon, color: const Color(0xFFFFD166), size: 31),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }

  Widget _game() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 18),
          children: <Widget>[
            _scoreboard(),
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _lastGoal && _phase == _PenaltyPhase.animating
                    ? const Color(0xFF0E9F6E)
                    : const Color(0xFF0D1B28),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16),
              ),
            ),
            const SizedBox(height: 9),
            AspectRatio(
              aspectRatio: 0.78,
              child: LayoutBuilder(
                builder: (context, fieldConstraints) {
                  final size = fieldConstraints.biggest;
                  return GestureDetector(
                    onPanStart: (d) => _dragBegin(d, size),
                    onPanUpdate: (d) => _dragUpdate(d, size),
                    onPanEnd: _dragEnd,
                    onTapDown: (d) {
                      if (_phase != _PenaltyPhase.saving) return;
                      final point = Offset(
                        (d.localPosition.dx / size.width).clamp(0.0, 1.0),
                        (d.localPosition.dy / (size.height * 0.58))
                            .clamp(0.0, 1.0),
                      );
                      _chooseDive(point);
                    },
                    child: AnimatedBuilder(
                      animation: Listenable.merge(
                          <Listenable>[_shotController, _crowdController]),
                      builder: (context, _) => CustomPaint(
                        painter: _ChampionsPenaltyPainter(
                          shotProgress: _shotController.value,
                          crowdProgress: _crowdController.value,
                          aim: _aim,
                          keeper: _keeper,
                          power: _power,
                          phase: _phase,
                          goal: _lastGoal,
                          dragging: _dragging,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            if (_phase == _PenaltyPhase.shooting)
              const Text(
                'ابدأ السحب من الكرة إلى المكان الذي تريد التسديد نحوه. طول السحب يحدد القوة.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            if (_phase == _PenaltyPhase.saving)
              const Text(
                'اضغط داخل المرمى لاختيار جهة قفز الحارس قبل تسديدة الروبوت.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Color(0xFFFFD166),
                    fontSize: 13,
                    fontWeight: FontWeight.w800),
              ),
            if (_phase == _PenaltyPhase.finished) ...<Widget>[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => _start(_isRobotMatch),
                icon: const Icon(Icons.replay),
                label: const Text('إعادة المباراة'),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _scoreboard() {
    Widget side(String name, int goals, List<bool> results) {
      return Expanded(
        child: Column(
          children: <Widget>[
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900)),
            Text('$goals',
                style: const TextStyle(
                    color: Color(0xFFFFD166),
                    fontSize: 28,
                    fontWeight: FontWeight.w900)),
            Wrap(
              spacing: 2,
              children: <Widget>[
                for (final result in results)
                  Icon(result ? Icons.check_circle : Icons.cancel,
                      size: 14,
                      color: result ? Colors.greenAccent : Colors.redAccent),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: <Widget>[
          side('اللاعب 1', _playerOneGoals, _playerOneResults),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('VS',
                style: TextStyle(
                    color: Color(0xFFFFD166), fontWeight: FontWeight.w900)),
          ),
          side(_isRobotMatch ? 'الروبوت' : 'اللاعب 2', _playerTwoGoals,
              _playerTwoResults),
        ],
      ),
    );
  }
}

class _ChampionsPenaltyPainter extends CustomPainter {
  const _ChampionsPenaltyPainter({
    required this.shotProgress,
    required this.crowdProgress,
    required this.aim,
    required this.keeper,
    required this.power,
    required this.phase,
    required this.goal,
    required this.dragging,
  });

  final double shotProgress;
  final double crowdProgress;
  final Offset aim;
  final Offset keeper;
  final double power;
  final _PenaltyPhase phase;
  final bool goal;
  final bool dragging;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    final stadium = Rect.fromLTWH(0, 0, size.width, size.height);
    paint.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xFF07121E), Color(0xFF12334B), Color(0xFF0A5D3E)],
    ).createShader(stadium);
    canvas.drawRRect(
        RRect.fromRectAndRadius(stadium, const Radius.circular(24)), paint);

    paint.shader = null;
    for (var i = 0; i < 80; i++) {
      final x = (i * 47.0) % size.width;
      final y = 18 + (i % 5) * 12.0;
      final pulse = 0.45 + 0.45 * math.sin(crowdProgress * math.pi * 2 + i);
      paint.color =
          Color.lerp(const Color(0xFF5AB0D8), const Color(0xFFFFD166), pulse)!;
      canvas.drawCircle(Offset(x, y), 1.6, paint);
    }

    final field = Path()
      ..moveTo(size.width * 0.04, size.height)
      ..lineTo(size.width * 0.96, size.height)
      ..lineTo(size.width * 0.78, size.height * 0.46)
      ..lineTo(size.width * 0.22, size.height * 0.46)
      ..close();
    paint.color = const Color(0xFF11845B);
    canvas.drawPath(field, paint);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    paint.color = Colors.white70;
    canvas.drawPath(field, paint);

    final goalRect = Rect.fromLTRB(
      size.width * 0.13,
      size.height * 0.13,
      size.width * 0.87,
      size.height * 0.49,
    );
    paint.style = PaintingStyle.fill;
    paint.color = const Color(0x55101924);
    canvas.drawRect(goalRect, paint);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 5;
    paint.color = Colors.white;
    canvas.drawRect(goalRect, paint);
    paint.strokeWidth = 1;
    paint.color = Colors.white38;
    for (var i = 1; i < 8; i++) {
      final x = goalRect.left + goalRect.width * i / 8;
      canvas.drawLine(
          Offset(x, goalRect.top), Offset(x, goalRect.bottom), paint);
    }
    for (var i = 1; i < 5; i++) {
      final y = goalRect.top + goalRect.height * i / 5;
      canvas.drawLine(
          Offset(goalRect.left, y), Offset(goalRect.right, y), paint);
    }

    final keeperPoint = Offset(
      goalRect.left + keeper.dx * goalRect.width,
      goalRect.top + keeper.dy * goalRect.height,
    );
    final keeperT = Curves.easeOut.transform(shotProgress);
    final displayedKeeper = Offset.lerp(goalRect.center, keeperPoint, keeperT)!;
    _drawKeeper(canvas, displayedKeeper, size.width * 0.055, paint);

    final ballStart = Offset(size.width * 0.5, size.height * 0.84);
    final ballTarget = Offset(
      goalRect.left + aim.dx * goalRect.width,
      goalRect.top + aim.dy * goalRect.height,
    );
    final shotT = Curves.easeInCubic.transform(shotProgress);
    final ballPosition = Offset.lerp(ballStart, ballTarget, shotT)!;
    final radius = math.max(5.0, size.width * 0.045 * (1 - shotT * 0.72));
    _drawBall(canvas, ballPosition, radius, paint);

    if (phase == _PenaltyPhase.shooting && dragging) {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2.5;
      paint.color = const Color(0xFFFFD166);
      canvas.drawCircle(ballTarget, 16, paint);
      canvas.drawLine(ballStart, ballTarget, paint);
      paint.style = PaintingStyle.fill;
      paint.color = const Color(0xCC081521);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(size.width * 0.5, size.height * 0.94),
              width: size.width * 0.55,
              height: 28),
          const Radius.circular(12),
        ),
        paint,
      );
      paint.color = power > 0.92 ? Colors.redAccent : const Color(0xFFFFD166);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.225, size.height * 0.925,
              size.width * 0.55 * power, 10),
          const Radius.circular(6),
        ),
        paint,
      );
    }

    if (phase == _PenaltyPhase.animating && shotProgress > 0.88) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: goal ? 'GOAL!' : 'SAVE!',
          style: TextStyle(
            color: goal ? const Color(0xFFFFD166) : Colors.white,
            fontSize: size.width * 0.12,
            fontWeight: FontWeight.w900,
            shadows: const <Shadow>[
              Shadow(color: Colors.black, blurRadius: 12)
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas,
          Offset((size.width - textPainter.width) / 2, size.height * 0.53));
    }
  }

  void _drawKeeper(Canvas canvas, Offset center, double scale, Paint paint) {
    paint.style = PaintingStyle.stroke;
    paint.strokeCap = StrokeCap.round;
    paint.strokeWidth = scale * 0.32;
    paint.color = const Color(0xFFFFB703);
    canvas.drawLine(
        center + Offset(0, -scale), center + Offset(0, scale), paint);
    canvas.drawLine(center + Offset(0, -scale * 0.45),
        center + Offset(-scale * 1.35, 0), paint);
    canvas.drawLine(center + Offset(0, -scale * 0.45),
        center + Offset(scale * 1.35, 0), paint);
    canvas.drawLine(center + Offset(0, scale),
        center + Offset(-scale * 0.72, scale * 1.75), paint);
    canvas.drawLine(center + Offset(0, scale),
        center + Offset(scale * 0.72, scale * 1.75), paint);
    paint.style = PaintingStyle.fill;
    paint.color = const Color(0xFFFFD6A5);
    canvas.drawCircle(center + Offset(0, -scale * 1.55), scale * 0.48, paint);
  }

  void _drawBall(Canvas canvas, Offset center, double radius, Paint paint) {
    paint.style = PaintingStyle.fill;
    paint.color = Colors.white;
    canvas.drawCircle(center, radius, paint);
    paint.color = const Color(0xFF101820);
    canvas.drawCircle(center, radius * 0.33, paint);
    for (var i = 0; i < 5; i++) {
      final angle = i * math.pi * 2 / 5;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.62,
        radius * 0.16,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChampionsPenaltyPainter oldDelegate) => true;
}
