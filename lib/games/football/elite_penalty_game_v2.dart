import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio_feedback.dart';
import '../../core/network/local_network_core.dart';
import '../../core/network/network_message.dart';
import 'penalty_actor_painter.dart';
import 'penalty_motion_timeline.dart';
import 'penalty_rules.dart';

class ChampionsPenaltyGameScreen extends StatelessWidget {
  const ChampionsPenaltyGameScreen({super.key, this.networkCore});
  final LocalNetworkCore? networkCore;

  @override
  Widget build(BuildContext context) => _ElitePenaltyGame(
        networkCore: networkCore,
        title: 'ركلات الأبطال',
        subtitle: 'تسديد وتحكم بالحارس',
        actionName: 'eliteChampionsPenaltyV2',
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
        actionName: 'eliteProPenaltyV2',
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
    with TickerProviderStateMixin, WidgetsBindingObserver {
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
  GameFeedbackCancellation? _shotFeedback;
  bool _contactEmitted = false;
  bool _arrivalEmitted = false;
  int _generation = 0;
  bool _lifecyclePaused = false;
  bool _keeperDragActive = false;
  ({
    int turn,
    Offset target,
    Offset keeper,
    double power,
    double curve,
    _Outcome outcome
  })? _pendingShot;
  PenaltyActorPainter? _actors;
  final List<_Outcome> _leftResults = <_Outcome>[];
  final List<_Outcome> _rightResults = <_Outcome>[];
  String _message = 'اسحب من الكرة إلى زاوية المرمى';

  bool get _network => widget.networkCore != null;
  bool get _isHost => widget.networkCore?.state.mode == LocalNetworkMode.host;
  bool get _localTurn => !_network || (_turn.isEven == _isHost);
  bool get _leftTurn => _turn.isEven;

  bool get _finished => PenaltyRules.isFinished(
        playerGoals: _leftGoals,
        robotGoals: _rightGoals,
        playerShots: _leftShots,
        robotShots: _rightShots,
      );

  String get _localId {
    final players = widget.networkCore?.state.players ?? const <LocalPlayer>[];
    final own = players.where((player) => player.isHost == _isHost);
    return own.isNotEmpty ? own.first.id : (_isHost ? 'host' : 'guest');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(PenaltyActorPainter.load().then((actors) {
      if (mounted) setState(() => _actors = actors);
    }));
    _shot = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1650),
    );
    _shot.addListener(_onShotTick);
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
    _pendingShot = null;
    _shotFeedback?.cancel();
    _shotFeedback = null;
    WidgetsBinding.instance.removeObserver(this);
    _cancelShot();
    _networkSub?.cancel();
    _shot.dispose();
    _stadium.dispose();
    super.dispose();
  }

