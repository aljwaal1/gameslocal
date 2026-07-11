import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio_feedback.dart';
import '../../core/network/local_network_core.dart';
import '../../core/network/network_message.dart';

class BattleArenaScreen extends StatefulWidget {
  const BattleArenaScreen({
    super.key,
    required this.characterName,
    required this.players,
    required this.mode,
    required this.botLevel,
    this.networkCore,
    this.arenaName = 'الغابة',
  });

  final String characterName;
  final int players;
  final String mode;
  final String botLevel;
  final LocalNetworkCore? networkCore;
  final String arenaName;

  @override
  State<BattleArenaScreen> createState() => _BattleArenaScreenState();
}

class _BattleArenaScreenState extends State<BattleArenaScreen> {
  static const double baseStep = 0.13;
  static const int skillCooldownSeconds = 8;

  final math.Random random = math.Random();
  Timer? matchTimer;
  Timer? botTimer;
  Timer? effectTimer;
  StreamSubscription<NetworkMessage>? networkSubscription;

  double playerX = -0.55;
  double playerY = 0.45;
  double botX = 0.55;
  double botY = -0.35;
  late int playerHealth;
  int botHealth = 100;
  int secondsLeft = 60;
  int skillCooldown = 0;
  bool finished = false;
  bool skillSucceeded = false;
  bool playerEffect = false;
  bool botEffect = false;
  String? skillMessage;
  double pickupX = 0;
  double pickupY = 0;
  bool pickupVisible = true;

  int get playerMaxHealth => widget.characterName == 'صخر' ? 125 : 100;

  int get playerDamage => switch (widget.characterName) {
        'لهب' => 24,
        'موج' => 20,
        _ => 18,
      };

  int get botDamage => widget.characterName == 'صخر' ? 4 : 6;
  double get playerStep => widget.characterName == 'برق' ? 0.17 : baseStep;
  double get attackRange => widget.characterName == 'موج' ? 0.48 : 0.42;

  String get abilityText => switch (widget.characterName) {
        'برق' => 'اندفاع سريع نحو الروبوت',
        'صخر' => 'استعادة 20 نقطة صحة',
        'لهب' => 'ضربة لهب بقوة 36',
        'موج' => 'موجة بعيدة بقوة 26',
        _ => 'ضربة مركزة بقوة 24',
      };

  IconData get abilityIcon => switch (widget.characterName) {
        'برق' => Icons.bolt,
        'صخر' => Icons.shield,
        'لهب' => Icons.local_fire_department,
        'موج' => Icons.waves,
        _ => Icons.auto_awesome,
      };

  Duration get botDelay => switch (widget.botLevel) {
        'صعب' => const Duration(milliseconds: 450),
        'سهل' => const Duration(milliseconds: 900),
        _ => const Duration(milliseconds: 650),
      };

  double get distance => math.sqrt(
        math.pow(playerX - botX, 2) + math.pow(playerY - botY, 2),
      );

  bool get isNetworkGame => widget.networkCore != null;
  bool get isHost => widget.networkCore?.state.mode == LocalNetworkMode.host;
  String get localPlayerId {
    final players = widget.networkCore?.state.players ?? const <LocalPlayer>[];
    final own = players.where((player) => player.isHost == isHost);
    return own.isNotEmpty ? own.first.id : (isHost ? 'host' : 'client');
  }
  bool get canUseSkill => !finished && skillCooldown == 0 && (!isNetworkGame || isHost);

  @override
  void initState() {
    super.initState();
    playerHealth = playerMaxHealth;
    if (isNetworkGame) {
      networkSubscription = widget.networkCore!.messages.listen(_handleNetworkMessage);
      if (!isHost) Future<void>.delayed(const Duration(milliseconds: 300), _requestState);
    }
    startTimers();
  }

  void startTimers() {
    matchTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    if (!isNetworkGame) botTimer = Timer.periodic(botDelay, (_) => moveBot());
  }

  @override
  void dispose() {
    matchTimer?.cancel();
    botTimer?.cancel();
    effectTimer?.cancel();
    networkSubscription?.cancel();
    super.dispose();
  }

  void _requestState() {
    if (!isNetworkGame) return;
    widget.networkCore!.sendMove(<String, dynamic>{'game': 'battle', 'action': 'stateRequest'}, senderId: localPlayerId);
  }

