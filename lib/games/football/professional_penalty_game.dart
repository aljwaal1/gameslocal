import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/local_network_core.dart';
import '../../core/network/network_message.dart';
import 'penalty_shootout_game.dart' show FootballTeam, footballTeams;
import 'professional_penalty_scene.dart';

class ProPenaltyShootoutGameScreen extends StatefulWidget {
  const ProPenaltyShootoutGameScreen({super.key, this.networkCore});

  final LocalNetworkCore? networkCore;

  @override
  State<ProPenaltyShootoutGameScreen> createState() =>
      _ProPenaltyShootoutGameScreenState();
}

class _ProPenaltyShootoutGameScreenState
    extends State<ProPenaltyShootoutGameScreen> with TickerProviderStateMixin {
  final Random _random = Random();
  StreamSubscription<NetworkMessage>? _subscription;

  late final AnimationController _shotController;
  late final AnimationController _ambientController;

  FootballTeam _homeTeam = footballTeams.first;
  FootballTeam _awayTeam = footballTeams[1];

  bool _started = false;
  bool _busy = false;
  bool _connectionLost = false;
  bool _showResultFlash = false;
  bool _lastGoal = false;

  int _turn = 0;
  int _homeGoals = 0;
  int _awayGoals = 0;
  int _homeShots = 0;
  int _awayShots = 0;

  double _shotPower = 0.82;
  double _targetX = 0.50;
  double _targetY = 0.34;
  double _keeperX = 0.50;
  double _keeperY = 0.58;

  String _message = 'اختر المنتخب واللباس ثم ابدأ المباراة';

  final List<bool> _homeResults = <bool>[];
  final List<bool> _awayResults = <bool>[];

  bool get _networkGame => widget.networkCore != null;
  bool get _isHost => widget.networkCore?.state.mode == LocalNetworkMode.host;
  bool get _localTurn => !_networkGame || (_turn.isEven == _isHost);

  bool get _finished {
    if (_homeShots < 5 || _awayShots < 5) return false;
    return _homeGoals != _awayGoals;
  }

  FootballTeam get _shootingTeam => _turn.isEven ? _homeTeam : _awayTeam;

  String get _localPlayerId {
    final players = widget.networkCore?.state.players ?? const <LocalPlayer>[];
    final match = players.where((player) => player.isHost == _isHost);
    return match.isNotEmpty ? match.first.id : (_isHost ? 'host' : 'client');
  }

  @override
  void initState() {
    super.initState();
    _shotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    if (_networkGame) {
      _subscription =
          widget.networkCore!.messages.listen(_handleNetworkMessage);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _shotController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  void _start() {
    if (_homeTeam.id == _awayTeam.id) {
      setState(() => _message = 'اختر منتخبًا مختلفًا للمنافس');
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _started = true;
      _resetState();
    });
    SystemSound.play(SystemSoundType.click);
  }

  void _resetState() {
    _shotController.reset();
    _turn = 0;
    _homeGoals = 0;
    _awayGoals = 0;
    _homeShots = 0;
    _awayShots = 0;
    _busy = false;
    _connectionLost = false;
    _showResultFlash = false;
    _homeResults.clear();
    _awayResults.clear();
    _targetX = 0.50;
    _targetY = 0.34;
    _keeperX = 0.50;
    _keeperY = 0.58;
    _message = _networkGame
        ? (_isHost ? 'دورك: حدد الزاوية وقوة التسديدة' : 'بانتظار اللاعب الأول')
        : 'حدد الزاوية واضبط قوة التسديدة';
  }

  int _zoneFromTarget(double x, double y) {
    final column = (x.clamp(0.0, 0.999) * 3).floor().clamp(0, 2);
    final row = (y.clamp(0.0, 0.999) * 3).floor().clamp(0, 2);
    return row * 3 + column;
  }

  Offset _zoneCenter(int zone) {
    final row = zone ~/ 3;
    final column = zone % 3;
    return Offset((column + 0.5) / 3, (row + 0.5) / 3);
  }

  Future<void> _shootAt(double targetX, double targetY) async {
    if (!_started || _busy || _finished || !_localTurn || _connectionLost) {
      return;
    }

    final zone = _zoneFromTarget(targetX, targetY);
    final keeperZone = _random.nextInt(9);
    final keeperCenter = _zoneCenter(keeperZone);
    final keeperX = (keeperCenter.dx + (_random.nextDouble() - 0.5) * 0.12)
        .clamp(0.06, 0.94)
        .toDouble();
    final keeperY = (keeperCenter.dy + (_random.nextDouble() - 0.5) * 0.10)
        .clamp(0.08, 0.90)
        .toDouble();

    final distance = sqrt(
      pow(targetX - keeperX, 2) + pow(targetY - keeperY, 2),
    );
    final reactionRadius = 0.24 - (_shotPower * 0.085);
    final keeperReadsShot = distance < reactionRadius;
    final saveChance = keeperReadsShot ? 0.86 : 0.10;
    final poorContactChance = (0.92 - _shotPower).clamp(0.0, 0.22) * 0.26;
    final saved = _random.nextDouble() < saveChance;
    final poorContact = !saved && _random.nextDouble() < poorContactChance;
    final goal = !saved && !poorContact;
    final shotTurn = _turn;

    await _applyShot(
      zone: zone,
      keeperZone: keeperZone,
      targetX: targetX,
      targetY: targetY,
      keeperX: keeperX,
      keeperY: keeperY,
      power: _shotPower,
      goal: goal,
      remote: false,
    );

    if (_networkGame) {
      widget.networkCore!.sendMove(<String, dynamic>{
        'action': 'penaltyShot',
        'turn': shotTurn,
        'zone': zone,
        'keeperZone': keeperZone,
        'targetX': targetX,
        'targetY': targetY,
        'keeperX': keeperX,
        'keeperY': keeperY,
        'power': _shotPower,
        'goal': goal,
        'teamId': _isHost ? _homeTeam.id : _awayTeam.id,
      }, senderId: _localPlayerId);
    }
  }

  Future<void> _applyShot({
    required int zone,
    required int keeperZone,
    required double targetX,
    required double targetY,
    required double keeperX,
    required double keeperY,
    required double power,
    required bool goal,
    required bool remote,
  }) async {
    if (!mounted) return;

    setState(() {
      _busy = true;
      _showResultFlash = false;
      _message = remote ? 'اللاعب الآخر يتهيأ للتسديد...' : 'ثبّت قدمك...';
      _targetX = targetX;
      _targetY = targetY;
      _keeperX = keeperX;
      _keeperY = keeperY;
      _shotPower = power;
    });

    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);

    try {
      await _shotController.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }

    if (!mounted) return;
    final homeTurn = _turn.isEven;

    setState(() {
      if (homeTurn) {
        _homeShots++;
        _homeResults.add(goal);
        if (goal) _homeGoals++;
      } else {
        _awayShots++;
        _awayResults.add(goal);
        if (goal) _awayGoals++;
      }
      _turn++;
      _busy = false;
      _lastGoal = goal;
      _showResultFlash = true;
      _message = goal ? 'هــــدف!' : 'تصـــدٍ رائع!';
    });

    if (goal) {
      HapticFeedback.heavyImpact();
      await SystemSound.play(SystemSoundType.alert);
    } else {
      HapticFeedback.mediumImpact();
      await SystemSound.play(SystemSoundType.click);
    }

    await Future<void>.delayed(const Duration(milliseconds: 1350));
    if (!mounted) return;

    setState(() {
      _showResultFlash = false;
      _shotController.reset();
      if (_finished) {
        _message = _homeGoals > _awayGoals
            ? '🏆 فاز ${_homeTeam.name}'
            : '🏆 فاز ${_awayTeam.name}';
      } else if (_homeShots >= 5 &&
          _awayShots >= 5 &&
          _homeGoals == _awayGoals) {
        _message = 'تعادل! تبدأ ركلات الحسم المفاجئ';
      } else if (_networkGame) {
        _message = _localTurn
            ? 'دورك: حدد الزاوية وقوة التسديدة'
            : 'بانتظار اللاعب الآخر';
      } else {
        _message = _turn.isEven
            ? 'دورك: حدد الزاوية وقوة التسديدة'
            : 'الروبوت يستعد...';
      }
    });

    if (!_networkGame && !_finished && _turn.isOdd) {
      await _robotShot();
    }
  }

  Future<void> _robotShot() async {
    if (_busy || _finished) return;
    await Future<void>.delayed(const Duration(milliseconds: 1250));
    if (!mounted) return;

    final targetX = 0.10 + _random.nextDouble() * 0.80;
    final targetY = 0.08 + _random.nextDouble() * 0.74;
    final zone = _zoneFromTarget(targetX, targetY);
    final keeperZone = _random.nextInt(9);
    final keeperCenter = _zoneCenter(keeperZone);
    final keeperX = keeperCenter.dx;
    final keeperY = keeperCenter.dy;
    final power = 0.66 + _random.nextDouble() * 0.30;
    final distance = sqrt(
      pow(targetX - keeperX, 2) + pow(targetY - keeperY, 2),
    );
    final goal = !(distance < 0.18 && _random.nextDouble() < 0.74);

    await _applyShot(
      zone: zone,
      keeperZone: keeperZone,
      targetX: targetX,
      targetY: targetY,
      keeperX: keeperX,
      keeperY: keeperY,
      power: power,
      goal: goal,
      remote: true,
    );
  }

  double? _payloadDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  void _handleNetworkMessage(NetworkMessage message) {
    if (!mounted || message.senderId == _localPlayerId) return;

    if (message.type == NetworkMessageType.disconnect) {
      setState(() {
        _connectionLost = true;
        _busy = false;
        _shotController.reset();
        _message = 'انقطع اتصال اللاعب الآخر';
      });
      return;
    }

    if (message.type != NetworkMessageType.move || _connectionLost) return;
    if (message.payload['action'] != 'penaltyShot') return;

    final turn = message.payload['turn'];
    final zone = message.payload['zone'];
    final keeperZone = message.payload['keeperZone'];
    final goal = message.payload['goal'];
    if (turn is! int || zone is! int || keeperZone is! int || goal is! bool) {
      return;
    }
    if (turn != _turn ||
        zone < 0 ||
        zone > 8 ||
        keeperZone < 0 ||
        keeperZone > 8) {
      return;
    }

    final fallbackTarget = _zoneCenter(zone);
    final fallbackKeeper = _zoneCenter(keeperZone);
    final targetX =
        _payloadDouble(message.payload['targetX']) ?? fallbackTarget.dx;
    final targetY =
        _payloadDouble(message.payload['targetY']) ?? fallbackTarget.dy;
    final keeperX =
        _payloadDouble(message.payload['keeperX']) ?? fallbackKeeper.dx;
    final keeperY =
        _payloadDouble(message.payload['keeperY']) ?? fallbackKeeper.dy;
    final power = _payloadDouble(message.payload['power']) ?? 0.82;

    final teamId = message.payload['teamId']?.toString() ?? '';
    final teams = footballTeams.where((team) => team.id == teamId);
    if (teams.isNotEmpty) {
      if (_isHost) {
        _awayTeam = teams.first;
      } else {
        _homeTeam = teams.first;
      }
    }

    unawaited(
      _applyShot(
        zone: zone,
        keeperZone: keeperZone,
        targetX: targetX.clamp(0.0, 1.0).toDouble(),
        targetY: targetY.clamp(0.0, 1.0).toDouble(),
        keeperX: keeperX.clamp(0.0, 1.0).toDouble(),
        keeperY: keeperY.clamp(0.0, 1.0).toDouble(),
        power: power.clamp(0.55, 1.0).toDouble(),
        goal: goal,
        remote: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030B12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07131F),
        foregroundColor: Colors.white,
        title: const Text('Penalty Arena Pro'),
        actions: <Widget>[
          IconButton(
            tooltip: 'مباراة جديدة',
            onPressed: _started ? () => setState(_resetState) : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 360),
          child: _started ? _matchView() : _selectionView(),
        ),
      ),
    );
  }

  Widget _selectionView() {
    return ListView(
      key: const ValueKey<String>('selection'),
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFF0B2239),
                Color(0xFF0A4A3B),
                Color(0xFF07131F),
              ],
            ),
            border: Border.all(color: Colors.white12),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Colors.black54,
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              Container(
                width: 92,
                height: 92,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[Color(0xFFFFE08A), Color(0xFFD79B18)],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: Colors.black45, blurRadius: 18),
                  ],
                ),
                child: const Icon(
                  Icons.sports_soccer,
                  color: Color(0xFF101820),
                  size: 58,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'ليلة ركلات الترجيح',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'منظور خلف اللاعب • قوة ودقة • حارس متفاعل',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _teamPicker('منتخبك', _homeTeam, (team) {
          setState(() => _homeTeam = team);
        }),
        const SizedBox(height: 12),
        _teamPicker('المنتخب المنافس', _awayTeam, (team) {
          setState(() => _awayTeam = team);
        }),
        const SizedBox(height: 14),
        Text(
          _message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF17A36B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          onPressed: _start,
          icon: const Icon(Icons.stadium),
          label: Text(
            _networkGame ? 'ابدأ مباراة الشبكة' : 'ابدأ ضد الروبوت',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
        ),
      ],
    );
  }

  Widget _teamPicker(
    String title,
    FootballTeam selected,
    ValueChanged<FootballTeam> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1825),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selected.id,
            dropdownColor: const Color(0xFF102334),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            items: <DropdownMenuItem<String>>[
              for (final team in footballTeams)
                DropdownMenuItem<String>(
                  value: team.id,
                  child: Row(
                    children: <Widget>[
                      _KitBadge(team: team, compact: true),
                      const SizedBox(width: 12),
                      Text(team.name),
                    ],
                  ),
                ),
            ],
            onChanged: (id) {
              if (id == null) return;
              onChanged(footballTeams.firstWhere((team) => team.id == id));
            },
          ),
        ],
      ),
    );
  }

  Widget _matchView() {
    return ListView(
      key: const ValueKey<String>('match'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
      children: <Widget>[
        _scoreboard(),
        const SizedBox(height: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: _showResultFlash
                ? (_lastGoal
                    ? const Color(0xFF0E9F5B)
                    : const Color(0xFFCB2636))
                : const Color(0xFF0B1825),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(
            _message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 10),
        AspectRatio(
          aspectRatio: 0.74,
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[
              _shotController,
              _ambientController,
            ]),
            builder: (context, child) {
              return ProfessionalPenaltyScene(
                shotProgress: _shotController.value,
                ambientProgress: _ambientController.value,
                shootingTeam: _shootingTeam,
                targetX: _targetX,
                targetY: _targetY,
                keeperX: _keeperX,
                keeperY: _keeperY,
                shotPower: _shotPower,
                goal: _lastGoal,
                enabled: !_busy && !_finished && _localTurn && !_connectionLost,
                onShoot: _shootAt,
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1825),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.bolt, color: Color(0xFFFFCF5C)),
                  const SizedBox(width: 8),
                  const Text(
                    'قوة التسديدة',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(_shotPower * 100).round()}%',
                    style: const TextStyle(
                      color: Color(0xFFFFCF5C),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Slider(
                min: 0.55,
                max: 1.0,
                value: _shotPower,
                activeColor: const Color(0xFFFFCF5C),
                inactiveColor: Colors.white12,
                onChanged: _busy || !_localTurn || _finished
                    ? null
                    : (value) => setState(() => _shotPower = value),
              ),
              const Text(
                'المس المكان الدقيق داخل المرمى. القوة العالية أسرع لكنها أصعب في التحكم.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
        if (_finished) ...<Widget>[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => setState(_resetState),
            icon: const Icon(Icons.replay),
            label: const Text('إعادة المباراة'),
          ),
        ],
      ],
    );
  }

  Widget _scoreboard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF10283B), Color(0xFF08131E)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Colors.black45, blurRadius: 16, offset: Offset(0, 7)),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: _scoreSide(_homeTeam, _homeGoals, _homeResults)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'VS',
              style: TextStyle(
                color: Color(0xFFFFCF5C),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(child: _scoreSide(_awayTeam, _awayGoals, _awayResults)),
        ],
      ),
    );
  }

  Widget _scoreSide(FootballTeam team, int goals, List<bool> results) {
    return Column(
      children: <Widget>[
        _KitBadge(team: team),
        const SizedBox(height: 5),
        Text(
          team.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          '$goals',
          style: const TextStyle(
            color: Color(0xFFFFCF5C),
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        Wrap(
          spacing: 3,
          children: <Widget>[
            for (final result in results)
              Icon(
                result ? Icons.check_circle : Icons.cancel,
                size: 14,
                color: result ? Colors.greenAccent : Colors.redAccent,
              ),
          ],
        ),
      ],
    );
  }
}

class _KitBadge extends StatelessWidget {
  const _KitBadge({required this.team, this.compact = false});

  final FootballTeam team;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 34.0 : 50.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 9 : 14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[team.primary, team.secondary],
        ),
        border: Border.all(color: Colors.white24),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Icon(
        Icons.checkroom,
        color: Colors.white,
        size: compact ? 22 : 31,
      ),
    );
  }
}
