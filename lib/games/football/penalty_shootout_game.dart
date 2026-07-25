import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

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
  int _turn = 0;
  int _homeGoals = 0;
  int _awayGoals = 0;
  int _homeShots = 0;
  int _awayShots = 0;
  int _ballZone = 7;
  int _keeperZone = 1;
  String _message = 'اختر المنتخب ثم ابدأ المباراة';
  final List<bool> _homeResults = <bool>[];
  final List<bool> _awayResults = <bool>[];

  bool get _networkGame => widget.networkCore != null;
  bool get _isHost => widget.networkCore?.state.mode == LocalNetworkMode.host;
  bool get _localTurn => !_networkGame || (_turn.isEven == _isHost);
  bool get _finished => _homeShots >= 5 && _awayShots >= 5;

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
      return;
    }
    setState(() {
      _started = true;
      _resetState();
    });
  }

  void _resetState() {
    _turn = 0;
    _homeGoals = 0;
    _awayGoals = 0;
    _homeShots = 0;
    _awayShots = 0;
    _ballZone = 7;
    _keeperZone = 1;
    _busy = false;
    _connectionLost = false;
    _homeResults.clear();
    _awayResults.clear();
    _message = _networkGame
        ? (_isHost ? 'دورك: اختر مكان التسديدة' : 'بانتظار اللاعب الأول')
        : 'اختر مكان التسديدة';
  }

  Future<void> _shoot(int zone) async {
    if (!_started || _busy || _finished || !_localTurn || _connectionLost) return;
    final keeperZone = _random.nextInt(9);
    final goal = !(keeperZone == zone && _random.nextDouble() < 0.78);
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
      _message = remote ? 'اللاعب الآخر يسدد...' : 'التسديدة في الطريق...';
      _ballZone = 7;
      _keeperZone = 1;
    });

    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    setState(() {
      _ballZone = zone;
      _keeperZone = keeperZone;
    });

    await Future<void>.delayed(const Duration(milliseconds: 600));
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
      _message = goal ? 'هدف!' : 'تصدى الحارس!';
    });

    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() {
      if (_finished) {
        _message = _homeGoals == _awayGoals
            ? 'تعادل بعد خمس ركلات لكل منتخب'
            : (_homeGoals > _awayGoals ? 'فاز ${_homeTeam.name}' : 'فاز ${_awayTeam.name}');
      } else if (_networkGame) {
        _message = _localTurn ? 'دورك: اختر مكان التسديدة' : 'بانتظار اللاعب الآخر';
      } else {
        _message = 'اختر مكان التسديدة التالية';
      }
    });

    if (!_networkGame && !_finished && _turn.isOdd) {
      await _robotShot();
    }
  }

  Future<void> _robotShot() async {
    if (_busy || _finished) return;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final zone = _random.nextInt(9);
    final keeperZone = _random.nextInt(9);
    final goal = !(zone == keeperZone && _random.nextDouble() < 0.65);
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
      Alignment(-0.82, -0.72), Alignment(0, -0.72), Alignment(0.82, -0.72),
      Alignment(-0.82, 0), Alignment.center, Alignment(0.82, 0),
      Alignment(-0.82, 0.72), Alignment(0, 0.72), Alignment(0.82, 0.72),
    ];
    return zones[zone.clamp(0, 8)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ركلات الترجيح'),
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
          padding: const EdgeInsets.all(16),
          children: <Widget>[_started ? _matchView() : _selectionView()],
        ),
      ),
    );
  }

  Widget _selectionView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('اختر القميص والمنتخب', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(
          _networkGame
              ? 'كل لاعب يسدد بالتناوب عبر الشبكة المحلية.'
              : 'أنت تسدد ضد حارس آلي، ثم يسدد الروبوت ضد حارسك.',
          style: const TextStyle(fontSize: 16, height: 1.45),
        ),
        const SizedBox(height: 16),
        _teamPicker('منتخبك', _homeTeam, (team) => setState(() => _homeTeam = team)),
        const SizedBox(height: 12),
        _teamPicker('المنتخب المنافس', _awayTeam, (team) => setState(() => _awayTeam = team)),
        const SizedBox(height: 14),
        Text(_message, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        FilledButton.icon(onPressed: _start, icon: const Icon(Icons.sports_soccer), label: const Text('ابدأ المباراة')),
      ],
    );
  }

  Widget _teamPicker(String title, FootballTeam selected, ValueChanged<FootballTeam> onChanged) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selected.id,
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
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('VS', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
          Expanded(child: _scoreCard(_awayTeam, _awayGoals, _awayResults)),
        ]),
        const SizedBox(height: 12),
        Text(_message, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 1.15,
          child: Container(
            decoration: BoxDecoration(color: const Color(0xFF247A3C), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white, width: 3)),
            padding: const EdgeInsets.all(18),
            child: Stack(children: [
              Positioned.fill(child: CustomPaint(painter: _GoalPainter())),
              AnimatedAlign(duration: const Duration(milliseconds: 420), alignment: _alignment(_keeperZone), child: const Icon(Icons.sports_handball, color: Colors.orange, size: 54)),
              AnimatedAlign(duration: const Duration(milliseconds: 520), alignment: _alignment(_ballZone), child: const Icon(Icons.sports_soccer, color: Colors.white, size: 32)),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        if (!_finished)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 9,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.9),
            itemBuilder: (context, index) => FilledButton(
              onPressed: _localTurn && !_busy && !_connectionLost ? () => _shoot(index) : null,
              child: Text('سدد ${index + 1}'),
            ),
          ),
        if (_finished) FilledButton.icon(onPressed: () => setState(_resetState), icon: const Icon(Icons.replay), label: const Text('إعادة المباراة')),
      ],
    );
  }

  Widget _scoreCard(FootballTeam team, int goals, List<bool> results) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(children: [
          _Kit(team: team),
          const SizedBox(height: 6),
          Text(team.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('$goals', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          Wrap(spacing: 3, children: [for (final result in results) Icon(result ? Icons.check_circle : Icons.cancel, size: 15, color: result ? Colors.green : Colors.red)]),
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
    final size = small ? 30.0 : 54.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(small ? 8 : 14),
        gradient: LinearGradient(colors: <Color>[team.primary, team.secondary]),
        border: Border.all(color: Colors.black12),
      ),
      child: Icon(Icons.checkroom, color: Colors.white, size: small ? 20 : 34),
    );
  }
}

class _GoalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final goal = Rect.fromLTWH(size.width * 0.06, size.height * 0.08, size.width * 0.88, size.height * 0.72);
    canvas.drawRect(goal, line);
    for (var i = 1; i < 3; i++) {
      final x = goal.left + goal.width * i / 3;
      final y = goal.top + goal.height * i / 3;
      canvas.drawLine(Offset(x, goal.top), Offset(x, goal.bottom), line);
      canvas.drawLine(Offset(goal.left, y), Offset(goal.right, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
