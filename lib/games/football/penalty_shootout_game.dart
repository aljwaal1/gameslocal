import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/local_network_core.dart';
import '../../core/network/network_message.dart';

class FootballTeam {
  const FootballTeam(this.id, this.name, this.primary, this.secondary);

  final String id;
  final String name;
  final Color primary;
  final Color secondary;
}

const List<FootballTeam> footballTeams = <FootballTeam>[
  FootballTeam('jordan', 'الأردن', Color(0xFFC8102E), Colors.white),
  FootballTeam('brazil', 'البرازيل', Color(0xFFF7D117), Color(0xFF009B3A)),
  FootballTeam('spain', 'إسبانيا', Color(0xFFAA151B), Color(0xFFF1BF00)),
  FootballTeam('colombia', 'كولومبيا', Color(0xFFFCD116), Color(0xFF003893)),
  FootballTeam('morocco', 'المغرب', Color(0xFFC1272D), Color(0xFF006233)),
  FootballTeam('france', 'فرنسا', Color(0xFF1B3F8B), Colors.white),
  FootballTeam('germany', 'ألمانيا', Color(0xFF202020), Colors.white),
  FootballTeam('italy', 'إيطاليا', Color(0xFF0066B3), Colors.white),
  FootballTeam('portugal', 'البرتغال', Color(0xFFB20D30), Color(0xFF046A38)),
  FootballTeam('netherlands', 'هولندا', Color(0xFFFF6B00), Colors.white),
  FootballTeam('croatia', 'كرواتيا', Color(0xFFD00027), Colors.white),
  FootballTeam('japan', 'اليابان', Color(0xFF1D2D5C), Colors.white),
  FootballTeam('south_korea', 'كوريا الجنوبية', Color(0xFFE6002D), Color(0xFF003478)),
  FootballTeam('mexico', 'المكسيك', Color(0xFF006847), Color(0xFFCE1126)),
  FootballTeam('egypt', 'مصر', Color(0xFFCE1126), Colors.white),
  FootballTeam('saudi', 'السعودية', Color(0xFF006C35), Colors.white),
  FootballTeam('tunisia', 'تونس', Color(0xFFE70013), Colors.white),
  FootballTeam('algeria', 'الجزائر', Color(0xFF006633), Colors.white),
];

class PenaltyShootoutGameScreen extends StatefulWidget {
  const PenaltyShootoutGameScreen({super.key, this.networkCore});

  final LocalNetworkCore? networkCore;

  @override
  State<PenaltyShootoutGameScreen> createState() => _PenaltyShootoutGameScreenState();
}

class _PenaltyShootoutGameScreenState extends State<PenaltyShootoutGameScreen> {
  final Random _random = Random();
  StreamSubscription<NetworkMessage>? _subscription;

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
  int _ballZone = 7;
  int _keeperZone = 4;
  int _shooterPose = 0;
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
    if (_networkGame) {
      _subscription = widget.networkCore!.messages.listen(_handleNetworkMessage);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
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
    _turn = 0;
    _homeGoals = 0;
    _awayGoals = 0;
    _homeShots = 0;
    _awayShots = 0;
    _ballZone = 7;
    _keeperZone = 4;
    _shooterPose = 0;
    _busy = false;
    _connectionLost = false;
    _showResultFlash = false;
    _homeResults.clear();
    _awayResults.clear();
    _message = _networkGame
        ? (_isHost ? 'دورك: المس إحدى زوايا المرمى' : 'بانتظار اللاعب الأول')
        : 'المس إحدى زوايا المرمى للتسديد';
  }

  Future<void> _shoot(int zone) async {
    if (!_started || _busy || _finished || !_localTurn || _connectionLost) return;
    final keeperZone = _random.nextInt(9);
    final goal = !(keeperZone == zone && _random.nextDouble() < 0.80);
    final shotTurn = _turn;

    await _applyShot(zone: zone, keeperZone: keeperZone, goal: goal, remote: false);

    if (_networkGame) {
      widget.networkCore!.sendMove(<String, dynamic>{
        'action': 'penaltyShot',
        'turn': shotTurn,
        'zone': zone,
        'keeperZone': keeperZone,
        'goal': goal,
        'teamId': _isHost ? _homeTeam.id : _awayTeam.id,
      }, senderId: _localPlayerId);
    }
  }