  void _handleNetworkMessage(NetworkMessage message) {
    if (!mounted || message.type != NetworkMessageType.move || message.senderId == localPlayerId || message.payload['game'] != 'battle') return;
    final p = message.payload;
    if (p['action'] == 'stateRequest') {
      if (isHost) _sendState();
      return;
    }
    setState(() {
      playerX = (p['playerX'] as num?)?.toDouble() ?? playerX;
      playerY = (p['playerY'] as num?)?.toDouble() ?? playerY;
      botX = (p['botX'] as num?)?.toDouble() ?? botX;
      botY = (p['botY'] as num?)?.toDouble() ?? botY;
      playerHealth = (p['playerHealth'] as num?)?.toInt() ?? playerHealth;
      botHealth = (p['botHealth'] as num?)?.toInt() ?? botHealth;
      secondsLeft = (p['secondsLeft'] as num?)?.toInt() ?? secondsLeft;
      finished = p['finished'] == true;
      pickupX = (p['pickupX'] as num?)?.toDouble() ?? pickupX;
      pickupY = (p['pickupY'] as num?)?.toDouble() ?? pickupY;
      pickupVisible = p['pickupVisible'] as bool? ?? pickupVisible;
    });
  }

  void _sendState() {
    if (!isNetworkGame) return;
    widget.networkCore!.sendMove(<String, dynamic>{
      'game': 'battle', 'action': 'snapshot', 'playerX': playerX, 'playerY': playerY,
      'botX': botX, 'botY': botY, 'playerHealth': playerHealth,
      'botHealth': botHealth, 'secondsLeft': secondsLeft, 'finished': finished,
      'pickupX': pickupX, 'pickupY': pickupY, 'pickupVisible': pickupVisible,
    }, senderId: localPlayerId);
  }

  void tick() {
    if (!mounted || finished) return;
    setState(() {
      secondsLeft--;
      if (skillCooldown > 0) skillCooldown--;
      if (secondsLeft > 0 && secondsLeft % 15 == 0) {
        pickupX = random.nextDouble() * 1.5 - 0.75;
        pickupY = random.nextDouble() * 1.4 - 0.70;
        pickupVisible = true;
      }
      if (secondsLeft <= 0) finish();
    });
  }

  void move(double dx, double dy) {
    if (finished) return;
    setState(() {
      if (isNetworkGame && !isHost) {
        botX = (botX + dx).clamp(-0.88, 0.88).toDouble();
        botY = (botY + dy).clamp(-0.82, 0.82).toDouble();
      } else {
        playerX = (playerX + dx).clamp(-0.88, 0.88).toDouble();
        playerY = (playerY + dy).clamp(-0.82, 0.82).toDouble();
      }
    });
    _collectPickupIfClose();
    _sendState();
  }

  void _collectPickupIfClose() {
    if (!pickupVisible) return;
    final x = isNetworkGame && !isHost ? botX : playerX;
    final y = isNetworkGame && !isHost ? botY : playerY;
    if (math.sqrt(math.pow(x - pickupX, 2) + math.pow(y - pickupY, 2)) > 0.20) return;
    pickupVisible = false;
    if (isNetworkGame && !isHost) {
      botHealth = math.min(100, botHealth + 18).toInt();
    } else {
      playerHealth = math.min(playerMaxHealth, playerHealth + 18).toInt();
    }
    skillMessage = 'تم التقاط حزمة علاج +18 صحة';
    skillSucceeded = true;
    GameFeedback.win();
  }

  void moveBot() {
    if (!mounted || finished) return;
    final chaseChance = switch (widget.botLevel) {
      'صعب' => 0.85,
      'سهل' => 0.45,
      _ => 0.65,
    };

    setState(() {
      if (random.nextDouble() < chaseChance) {
        botX += playerX > botX ? baseStep : -baseStep;
        botY += playerY > botY ? baseStep : -baseStep;
      } else {
        botX += (random.nextBool() ? 1 : -1) * baseStep;
        botY += (random.nextBool() ? 1 : -1) * baseStep;
      }
      botX = botX.clamp(-0.88, 0.88).toDouble();
      botY = botY.clamp(-0.82, 0.82).toDouble();
      if (distance < 0.34) {
        playerHealth = math.max(0, playerHealth - botDamage).toInt();
        if (playerHealth == 0) finish();
      }
    });
  }

  void attack() {
    if (finished) return;
    setState(() {
      if (distance >= attackRange) return;
      if (isNetworkGame && !isHost) {
        playerHealth = math.max(0, playerHealth - 18).toInt();
        playerX = (playerX + (playerX >= botX ? 0.20 : -0.20)).clamp(-0.88, 0.88).toDouble();
        if (playerHealth == 0) finish();
      } else {
        damageBot(playerDamage, knockback: 0.20);
      }
    });
    _sendState();
  }

