import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class BattleArenaScreen extends StatefulWidget {
  const BattleArenaScreen({
    super.key,
    required this.characterName,
    required this.players,
    required this.mode,
    required this.botLevel,
  });

  final String characterName;
  final int players;
  final String mode;
  final String botLevel;

  @override
  State<BattleArenaScreen> createState() => _BattleArenaScreenState();
}

class _BattleArenaScreenState extends State<BattleArenaScreen> {
  static const double _step = 0.13;
  final math.Random _random = math.Random();
  Timer? _timer;
  Timer? _botTimer;

  double playerX = -0.55;
  double playerY = 0.45;
  double botX = 0.55;
  double botY = -0.35;
  int playerHealth = 100;
  int botHealth = 100;
  int secondsLeft = 60;
  bool finished = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _botTimer = Timer.periodic(_botDelay, (_) => _moveBot());
  }

  Duration get _botDelay {
    switch (widget.botLevel) {
      case 'صعب':
        return const Duration(milliseconds: 450);
      case 'سهل':
        return const Duration(milliseconds: 900);
      default:
        return const Duration(milliseconds: 650);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _botTimer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted || finished) return;
    setState(() {
      secondsLeft--;
      if (secondsLeft <= 0) _finish();
    });
  }

  void _move(double dx, double dy) {
    if (finished) return;
    setState(() {
      playerX = (playerX + dx).clamp(-0.88, 0.88);
      playerY = (playerY + dy).clamp(-0.82, 0.82);
    });
  }

  void _moveBot() {
    if (!mounted || finished) return;
    final chaseChance = widget.botLevel == 'صعب' ? 0.85 : widget.botLevel == 'سهل' ? 0.45 : 0.65;
    setState(() {
      if (_random.nextDouble() < chaseChance) {
        botX += playerX > botX ? _step : -_step;
        botY += playerY > botY ? _step : -_step;
      } else {
        botX += (_random.nextBool() ? 1 : -1) * _step;
        botY += (_random.nextBool() ? 1 : -1) * _step;
      }
      botX = botX.clamp(-0.88, 0.88);
      botY = botY.clamp(-0.82, 0.82);
      if (_distance < 0.34) {
        playerHealth = math.max(0, playerHealth - 6);
        if (playerHealth == 0) _finish();
      }
    });
  }

  double get _distance => math.sqrt(math.pow(playerX - botX, 2) + math.pow(playerY - botY, 2));

  void _attack() {
    if (finished) return;
    setState(() {
      if (_distance < 0.42) {
        botHealth = math.max(0, botHealth - 18);
        botX = (botX + (botX >= playerX ? 0.20 : -0.20)).clamp(-0.88, 0.88);
        botY = (botY + (botY >= playerY ? 0.20 : -0.20)).clamp(-0.82, 0.82);
        if (botHealth == 0) _finish();
      }
    });
  }

  void _finish() {
    finished = true;
    _timer?.cancel();
    _botTimer?.cancel();
  }

  void _restart() {
    _timer?.cancel();
    _botTimer?.cancel();
    setState(() {
      playerX = -0.55;
      playerY = 0.45;
      botX = 0.55;
      botY = -0.35;
      playerHealth = 100;
      botHealth = 100;
      secondsLeft = 60;
      finished = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _botTimer = Timer.periodic(_botDelay, (_) => _moveBot());
  }

  String get _resultText {
    if (playerHealth == botHealth) return 'تعادل';
    return playerHealth > botHealth ? 'فوز ${widget.characterName}' : 'فوز الروبوت';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الساحة الأولى • ${widget.characterName}'),
        actions: [
          Center(child: Text('$secondsLeft ث', style: const TextStyle(fontWeight: FontWeight.bold))),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  Expanded(child: _HealthBar(label: widget.characterName, value: playerHealth, icon: Icons.person)),
                  const SizedBox(width: 10),
                  Expanded(child: _HealthBar(label: 'الروبوت', value: botHealth, icon: Icons.smart_toy)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const _ArenaBackground(),
                      Align(
                        alignment: Alignment(playerX, playerY),
                        child: _Fighter(name: widget.characterName, icon: Icons.sports_martial_arts, color: Colors.blue),
                      ),
                      Align(
                        alignment: Alignment(botX, botY),
                        child: const _Fighter(name: 'روبوت', icon: Icons.smart_toy, color: Colors.red),
                      ),
                      if (finished)
                        Container(
                          color: Colors.black54,
                          child: Center(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(22),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_resultText, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Text('النمط: ${widget.mode} • ${widget.players} لاعبين'),
                                    const SizedBox(height: 14),
                                    FilledButton.icon(
                                      onPressed: _restart,
                                      icon: const Icon(Icons.replay),
                                      label: const Text('إعادة المباراة'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _MovementPad(onMove: _move),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: _attack,
                    icon: const Icon(Icons.flash_on, size: 30),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('ضربة'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArenaBackground extends StatelessWidget {
  const _ArenaBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B4332), Color(0xFF2D6A4F), Color(0xFF40916C)],
        ),
      ),
      child: CustomPaint(painter: _ArenaPainter()),
    );
  }
}

class _ArenaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawOval(Rect.fromCenter(center: size.center(Offset.zero), width: size.width * 0.55, height: size.height * 0.45), paint);
    canvas.drawRect(Rect.fromLTWH(12, 12, size.width - 24, size.height - 24), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Fighter extends StatelessWidget {
  const _Fighter({required this.name, required this.icon, required this.color});

  final String name;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 4))],
          ),
          child: Icon(icon, color: Colors.white, size: 34),
        ),
        const SizedBox(height: 3),
        Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
      ],
    );
  }
}

class _HealthBar extends StatelessWidget {
  const _HealthBar({required this.label, required this.value, required this.icon});

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Icon(icon, size: 17), const SizedBox(width: 5), Expanded(child: Text('$label • $value', overflow: TextOverflow.ellipsis))]),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: value / 100, minHeight: 8, borderRadius: BorderRadius.circular(8)),
      ],
    );
  }
}

class _MovementPad extends StatelessWidget {
  const _MovementPad({required this.onMove});

  final void Function(double dx, double dy) onMove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        children: [
          Align(alignment: Alignment.topCenter, child: _MoveButton(icon: Icons.keyboard_arrow_up, onTap: () => onMove(0, -_BattleArenaScreenState._step))),
          Align(alignment: Alignment.bottomCenter, child: _MoveButton(icon: Icons.keyboard_arrow_down, onTap: () => onMove(0, _BattleArenaScreenState._step))),
          Align(alignment: Alignment.centerLeft, child: _MoveButton(icon: Icons.keyboard_arrow_left, onTap: () => onMove(-_BattleArenaScreenState._step, 0))),
          Align(alignment: Alignment.centerRight, child: _MoveButton(icon: Icons.keyboard_arrow_right, onTap: () => onMove(_BattleArenaScreenState._step, 0))),
        ],
      ),
    );
  }
}

class _MoveButton extends StatelessWidget {
  const _MoveButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(onPressed: onTap, icon: Icon(icon, size: 30));
  }
}