  Future<void> _applyShot({
    required int zone,
    required int keeperZone,
    required bool goal,
    required bool remote,
  }) async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _showResultFlash = false;
      _message = remote ? 'اللاعب الآخر يستعد للتسديد...' : 'استعد...';
      _ballZone = 7;
      _keeperZone = 4;
      _shooterPose = 0;
    });

    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    setState(() {
      _message = 'انطلاق!';
      _shooterPose = 1;
    });
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);

    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (!mounted) return;
    setState(() {
      _ballZone = zone;
      _keeperZone = keeperZone;
      _shooterPose = 2;
    });

    await Future<void>.delayed(const Duration(milliseconds: 560));
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

    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _showResultFlash = false;
      if (_finished) {
        _message = _homeGoals > _awayGoals
            ? '🏆 فاز ${_homeTeam.name}'
            : '🏆 فاز ${_awayTeam.name}';
      } else if (_homeShots >= 5 && _awayShots >= 5 && _homeGoals == _awayGoals) {
        _message = 'تعادل! تبدأ الآن ركلات الحسم المفاجئ';
      } else if (_networkGame) {
        _message = _localTurn ? 'دورك: اختر مكان التسديدة' : 'بانتظار اللاعب الآخر';
      } else {
        _message = _turn.isEven ? 'دورك: اختر مكان التسديدة' : 'الروبوت يستعد...';
      }
    });

    if (!_networkGame && !_finished && _turn.isOdd) {
      await _robotShot();
    }
  }

  Future<void> _robotShot() async {
    if (_busy || _finished) return;
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    final zone = _random.nextInt(9);
    final keeperZone = _random.nextInt(9);
    final goal = !(zone == keeperZone && _random.nextDouble() < 0.68);
    await _applyShot(zone: zone, keeperZone: keeperZone, goal: goal, remote: true);
  }

  void _handleNetworkMessage(NetworkMessage message) {
    if (!mounted || message.senderId == _localPlayerId) return;
    if (message.type == NetworkMessageType.disconnect) {
      setState(() {
        _connectionLost = true;
        _busy = false;
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
    if (turn is! int || zone is! int || keeperZone is! int || goal is! bool) return;
    if (turn != _turn || zone < 0 || zone > 8 || keeperZone < 0 || keeperZone > 8) return;

    final teamId = message.payload['teamId']?.toString() ?? '';
    final teams = footballTeams.where((team) => team.id == teamId);
    if (teams.isNotEmpty) {
      if (_isHost) {
        _awayTeam = teams.first;
      } else {
        _homeTeam = teams.first;
      }
    }
    _applyShot(zone: zone, keeperZone: keeperZone, goal: goal, remote: true);
  }

  Alignment _alignment(int zone) {
    const zones = <Alignment>[
      Alignment(-0.78, -0.66), Alignment(0, -0.66), Alignment(0.78, -0.66),
      Alignment(-0.78, -0.05), Alignment.center, Alignment(0.78, -0.05),
      Alignment(-0.78, 0.58), Alignment(0, 0.58), Alignment(0.78, 0.58),
    ];
    return zones[zone.clamp(0, 8)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061C18),
      appBar: AppBar(
        title: const Text('ركلات الترجيح الاحترافية'),
        actions: [
          IconButton(
            tooltip: 'مباراة جديدة',
            onPressed: _started ? () => setState(_resetState) : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: <Widget>[_started ? _matchView() : _selectionView()],
        ),
      ),
    );
  }

  Widget _selectionView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: <Color>[Color(0xFF064E3B), Color(0xFF0B172A)],
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Colors.black45, blurRadius: 24, offset: Offset(0, 10)),
            ],
          ),
          child: const Column(
            children: <Widget>[
              Icon(Icons.sports_soccer, color: Color(0xFFFFD166), size: 74),
              SizedBox(height: 12),
              Text('ليلة ركلات الترجيح', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
              SizedBox(height: 6),
              Text('اختر منتخبك وادخل أجواء الملعب', style: TextStyle(color: Colors.white70, fontSize: 16)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _teamPicker('منتخبك', _homeTeam, (team) => setState(() => _homeTeam = team)),
        const SizedBox(height: 12),
        _teamPicker('المنتخب المنافس', _awayTeam, (team) => setState(() => _awayTeam = team)),
        const SizedBox(height: 14),
        Text(_message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 17)),
          onPressed: _start,
          icon: const Icon(Icons.stadium),
          label: Text(_networkGame ? 'ابدأ مباراة الشبكة' : 'ابدأ ضد الروبوت'),
        ),
      ],
    );
  }

  Widget _teamPicker(String title, FootballTeam selected, ValueChanged<FootballTeam> onChanged) {
    return Card(
      color: const Color(0xFF102D28),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selected.id,
              dropdownColor: const Color(0xFF102D28),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: [
                for (final team in footballTeams)
                  DropdownMenuItem<String>(
                    value: team.id,
                    child: Row(children: [_Kit(team: team, small: true), const SizedBox(width: 10), Text(team.name)]),
                  ),
              ],
              onChanged: (id) {
                if (id == null) return;
                onChanged(footballTeams.firstWhere((team) => team.id == id));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _matchView() {
    return Column(
      children: [
        Row(children: [
          Expanded(child: _scoreCard(_homeTeam, _homeGoals, _homeResults)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('VS', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
          ),
          Expanded(child: _scoreCard(_awayTeam, _awayGoals, _awayResults)),
        ]),
        const SizedBox(height: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _showResultFlash
                ? (_lastGoal ? const Color(0xFF16A34A) : const Color(0xFFDC2626))
                : const Color(0xFF102D28),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(_message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 0.86,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              children: [
                const Positioned.fill(child: CustomPaint(painter: _StadiumPainter())),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 62,
                  height: 230,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      if (!_localTurn || _busy || _finished || _connectionLost) return;
                      final col = (details.localPosition.dx / (details.localPosition.dx.isFinite ? 1 : 1));
                      final width = MediaQuery.sizeOf(context).width - 52;
                      final column = (details.localPosition.dx / (width / 3)).floor().clamp(0, 2);
                      final row = (details.localPosition.dy / (230 / 3)).floor().clamp(0, 2);
                      _shoot(row * 3 + column);
                    },
                    child: Stack(
                      children: [
                        const Positioned.fill(child: CustomPaint(painter: _GoalPainter())),
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.easeOutCubic,
                          alignment: _alignment(_keeperZone),
                          child: CustomPaint(
                            size: const Size(92, 118),
                            painter: _PlayerPainter(
                              primary: const Color(0xFFFFA500),
                              secondary: Colors.black,
                              keeper: true,
                              pose: _busy ? 2 : 0,
                            ),
                          ),
                        ),
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 520),
                          curve: Curves.easeOutExpo,
                          alignment: _alignment(_ballZone),
                          child: const _BallWidget(),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 26,
                  bottom: 20,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 300),
                    offset: Offset(_shooterPose == 0 ? 0 : (_shooterPose == 1 ? 0.35 : 0.62), 0),
                    child: CustomPaint(
                      size: const Size(105, 170),
                      painter: _PlayerPainter(
                        primary: _shootingTeam.primary,
                        secondary: _shootingTeam.secondary,
                        keeper: false,
                        pose: _shooterPose,
                      ),
                    ),
                  ),
                ),
                if (!_busy && !_finished && _localTurn)
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 300,
                    child: Text(
                      'المس الزاوية التي تريد التسديد نحوها',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, shadows: <Shadow>[Shadow(color: Colors.black, blurRadius: 5)]),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_finished)
          FilledButton.icon(
            onPressed: () => setState(_resetState),
            icon: const Icon(Icons.replay),
            label: const Text('إعادة المباراة'),
          ),
      ],
    );
  }

  Widget _scoreCard(FootballTeam team, int goals, List<bool> results) {
    return Card(
      color: const Color(0xFF102D28),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Column(children: [
          _Kit(team: team),
          const SizedBox(height: 5),
          Text(team.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text('$goals', style: const TextStyle(color: Color(0xFFFFD166), fontSize: 28, fontWeight: FontWeight.w900)),
          Wrap(
            spacing: 2,
            children: [for (final result in results) Icon(result ? Icons.check_circle : Icons.cancel, size: 14, color: result ? Colors.greenAccent : Colors.redAccent)],
          ),
        ]),
      ),
    );
  }
}

class _Kit extends StatelessWidget {
  const _Kit({required this.team, this.small = false});

  final FootballTeam team;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final size = small ? 32.0 : 52.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(small ? 8 : 14),
        gradient: LinearGradient(colors: <Color>[team.primary, team.secondary]),
        border: Border.all(color: Colors.white24),
        boxShadow: const <BoxShadow>[BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Icon(Icons.checkroom, color: Colors.white, size: small ? 21 : 33),
    );
  }
}