  void useSkill() {
    if (!canUseSkill) return;
    setState(() {
      final succeeded = _applySkill();
      skillSucceeded = succeeded;
      if (succeeded) {
        skillCooldown = skillCooldownSeconds;
        _showSkillEffect(onPlayer: widget.characterName == 'صخر');
      }
    });
    _sendState();
  }

  void _showSkillEffect({required bool onPlayer}) {
    effectTimer?.cancel();
    playerEffect = onPlayer;
    botEffect = !onPlayer;
    effectTimer = Timer(const Duration(milliseconds: 550), () {
      if (!mounted) return;
      setState(() {
        playerEffect = false;
        botEffect = false;
      });
    });
  }

  bool _applySkill() {
    switch (widget.characterName) {
      case 'برق':
        final dx = botX - playerX;
        final dy = botY - playerY;
        final length = math.max(0.001, math.sqrt(dx * dx + dy * dy));
        playerX =
            (playerX + (dx / length) * 0.38).clamp(-0.88, 0.88).toDouble();
        playerY =
            (playerY + (dy / length) * 0.38).clamp(-0.82, 0.82).toDouble();
        if (distance < 0.46) {
          damageBot(22, knockback: 0.12);
          skillMessage = 'نجح اندفاع برق وأصاب الروبوت.';
        } else {
          skillMessage = 'اندفع برق للأمام واقترب من الروبوت.';
        }
        return true;
      case 'صخر':
        if (playerHealth >= playerMaxHealth) {
          skillMessage = 'الصحة ممتلئة؛ لم تُستخدم المهارة.';
          return false;
        }
        final before = playerHealth;
        playerHealth = math.min(playerMaxHealth, playerHealth + 20).toInt();
        skillMessage = 'استعاد صخر ${playerHealth - before} نقطة صحة.';
        return true;
      case 'لهب':
        if (distance >= 0.46) {
          skillMessage = 'الروبوت بعيد عن ضربة اللهب.';
          return false;
        }
        damageBot(36, knockback: 0.26);
        skillMessage = 'أصابت ضربة اللهب الروبوت بقوة 36.';
        return true;
      case 'موج':
        if (distance >= 0.72) {
          skillMessage = 'الروبوت خارج مدى الموجة.';
          return false;
        }
        damageBot(26, knockback: 0.34);
        skillMessage = 'أصابت الموجة الروبوت ودفعته للخلف.';
        return true;
      default:
        if (distance >= 0.46) {
          skillMessage = 'اقترب أكثر لاستخدام المهارة.';
          return false;
        }
        damageBot(24, knockback: 0.20);
        skillMessage = 'نجحت الضربة المركزة.';
        return true;
    }
  }

  void damageBot(int damage, {required double knockback}) {
    botHealth = math.max(0, botHealth - damage).toInt();
    botX = (botX + (botX >= playerX ? knockback : -knockback))
        .clamp(-0.88, 0.88)
        .toDouble();
    botY = (botY + (botY >= playerY ? knockback : -knockback))
        .clamp(-0.82, 0.82)
        .toDouble();
    if (botHealth == 0) finish();
  }

  void finish() {
    finished = true;
    matchTimer?.cancel();
    botTimer?.cancel();
  }

  void restart() {
    matchTimer?.cancel();
    botTimer?.cancel();
    effectTimer?.cancel();
    setState(() {
      playerX = -0.55;
      playerY = 0.45;
      botX = 0.55;
      botY = -0.35;
      playerHealth = playerMaxHealth;
      botHealth = 100;
      secondsLeft = 60;
      skillCooldown = 0;
      skillMessage = null;
      skillSucceeded = false;
      playerEffect = false;
      botEffect = false;
      finished = false;
      pickupVisible = true;
      pickupX = 0;
      pickupY = 0;
    });
    startTimers();
  }