  void _reset() {
    _pendingShot = null;
    _cancelShot();
    _shotFeedback = null;
    _dragStart = null;
    _dragNow = null;
    _keeperDragActive = false;
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

  Rect _goalRect(Size size) => Rect.fromLTRB(
        size.width * .105,
        size.height * .115,
        size.width * .895,
        size.height * .455,
      );

  void _beginDrag(DragStartDetails details, Size size) {
    if (_lifecyclePaused ||
        _phase != _Phase.ready ||
        !_localTurn ||
        _connectionLost) {
      return;
    }
    final ball = Offset(size.width * .5, size.height * .80);
    if ((details.localPosition - ball).distance > size.width * .20) {
      return;
    }
    setState(() {
      _phase = _Phase.shooting;
      _dragStart = details.localPosition;
      _dragNow = details.localPosition;
    });
    GameFeedback.selection();
  }

  void _updateDrag(DragUpdateDetails details, Size size) {
    if (_lifecyclePaused ||
        _connectionLost ||
        _phase != _Phase.shooting ||
        _dragStart == null) {
      return;
    }
    final p = details.localPosition;
    final goal = _goalRect(size);
    final raw = p - _dragStart!;
    final distance = raw.distance;
    setState(() {
      _dragNow = p;
      _aim = Offset(
        ((p.dx - goal.left) / goal.width).clamp(.015, .985).toDouble(),
        ((p.dy - goal.top) / goal.height).clamp(.025, .975).toDouble(),
      );
      _power =
          (.38 + distance / (size.height * .43)).clamp(.42, 1.0).toDouble();
      _curve = (raw.dx / (size.width * .55)).clamp(-1.0, 1.0).toDouble();
    });
  }

  void _endDrag(DragEndDetails details) {
    if (_lifecyclePaused ||
        _connectionLost ||
        _phase != _Phase.shooting ||
        _dragStart == null) {
      return;
    }
    _dragStart = null;
    _dragNow = null;
    unawaited(_takeShot(_aim, _power, _curve, local: true));
  }

  Future<void> _takeShot(
    Offset requested,
    double power,
    double curve, {
    required bool local,
  }) async {
    if (_lifecyclePaused ||
        _connectionLost ||
        (local && !_localTurn) ||
        (_phase != _Phase.shooting && _phase != _Phase.ready)) {
      return;
    }

    final overPower = ((power - .90) / .10).clamp(0.0, 1.0).toDouble();
    final underPower = ((.58 - power) / .16).clamp(0.0, 1.0).toDouble();
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
            (actual.dx + (_random.nextDouble() - .5) * .12)
                .clamp(.06, .94)
                .toDouble(),
            (actual.dy + (_random.nextDouble() - .5) * .14)
                .clamp(.08, .88)
                .toDouble(),
          )
        : Offset(
            .10 + _random.nextDouble() * .80,
            .12 + _random.nextDouble() * .70,
          );

    final reach = .165 + (1 - power) * .055;
    final saveDistance = (actual - predicted).distance;
    final saveChance = saveDistance < reach
        ? (.76 - power * .20).clamp(.38, .64).toDouble()
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
    await _animate(
      target: Offset(
        actual.dx.clamp(-.06, 1.06).toDouble(),
        actual.dy.clamp(-.05, 1.03).toDouble(),
      ),
      keeper: predicted,
      power: power,
      curve: curve,
      outcome: outcome,
      local: local,
    );
  }