class _BallWidget extends StatelessWidget {
  const _BallWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: <BoxShadow>[BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: const Icon(Icons.sports_soccer, size: 34, color: Colors.black87),
    );
  }
}

class _StadiumPainter extends CustomPainter {
  const _StadiumPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xFF071A33), Color(0xFF123E45)],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final crowd = Paint()..color = const Color(0xFF15263A);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.12, size.width, size.height * 0.25), crowd);
    final random = Random(7);
    final dot = Paint();
    for (var i = 0; i < 240; i++) {
      dot.color = <Color>[Colors.white54, Colors.yellowAccent, Colors.redAccent, Colors.lightBlueAccent][i % 4];
      canvas.drawCircle(Offset(random.nextDouble() * size.width, size.height * 0.13 + random.nextDouble() * size.height * 0.20), 1.2, dot);
    }

    final pitch = Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xFF16833F), Color(0xFF075A2B)],
    ).createShader(Rect.fromLTWH(0, size.height * 0.35, size.width, size.height * 0.65));
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.35, size.width, size.height * 0.65), pitch);

    final line = Paint()..color = Colors.white70..strokeWidth = 2..style = PaintingStyle.stroke;
    canvas.drawOval(Rect.fromCenter(center: Offset(size.width / 2, size.height * 0.83), width: size.width * 0.66, height: size.height * 0.30), line);
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.72), 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GoalPainter extends CustomPainter {
  const _GoalPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Paint()..color = Colors.black38..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.05, size.height * 0.05, size.width * 0.90, size.height * 0.82), shadow);

    final line = Paint()..color = Colors.white..strokeWidth = 4..style = PaintingStyle.stroke;
    final net = Paint()..color = Colors.white38..strokeWidth = 1.2..style = PaintingStyle.stroke;
    final goal = Rect.fromLTWH(size.width * 0.05, size.height * 0.05, size.width * 0.90, size.height * 0.82);
    canvas.drawRect(goal, line);
    for (var i = 1; i < 9; i++) {
      final x = goal.left + goal.width * i / 9;
      canvas.drawLine(Offset(x, goal.top), Offset(x, goal.bottom), net);
    }
    for (var i = 1; i < 6; i++) {
      final y = goal.top + goal.height * i / 6;
      canvas.drawLine(Offset(goal.left, y), Offset(goal.right, y), net);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PlayerPainter extends CustomPainter {
  const _PlayerPainter({required this.primary, required this.secondary, required this.keeper, required this.pose});

  final Color primary;
  final Color secondary;
  final bool keeper;
  final int pose;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final skin = Paint()..color = const Color(0xFFD99A68);
    final hair = Paint()..color = const Color(0xFF24150F);
    final shirt = Paint()..shader = LinearGradient(colors: <Color>[primary, secondary]).createShader(Rect.fromLTWH(0, size.height * 0.28, size.width, size.height * 0.38));
    final shorts = Paint()..color = secondary.withOpacity(0.92);
    final boots = Paint()..color = Colors.black87;
    final white = Paint()..color = Colors.white;
    final dark = Paint()..color = Colors.black87;

    canvas.drawOval(Rect.fromCenter(center: Offset(centerX + (pose == 2 ? 4 : 0), size.height * 0.17), width: size.width * 0.28, height: size.height * 0.24), skin);
    canvas.drawArc(Rect.fromCenter(center: Offset(centerX, size.height * 0.13), width: size.width * 0.31, height: size.height * 0.18), pi, pi, true, hair);
    canvas.drawCircle(Offset(centerX - size.width * 0.055, size.height * 0.16), 2.2, dark);
    canvas.drawCircle(Offset(centerX + size.width * 0.055, size.height * 0.16), 2.2, dark);
    canvas.drawArc(Rect.fromCenter(center: Offset(centerX, size.height * 0.20), width: size.width * 0.10, height: size.height * 0.05), 0, pi, false, dark..strokeWidth = 1.5..style = PaintingStyle.stroke);

    final body = RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.28, size.height * 0.27, size.width * 0.44, size.height * 0.34), const Radius.circular(10));
    canvas.drawRRect(body, shirt);
    canvas.drawCircle(Offset(centerX, size.height * 0.38), 10, white);
    final number = TextPainter(
      text: TextSpan(text: keeper ? '1' : '9', style: TextStyle(color: primary.computeLuminance() > 0.55 ? Colors.black : Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
      textDirection: TextDirection.ltr,
    )..layout();
    number.paint(canvas, Offset(centerX - number.width / 2, size.height * 0.38 - number.height / 2));

    final armPaint = Paint()..color = primary..strokeWidth = size.width * 0.10..strokeCap = StrokeCap.round;
    if (keeper || pose == 2) {
      canvas.drawLine(Offset(size.width * 0.31, size.height * 0.34), Offset(size.width * 0.07, size.height * 0.18), armPaint);
      canvas.drawLine(Offset(size.width * 0.69, size.height * 0.34), Offset(size.width * 0.93, size.height * 0.18), armPaint);
      canvas.drawCircle(Offset(size.width * 0.06, size.height * 0.17), 6, skin);
      canvas.drawCircle(Offset(size.width * 0.94, size.height * 0.17), 6, skin);
    } else {
      canvas.drawLine(Offset(size.width * 0.31, size.height * 0.34), Offset(size.width * 0.18, size.height * 0.53), armPaint);
      canvas.drawLine(Offset(size.width * 0.69, size.height * 0.34), Offset(size.width * 0.82, size.height * 0.53), armPaint);
    }

    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.29, size.height * 0.59, size.width * 0.42, size.height * 0.18), const Radius.circular(7)), shorts);

    final leg = Paint()..color = skin.color..strokeWidth = size.width * 0.11..strokeCap = StrokeCap.round;
    final leftStart = Offset(size.width * 0.40, size.height * 0.72);
    final rightStart = Offset(size.width * 0.60, size.height * 0.72);
    if (!keeper && pose == 2) {
      canvas.drawLine(leftStart, Offset(size.width * 0.34, size.height * 0.94), leg);
      canvas.drawLine(rightStart, Offset(size.width * 0.93, size.height * 0.78), leg);
      canvas.drawLine(Offset(size.width * 0.88, size.height * 0.78), Offset(size.width * 0.98, size.height * 0.78), boots..strokeWidth = 7..strokeCap = StrokeCap.round);
    } else {
      canvas.drawLine(leftStart, Offset(size.width * 0.37, size.height * 0.94), leg);
      canvas.drawLine(rightStart, Offset(size.width * 0.63, size.height * 0.94), leg);
      canvas.drawLine(Offset(size.width * 0.31, size.height * 0.95), Offset(size.width * 0.44, size.height * 0.95), boots..strokeWidth = 7..strokeCap = StrokeCap.round);
      canvas.drawLine(Offset(size.width * 0.57, size.height * 0.95), Offset(size.width * 0.70, size.height * 0.95), boots);
    }
  }

  @override
  bool shouldRepaint(covariant _PlayerPainter oldDelegate) {
    return oldDelegate.primary != primary || oldDelegate.secondary != secondary || oldDelegate.pose != pose || oldDelegate.keeper != keeper;
  }
}