  String get resultText {
    final playerRatio = playerHealth / playerMaxHealth;
    final botRatio = botHealth / 100;
    if (playerRatio == botRatio) return 'تعادل';
    return playerRatio > botRatio
        ? 'فوز ${widget.characterName}'
        : (isNetworkGame ? 'فوز اللاعب 2' : 'فوز الروبوت');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.arenaName} • ${widget.characterName}'),
        actions: [
          Center(
            child: Text(
              '$secondsLeft ث',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: _HealthBar(
                      label: widget.characterName,
                      value: playerHealth,
                      maxValue: playerMaxHealth,
                      icon: Icons.person,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HealthBar(
                      label: isNetworkGame ? 'اللاعب 2' : 'الروبوت',
                      value: botHealth,
                      maxValue: 100,
                      icon: Icons.smart_toy,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Chip(
                avatar: Icon(abilityIcon, size: 18),
                label: Text('مهارة ${widget.characterName}: $abilityText'),
              ),
            ),
            if (skillMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Material(
                  color: skillSucceeded
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Icon(skillSucceeded
                            ? Icons.check_circle
                            : Icons.info_outline),
                        const SizedBox(width: 8),
                        Expanded(child: Text(skillMessage!)),
                      ],
                    ),
                  ),
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
                      _ArenaBackground(arenaName: widget.arenaName),
                      if (pickupVisible)
                        Align(
                          alignment: Alignment(pickupX, pickupY),
                          child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.green, width: 3)), child: const Icon(Icons.medical_services, color: Colors.green)),
                        ),
                      Align(
                        alignment: Alignment(playerX, playerY),
                        child: _SkillPulse(
                          active: playerEffect,
                          child: _Fighter(
                            name: widget.characterName,
                            icon: Icons.sports_martial_arts,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment(botX, botY),
                        child: _SkillPulse(
                          active: botEffect,
                          child: _Fighter(
                            name: isNetworkGame ? 'اللاعب 2' : 'روبوت',
                            icon: isNetworkGame ? Icons.person : Icons.smart_toy,
                            color: Colors.red,
                          ),
                        ),
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
                                    Text(
                                      resultText,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'النمط: ${widget.mode} • ${widget.players} لاعبين',
                                    ),
                                    const SizedBox(height: 14),
                                    FilledButton.icon(
                                      onPressed: restart,
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _MovementPad(onMove: move, step: playerStep),
                  const Spacer(),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: canUseSkill ? useSkill : null,
                        icon: Icon(abilityIcon, size: 26),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            skillCooldown == 0
                                ? 'المهارة'
                                : 'انتظر $skillCooldown ث',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: attack,
                        icon: const Icon(Icons.flash_on, size: 30),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text('ضربة $playerDamage'),
                        ),
                      ),
                    ],
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

class _SkillPulse extends StatelessWidget {
  const _SkillPulse({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: active ? 1.35 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.all(active ? 8 : 0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Colors.amberAccent,
                    blurRadius: 24,
                    spreadRadius: 8,
                  ),
                ]
              : const [],
        ),
        child: child,
      ),
    );
  }
}

class _ArenaBackground extends StatelessWidget {
  const _ArenaBackground({required this.arenaName});

  final String arenaName;

  @override
  Widget build(BuildContext context) {
    final colors = switch (arenaName) {
      'الصحراء' => const [Color(0xFF78350F), Color(0xFFD97706), Color(0xFFFBBF24)],
      'الجليد' => const [Color(0xFF0C4A6E), Color(0xFF0284C7), Color(0xFFBAE6FD)],
      _ => const [Color(0xFF1B4332), Color(0xFF2D6A4F), Color(0xFF40916C)],
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
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
    canvas.drawOval(
      Rect.fromCenter(
        center: size.center(Offset.zero),
        width: size.width * 0.55,
        height: size.height * 0.45,
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(12, 12, size.width - 24, size.height - 24),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Fighter extends StatelessWidget {
  const _Fighter({
    required this.name,
    required this.icon,
    required this.color,
  });

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
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 34),
        ),
        const SizedBox(height: 3),
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
      ],
    );
  }
}

class _HealthBar extends StatelessWidget {
  const _HealthBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.icon,
  });

  final String label;
  final int value;
  final int maxValue;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 17),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                '$label • $value/$maxValue',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: value / maxValue,
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    );
  }
}

class _MovementPad extends StatelessWidget {
  const _MovementPad({required this.onMove, required this.step});

  final void Function(double dx, double dy) onMove;
  final double step;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: _MoveButton(
              icon: Icons.keyboard_arrow_up,
              onTap: () => onMove(0, -step),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _MoveButton(
              icon: Icons.keyboard_arrow_down,
              onTap: () => onMove(0, step),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: _MoveButton(
              icon: Icons.keyboard_arrow_left,
              onTap: () => onMove(-step, 0),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _MoveButton(
              icon: Icons.keyboard_arrow_right,
              onTap: () => onMove(step, 0),
            ),
          ),
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
    return IconButton.filledTonal(
      onPressed: onTap,
      icon: Icon(icon, size: 30),
    );
  }
}