  void _cancelShot() {
    _generation++;
    _shotFeedback?.cancel();
    _shot.stop(canceled: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_lifecyclePaused) {
        return;
      }
      _lifecyclePaused = false;
      if (_connectionLost) {
        return;
      }
      final feedback = _shotFeedback;
      if (feedback != null &&
          (_phase == _Phase.flying || _phase == _Phase.result)) {
        // Keep the resolved, already-sent turn. Its cancelled feedback lifetime
        // remains silent while its presentation catches up after foregrounding.
        unawaited(_continueShot(_generation, feedback));
      } else {
        _drainPendingShot();
      }
      return;
    }
    if (_lifecyclePaused) {
      return;
    }
    _lifecyclePaused = true;
    _dragStart = null;
    _dragNow = null;
    _keeperDragActive = false;
    if (_phase == _Phase.shooting && !_connectionLost) {
      setState(() {
        _phase = _Phase.ready;
        _message = 'اسحب من الكرة إلى زاوية المرمى';
      });
    }
    _cancelShot();
  }

  void _onShotTick() {
    if (!mounted ||
        _connectionLost ||
        _lifecyclePaused ||
        _shotFeedback == null) {
      return;
    }
    if (!_contactEmitted && _shot.value >= PenaltyMotionTimeline.contactStart) {
      _contactEmitted = true;
      GameFeedback.kick(GameAudioTheme.football, _shotFeedback);
    }
    if (_arrivalEmitted || _shot.value < PenaltyMotionTimeline.ballArrival) {
      return;
    }
    _arrivalEmitted = true;
    final wasLeft = _leftTurn;
    setState(() {
      final goal = _outcome == _Outcome.goal;
      if (wasLeft) {
        _leftShots++;
        _leftResults.add(_outcome);
        if (goal) _leftGoals++;
      } else {
        _rightShots++;
        _rightResults.add(_outcome);
        if (goal) _rightGoals++;
      }
      _turn++;
      _phase = _Phase.result;
      _message = switch (_outcome) {
        _Outcome.goal => 'هــــدف! ⚽',
        _Outcome.save => 'تصـــدٍ رائع! 🧤',
        _Outcome.post => 'في القائم! 💥',
        _Outcome.miss => 'خارج المرمى!',
      };
    });

    switch (_outcome) {
      case _Outcome.goal:
        GameFeedback.goal(GameAudioTheme.football, _shotFeedback);
      case _Outcome.save:
        GameFeedback.save(GameAudioTheme.football, _shotFeedback);
      case _Outcome.post:
        GameFeedback.post(GameAudioTheme.football, _shotFeedback);
      case _Outcome.miss:
        GameFeedback.error(GameAudioTheme.football, _shotFeedback);
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
    if (!mounted || _connectionLost || _lifecyclePaused || _finished) {
      return;
    }
    _cancelShot();
    final generation = _generation;
    final feedback = _shotFeedback = GameFeedbackCancellation();
    _contactEmitted = false;
    _arrivalEmitted = false;
    setState(() {
      _phase = _Phase.flying;
      _aim = Offset(target.dx.clamp(-.06, 1.06).toDouble(),
          target.dy.clamp(-.05, 1.03).toDouble());
      _keeper = keeper;
      _power = power;
      _curve = curve;
      _outcome = outcome;
      _message = local ? 'التسديدة تنطلق...' : 'المنافس يسدد...';
    });
    _shot.value = 0;
    await _continueShot(generation, feedback);
  }

  Future<void> _continueShot(
      int generation, GameFeedbackCancellation feedback) async {
    if (!mounted ||
        _connectionLost ||
        _lifecyclePaused ||
        generation != _generation) {
      return;
    }
    try {
      await _shot.forward().orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted ||
        _connectionLost ||
        _lifecyclePaused ||
        generation != _generation) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted ||
        _connectionLost ||
        _lifecyclePaused ||
        generation != _generation) {
      return;
    }
    _shot.reset();

    if (_finished) {
      if (_leftGoals > _rightGoals) {
        GameFeedback.win(GameAudioTheme.football, feedback);
      } else {
        GameFeedback.lose(GameAudioTheme.football, feedback);
      }
      setState(() {
        _phase = _Phase.finished;
        _message =
            _leftGoals > _rightGoals ? '🏆 فاز اللاعب الأول' : '🏆 فاز المنافس';
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
        if (mounted &&
            !_connectionLost &&
            !_lifecyclePaused &&
            generation == _generation) {
          await _robotShot();
        }
      }
    } else {
      setState(() {
        _phase = _Phase.ready;
        _message = _network && !_localTurn
            ? 'بانتظار اللاعب الآخر'
            : 'اسحب من الكرة إلى زاوية المرمى';
      });
      _drainPendingShot();
    }
  }

  Future<void> _robotShot({Offset? forcedKeeper}) async {
    if (!mounted || _connectionLost || _lifecyclePaused) {
      return;
    }
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
    final distance = (actual - forcedKeeper).distance;
    final saved = distance < .19 && _random.nextDouble() < .73;
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

  void _keeperPanEnd(DragEndDetails details) {
    if (_lifecyclePaused ||
        _connectionLost ||
        !_keeperDragActive ||
        _phase != _Phase.saving) {
      return;
    }
    _keeperDragActive = false;
    final velocity = details.velocity.pixelsPerSecond;
    final dx = (velocity.dx / 1300).clamp(-.44, .44).toDouble();
    final dy = (velocity.dy / 1500).clamp(-.34, .25).toDouble();
    final dive = Offset(
      (.5 + dx).clamp(.06, .94).toDouble(),
      (.52 + dy).clamp(.08, .88).toDouble(),
    );
    setState(() {
      _keeper = dive;
      _phase = _Phase.flying;
      _message = 'الحارس يقفز...';
    });
    unawaited(_robotShot(forcedKeeper: dive));
  }

  void _drainPendingShot() {
    final pending = _pendingShot;
    if (!mounted ||
        _connectionLost ||
        _finished ||
        _lifecyclePaused ||
        _phase != _Phase.ready ||
        pending == null ||
        pending.turn != _turn ||
        !_remoteOwnsTurn(pending.turn)) {
      return;
    }
    _pendingShot = null;
    unawaited(_animate(
        target: pending.target,
        keeper: pending.keeper,
        power: pending.power,
        curve: pending.curve,
        outcome: pending.outcome,
        local: false));
  }

  bool _remoteOwnsTurn(int turn) => _network && (turn.isEven != _isHost);

  void _onNetwork(NetworkMessage message) {
    if (!mounted || message.senderId == _localId) {
      return;
    }
    if (message.type == NetworkMessageType.disconnect) {
      _cancelShot();
      _pendingShot = null;
      _shotFeedback = null;
      _dragStart = null;
      _dragNow = null;
      _keeperDragActive = false;
      setState(() {
        _connectionLost = true;
        _phase = _Phase.ready;
        _message = 'انقطع اتصال اللاعب الآخر';
      });
      return;
    }
    if (_connectionLost ||
        _finished ||
        _phase == _Phase.finished ||
        message.type != NetworkMessageType.move ||
        message.payload['action'] != widget.actionName) {
      return;
    }
    final turnValue = message.payload['turn'];
    if (turnValue is! num ||
        !turnValue.isFinite ||
        turnValue < 0 ||
        turnValue != turnValue.roundToDouble()) {
      return;
    }
    final turn = turnValue.toInt();
    final activeShot = _phase == _Phase.flying || _phase == _Phase.result;
    // Before arrival _turn still names the in-flight shot; afterwards it
    // already names the next turn. Only that one next owner can be queued.
    final admissibleTurn = activeShot && !_arrivalEmitted ? _turn + 1 : _turn;
    if (turn != admissibleTurn || !_remoteOwnsTurn(turn)) {
      return;
    }
    double? number(String key, double minimum, double maximum) {
      final value = message.payload[key];
      if (value is! num || !value.isFinite) {
        return null;
      }
      final result = value.toDouble();
      if (result < minimum - 1e-9 || result > maximum + 1e-9) {
        return null;
      }
      return result;
    }

    // A pan without updates retains the preceding displayed aim, clamped by
    // _animate to x=-.06..1.06, y=-.05..1.03. Updated aim is narrower.
    // Maximum skillNoise=.077 adds ±.0385, and curve adds ±.018 to x.
    // Validate the full producer envelope without changing its raw wire values.
    final tx = number('tx', -.1165, 1.1165);
    final ty = number('ty', -.0885, 1.0685);
    final kx = number('kx', .06, .94);
    final ky = number('ky', .08, .88);
    final power = number('power', .42, 1);
    final curve = number('curve', -1, 1);
    final outcomeName = message.payload['outcome'];
    if (tx == null ||
        ty == null ||
        kx == null ||
        ky == null ||
        power == null ||
        curve == null ||
        outcomeName is! String) {
      return;
    }
    _Outcome? outcome;
    for (final value in _Outcome.values) {
      if (value.name == outcomeName) {
        outcome = value;
        break;
      }
    }
    if (outcome == null) {
      return;
    }
    if (_lifecyclePaused || activeShot) {
      // At most one validated next turn is retained while this arena finishes
      // presenting its current turn. No wire protocol or authority changes.
      _pendingShot ??= (
        turn: turn,
        target: Offset(tx, ty),
        keeper: Offset(kx, ky),
        power: power,
        curve: curve,
        outcome: outcome
      );
      return;
    }
    unawaited(_animate(
        target: Offset(tx, ty),
        keeper: Offset(kx, ky),
        power: power,
        curve: curve,
        outcome: outcome,
        local: false));
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
            Text(widget.title,
                style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(widget.subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ],
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _reset,
            tooltip: 'مباراة جديدة',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final score = _ScoreBar(
            leftGoals: _leftGoals,
            rightGoals: _rightGoals,
            left: _leftResults,
            right: _rightResults,
          );
          final message = Padding(
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
                  const Icon(Icons.sports_soccer,
                      color: Color(0xFFFFD166), size: 19),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
          final arena = Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.biggest;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (details) {
                      if (_lifecyclePaused || _connectionLost) return;
                      if (_phase == _Phase.saving) {
                        _keeperDragActive = true;
                      } else {
                        _beginDrag(details, size);
                      }
                    },
                    onPanUpdate: (details) => _updateDrag(details, size),
                    onPanEnd: (details) {
                      if (_phase == _Phase.saving) {
                        _keeperPanEnd(details);
                      } else {
                        _endDrag(details);
                      }
                    },
                    child: AnimatedBuilder(
                      animation:
                          Listenable.merge(<Listenable>[_shot, _stadium]),
                      builder: (context, _) => CustomPaint(
                        painter: _ElitePenaltyPainter(
                          actors: _actors,
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
          );
          final finish = <Widget>[
            if (_phase == _Phase.finished)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: FilledButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('مباراة جديدة'),
                ),
              )
          ];
          if (constraints.maxWidth > constraints.maxHeight * 1.3) {
            return Row(children: [
              arena,
              SizedBox(
                  width: math.min(280, constraints.maxWidth * .44),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [score, message, ...finish])),
            ]);
          }
          return Column(children: [score, message, arena, ...finish]);
        }),
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
          Expanded(child: _side('اللاعب 1', left)),
          Text(
            '$leftGoals  -  $rightGoals',
            style: const TextStyle(
              color: Color(0xFFFFD166),
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          Expanded(child: _side('المنافس', right)),
        ],
      ),
    );
  }

  Widget _side(String name, List<_Outcome> results) {
    return Column(
      children: <Widget>[
        Text(name,
            style: const TextStyle(
                color: Colors.white70, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Wrap(
          spacing: 1,
          children: results
              .map((result) => Icon(
                    result == _Outcome.goal
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    size: 14,
                    color: result == _Outcome.goal
                        ? Colors.greenAccent
                        : Colors.redAccent,
                  ))
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _ElitePenaltyPainter extends CustomPainter {
  const _ElitePenaltyPainter({
    required this.actors,
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

  final PenaltyActorPainter? actors;
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
    final paint = Paint()..isAntiAlias = true;
    final whole = Offset.zero & size;
    paint.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        Color(0xFF02050A),
        Color(0xFF0A2030),
        Color(0xFF0A6648),
      ],
      stops: <double>[0, .42, 1],
    ).createShader(whole);
    canvas.drawRRect(
      RRect.fromRectAndRadius(whole, const Radius.circular(24)),
      paint,
    );
    paint.shader = null;

    _stadiumLights(canvas, size, paint);
    _pitch(canvas, size, paint);
    _goal(canvas, paint);

    final target = Offset(
      goalRect.left + aim.dx * goalRect.width,
      goalRect.top + aim.dy * goalRect.height,
    );
    final frame = const PenaltyMotionTimeline().frame(progress);
    final layout = PenaltyActorLayout(
        size: size, goal: goalRect, keeperTarget: keeper, frame: frame);
    actors?.paintKeeper(canvas, layout);
    actors?.paintPlayer(canvas, layout);

    final ballStart = Offset(size.width * .5, size.height * .80);
    final flight = frame.ballFlight;
    final mid = Offset(size.width * (.5 + curve * .055), size.height * .48);
    final ballPos = _quadratic(ballStart, mid, target, flight);
    final radius = math.max(3.0,
        math.min(size.height * .045, size.width * .047) * (1 - flight * .74));

    if (flight > .03) {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2.2;
      paint.color = Colors.white.withOpacity(.18 * (1 - flight));
      final trail = Path()
        ..moveTo(ballStart.dx, ballStart.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, ballPos.dx, ballPos.dy);
      canvas.drawPath(trail, paint);
    }
    _ball(canvas, ballPos, radius, paint, flight * 12);

    if (phase == _Phase.shooting && dragPoint != null) {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2.4;
      paint.color = const Color(0xFFFFD166);
      canvas.drawLine(ballStart, dragPoint!, paint);
      canvas.drawCircle(target, 17, paint);
      _powerMeter(canvas, size, paint);
    }

    if ((phase == _Phase.flying || phase == _Phase.result) &&
        progress >= PenaltyMotionTimeline.ballArrival) {
      _impact(canvas, target, paint);
    }
  }

  Offset _quadratic(Offset a, Offset b, Offset c, double t) {
    final u = 1 - t;
    return Offset(
      u * u * a.dx + 2 * u * t * b.dx + t * t * c.dx,
      u * u * a.dy + 2 * u * t * b.dy + t * t * c.dy,
    );
  }

  void _stadiumLights(Canvas canvas, Size size, Paint paint) {
    for (var i = 0; i < 70; i++) {
      final x = (i * 53.0) % size.width;
      final row = i % 5;
      final y = 15 + row * 12.0;
      final pulse = .45 + .45 * math.sin(ambient * math.pi * 2 + i * .73);
      paint.color = Color.lerp(
        const Color(0xFF7AD7FF),
        const Color(0xFFFFE08A),
        pulse,
      )!;
      canvas.drawCircle(Offset(x, y), 1.5 + pulse, paint);
    }
    paint.color = Colors.white.withOpacity(.06);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .5, size.height * .25),
        width: size.width * .9,
        height: size.height * .28,
      ),
      paint,
    );
  }

  void _pitch(Canvas canvas, Size size, Paint paint) {
    final field = Path()
      ..moveTo(size.width * .03, size.height)
      ..lineTo(size.width * .97, size.height)
      ..lineTo(size.width * .78, size.height * .43)
      ..lineTo(size.width * .22, size.height * .43)
      ..close();
    paint.color = const Color(0xFF128354);
    paint.style = PaintingStyle.fill;
    canvas.drawPath(field, paint);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    paint.color = Colors.white70;
    canvas.drawPath(field, paint);
  }

  void _goal(Canvas canvas, Paint paint) {
    paint.style = PaintingStyle.fill;
    paint.color = const Color(0x99121B24);
    canvas.drawRect(goalRect, paint);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 5.2;
    paint.color = Colors.white;
    canvas.drawRect(goalRect, paint);
    paint.strokeWidth = .85;
    paint.color = Colors.white30;
    for (var i = 1; i < 12; i++) {
      final x = goalRect.left + goalRect.width * i / 12;
      canvas.drawLine(
        Offset(x, goalRect.top),
        Offset(x, goalRect.bottom),
        paint,
      );
    }
    for (var i = 1; i < 7; i++) {
      final y = goalRect.top + goalRect.height * i / 7;
      canvas.drawLine(
        Offset(goalRect.left, y),
        Offset(goalRect.right, y),
        paint,
      );
    }
  }

  void _ball(
      Canvas canvas, Offset center, double radius, Paint paint, double spin) {
    paint.style = PaintingStyle.fill;
    paint.color = Colors.black.withOpacity(.28);
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(2, radius * .45),
        width: radius * 2.1,
        height: radius * .65,
      ),
      paint,
    );
    paint.color = Colors.white;
    canvas.drawCircle(center, radius, paint);
    paint.color = const Color(0xFF101820);
    canvas.drawCircle(center, radius * .31, paint);
    for (var i = 0; i < 5; i++) {
      final angle = spin + i * math.pi * 2 / 5;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * radius * .62,
        radius * .14,
        paint,
      );
    }
  }

  void _powerMeter(Canvas canvas, Size size, Paint paint) {
    final width = size.width * .55;
    final rect = Rect.fromCenter(
      center: Offset(size.width * .5, size.height * .93),
      width: width,
      height: 13,
    );
    paint.style = PaintingStyle.fill;
    paint.color = Colors.black54;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      paint,
    );
    final fill = Rect.fromLTWH(
      rect.left,
      rect.top,
      rect.width * power,
      rect.height,
    );
    paint.color = power > .92 ? Colors.redAccent : const Color(0xFFFFD166);
    canvas.drawRRect(
      RRect.fromRectAndRadius(fill, const Radius.circular(8)),
      paint,
    );
  }

  void _impact(Canvas canvas, Offset target, Paint paint) {
    final t = ((progress - PenaltyMotionTimeline.ballArrival) /
            (1 - PenaltyMotionTimeline.ballArrival))
        .clamp(0.0, 1.0)
        .toDouble();
    if (outcome == _Outcome.goal) {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2.5;
      paint.color = Colors.white.withOpacity((1 - t) * .55);
      canvas.drawCircle(target, 18 + t * 24, paint);
    } else if (outcome == _Outcome.post) {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2;
      paint.color = const Color(0xFFFFD166).withOpacity(1 - t);
      for (var i = 0; i < 8; i++) {
        final angle = i * math.pi / 4;
        final start = target + Offset(math.cos(angle), math.sin(angle)) * 9;
        final end =
            target + Offset(math.cos(angle), math.sin(angle)) * (18 + t * 20);
        canvas.drawLine(start, end, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ElitePenaltyPainter oldDelegate) => true;
}
