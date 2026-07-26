import 'dart:math';

import 'package:flutter/material.dart';

import 'penalty_shootout_game.dart' show FootballTeam;
import 'realistic_football_sprite.dart';

class RealisticPenaltyScene extends StatelessWidget {
  const RealisticPenaltyScene({
    super.key,
    required this.shotProgress,
    required this.ambientProgress,
    required this.shootingTeam,
    required this.targetX,
    required this.targetY,
    required this.keeperX,
    required this.keeperY,
    required this.shotPower,
    required this.goal,
    required this.enabled,
    required this.onShoot,
  });

  final double shotProgress;
  final double ambientProgress;
  final FootballTeam shootingTeam;
  final double targetX;
  final double targetY;
  final double keeperX;
  final double keeperY;
  final double shotPower;
  final bool goal;
  final bool enabled;
  final void Function(double x, double y) onShoot;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final goalRect = _goalRect(size);
        final runT = Curves.easeInOutCubic.transform(
          (shotProgress / 0.34).clamp(0.0, 1.0),
        );
        final diveT = Curves.easeOutCubic.transform(
          ((shotProgress - 0.20) / 0.48).clamp(0.0, 1.0),
        );
        final impactT = ((shotProgress - 0.50) / 0.22).clamp(0.0, 1.0);
        final shake = sin(impactT * pi * 7) * (1 - impactT) * 3.4;

        final shooterX = _lerp(size.width * 0.01, size.width * 0.31, runT);
        final shooterBottom = _lerp(size.height * 0.015, size.height * 0.055, runT);
        final shooterPose = shotProgress <= 0.02
            ? FootballSpritePose.playerReady
            : shotProgress < 0.29
                ? FootballSpritePose.playerRun
                : FootballSpritePose.playerKick;

        final keeperStart = Offset(
          goalRect.center.dx,
          goalRect.bottom - goalRect.height * 0.05,
        );
        final keeperTarget = Offset(
          goalRect.left + goalRect.width * keeperX,
          goalRect.top + goalRect.height * keeperY,
        );
        final keeperCenter = Offset.lerp(keeperStart, keeperTarget, diveT)!;
        final keeperDiving = shotProgress > 0.20;
        final keeperWidth = keeperDiving ? size.width * 0.39 : size.width * 0.23;
        final keeperHeight = keeperDiving ? size.height * 0.19 : size.height * 0.25;

        return Transform.translate(
          offset: Offset(shake, -shake * 0.18),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: enabled
                  ? (details) {
                      if (!goalRect.contains(details.localPosition)) return;
                      final x = ((details.localPosition.dx - goalRect.left) /
                              goalRect.width)
                          .clamp(0.0, 1.0);
                      final y = ((details.localPosition.dy - goalRect.top) /
                              goalRect.height)
                          .clamp(0.0, 1.0);
                      onShoot(x, y);
                    }
                  : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _RealisticArenaPainter(
                      shotProgress: shotProgress,
                      ambientProgress: ambientProgress,
                      targetX: targetX,
                      targetY: targetY,
                      shotPower: shotPower,
                      goal: goal,
                      showTarget: enabled,
                    ),
                  ),
                  Positioned(
                    left: keeperCenter.dx - keeperWidth / 2,
                    top: keeperCenter.dy - keeperHeight * 0.70,
                    width: keeperWidth,
                    height: keeperHeight,
                    child: Transform.rotate(
                      angle: keeperDiving ? (keeperX - 0.5) * 1.05 : 0,
                      child: RealisticFootballSprite(
                        key: ValueKey('keeper-$keeperDiving'),
                        pose: keeperDiving
                            ? FootballSpritePose.keeperDive
                            : FootballSpritePose.keeperReady,
                        primary: const Color(0xFFFFA000),
                        secondary: const Color(0xFF17212C),
                        mirror: keeperX < 0.5,
                      ),
                    ),
                  ),
                  Positioned(
                    left: shooterX,
                    bottom: shooterBottom,
                    width: size.width * (shooterPose == FootballSpritePose.playerKick ? 0.52 : 0.35),
                    height: size.height * 0.43,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 120),
                      switchInCurve: Curves.easeOut,
                      child: RealisticFootballSprite(
                        key: ValueKey(shooterPose),
                        pose: shooterPose,
                        primary: shootingTeam.primary,
                        secondary: shootingTeam.secondary,
                      ),
                    ),
                  ),
                  if (enabled && shotProgress == 0)
                    Positioned(
                      left: goalRect.left,
                      top: goalRect.top,
                      width: goalRect.width,
                      height: goalRect.height,
                      child: const IgnorePointer(
                        child: Center(
                          child: Text(
                            'اختر مكان التسديدة داخل المرمى',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Rect _goalRect(Size size) {
  return Rect.fromLTWH(
    size.width * 0.105,
    size.height * 0.105,
    size.width * 0.79,
    size.height * 0.31,
  );
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

Offset _quadraticBezier(Offset a, Offset b, Offset c, double t) {
  final inv = 1 - t;
  return Offset(
    inv * inv * a.dx + 2 * inv * t * b.dx + t * t * c.dx,
    inv * inv * a.dy + 2 * inv * t * b.dy + t * t * c.dy,
  );
}

class _RealisticArenaPainter extends CustomPainter {
  const _RealisticArenaPainter({
    required this.shotProgress,
    required this.ambientProgress,
    required this.targetX,
    required this.targetY,
    required this.shotPower,
    required this.goal,
    required this.showTarget,
  });

  final double shotProgress;
  final double ambientProgress;
  final double targetX;
  final double targetY;
  final double shotPower;
  final bool goal;
  final bool showTarget;

  @override
  void paint(Canvas canvas, Size size) {
    final goalRect = _goalRect(size);
    _drawSky(canvas, size);
    _drawStadium(canvas, size);
    _drawPitch(canvas, size);
    _drawGoal(canvas, goalRect);
    if (showTarget && shotProgress == 0) {
      _drawTarget(
        canvas,
        Offset(
          goalRect.left + goalRect.width * targetX,
          goalRect.top + goalRect.height * targetY,
        ),
      );
    }
    _drawBall(canvas, size, goalRect);
    if (goal && shotProgress > 0.72) {
      _drawNetImpact(canvas, goalRect);
    }
  }

  void _drawSky(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF02050C), Color(0xFF0A2236), Color(0xFF123F52)],
          stops: [0, 0.35, 0.62],
        ).createShader(rect),
    );
    for (final x in [0.08, 0.92]) {
      final center = Offset(size.width * x, size.height * 0.045);
      canvas.drawCircle(
        center,
        size.width * 0.16,
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.white.withOpacity(0.24), Colors.transparent],
          ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.16)),
      );
    }
  }

  void _drawStadium(Canvas canvas, Size size) {
    final standRect = Rect.fromLTWH(0, size.height * 0.12, size.width, size.height * 0.27);
    canvas.drawRect(standRect, Paint()..color = const Color(0xFF08121E));
    for (var i = 0; i < 5; i++) {
      canvas.drawRect(
        Rect.fromLTWH(0, size.height * (0.14 + i * 0.047), size.width, size.height * 0.036),
        Paint()..color = i.isEven ? const Color(0xFF142435) : const Color(0xFF0E1A27),
      );
    }
    final random = Random(93);
    final pulse = 0.55 + sin(ambientProgress * pi * 2) * 0.08;
    const colors = [Color(0xFFFFE5A0), Color(0xFF9ED9FF), Color(0xFFFF8B8B), Color(0xFFB4F0C5)];
    for (var i = 0; i < 520; i++) {
      final point = Offset(
        random.nextDouble() * size.width,
        size.height * 0.145 + random.nextDouble() * size.height * 0.20,
      );
      canvas.drawCircle(
        point,
        0.55 + random.nextDouble() * 0.85,
        Paint()..color = colors[i % colors.length].withOpacity(pulse),
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.355, size.width, size.height * 0.033),
      Paint()..color = const Color(0xFF020810),
    );
    final text = TextPainter(
      text: const TextSpan(
        text: 'GAMESLOCAL   •   PENALTY NIGHT   •   PLAY LOCAL',
        style: TextStyle(color: Color(0xFFFFD25A), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 20);
    text.paint(canvas, Offset(10, size.height * 0.36));
  }

  void _drawPitch(Canvas canvas, Size size) {
    final pitch = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.84, size.height * 0.37)
      ..lineTo(size.width * 0.16, size.height * 0.37)
      ..close();
    canvas.drawPath(
      pitch,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A914F), Color(0xFF08713A), Color(0xFF034923)],
        ).createShader(Rect.fromLTWH(0, size.height * 0.35, size.width, size.height * 0.65)),
    );
    for (var i = 0; i < 9; i++) {
      final y0 = _lerp(size.height * 0.37, size.height, i / 9);
      final y1 = _lerp(size.height * 0.37, size.height, (i + 1) / 9);
      final left0 = _lerp(size.width * 0.16, 0, i / 9);
      final left1 = _lerp(size.width * 0.16, 0, (i + 1) / 9);
      final right0 = _lerp(size.width * 0.84, size.width, i / 9);
      final right1 = _lerp(size.width * 0.84, size.width, (i + 1) / 9);
      final stripe = Path()
        ..moveTo(left0, y0)
        ..lineTo(right0, y0)
        ..lineTo(right1, y1)
        ..lineTo(left1, y1)
        ..close();
      canvas.drawPath(stripe, Paint()..color = i.isEven ? Colors.white.withOpacity(0.025) : Colors.black.withOpacity(0.055));
    }
    final line = Paint()
      ..color = Colors.white.withOpacity(0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final box = Path()
      ..moveTo(size.width * 0.18, size.height * 0.42)
      ..lineTo(size.width * 0.82, size.height * 0.42)
      ..lineTo(size.width * 0.95, size.height * 0.74)
      ..lineTo(size.width * 0.05, size.height * 0.74)
      ..close();
    canvas.drawPath(box, line);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.75), 4, Paint()..color = Colors.white);
  }

  void _drawGoal(Canvas canvas, Rect goalRect) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(goalRect.shift(const Offset(2, 5)).inflate(4), const Radius.circular(5)),
      Paint()..color = Colors.black.withOpacity(0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    final net = Paint()..color = Colors.white.withOpacity(0.31)..strokeWidth = 1.0;
    for (var i = 0; i <= 14; i++) {
      final t = i / 14;
      canvas.drawLine(
        Offset(_lerp(goalRect.left, goalRect.right, t), goalRect.top),
        Offset(_lerp(goalRect.left + 9, goalRect.right - 9, t), goalRect.bottom),
        net,
      );
    }
    for (var i = 0; i <= 8; i++) {
      final y = _lerp(goalRect.top, goalRect.bottom, i / 8);
      canvas.drawLine(Offset(goalRect.left, y), Offset(goalRect.right, y), net);
    }
    canvas.drawRect(
      goalRect,
      Paint()
        ..shader = const LinearGradient(colors: [Colors.white, Color(0xFFBFCBD5), Colors.white]).createShader(goalRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.5,
    );
  }

  void _drawTarget(Canvas canvas, Offset center) {
    final pulse = 1 + sin(ambientProgress * pi * 2) * 0.08;
    final paint = Paint()
      ..color = const Color(0xFFFFD25A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawCircle(center, 17 * pulse, paint);
    canvas.drawCircle(center, 8 * pulse, paint);
    canvas.drawLine(center.translate(-27, 0), center.translate(27, 0), paint);
    canvas.drawLine(center.translate(0, -27), center.translate(0, 27), paint);
  }

  void _drawBall(Canvas canvas, Size size, Rect goalRect) {
    final t = Curves.easeInCubic.transform(
      ((shotProgress - 0.24) / 0.54).clamp(0.0, 1.0),
    );
    final start = Offset(size.width * 0.53, size.height * 0.79);
    final end = Offset(
      goalRect.left + goalRect.width * targetX,
      goalRect.top + goalRect.height * targetY,
    );
    final control = Offset(
      _lerp(start.dx, end.dx, 0.48) + (targetX - 0.5) * 42,
      min(start.dy, end.dy) - size.height * (0.10 + shotPower * 0.08),
    );
    final position = _quadraticBezier(start, control, end, t);
    final radius = _lerp(size.width * 0.034, size.width * 0.015, t);
    final groundY = _lerp(start.dy + 7, goalRect.bottom + 8, t);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(position.dx, groundY), width: radius * 2.2, height: radius * 0.65),
      Paint()..color = Colors.black.withOpacity(0.30)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(t * pi * 7);
    canvas.drawCircle(Offset.zero, radius, Paint()..color = const Color(0xFFF8FAFC));
    final patch = Paint()..color = const Color(0xFF11151A);
    canvas.drawCircle(Offset.zero, radius * 0.29, patch);
    for (var i = 0; i < 5; i++) {
      final a = -pi / 2 + i * pi * 2 / 5;
      canvas.drawCircle(Offset(cos(a) * radius * 0.58, sin(a) * radius * 0.58), radius * 0.17, patch);
    }
    canvas.restore();
  }

  void _drawNetImpact(Canvas canvas, Rect goalRect) {
    final impact = ((shotProgress - 0.72) / 0.22).clamp(0.0, 1.0);
    final center = Offset(
      goalRect.left + goalRect.width * targetX,
      goalRect.top + goalRect.height * targetY,
    );
    final paint = Paint()..color = Colors.white.withOpacity((1 - impact) * 0.55)..style = PaintingStyle.stroke..strokeWidth = 1.4;
    for (var ring = 1; ring <= 4; ring++) {
      canvas.drawOval(
        Rect.fromCenter(center: center, width: ring * 24.0 * impact, height: ring * 15.0 * impact),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RealisticArenaPainter oldDelegate) {
    return oldDelegate.shotProgress != shotProgress ||
        oldDelegate.ambientProgress != ambientProgress ||
        oldDelegate.targetX != targetX ||
        oldDelegate.targetY != targetY ||
        oldDelegate.goal != goal ||
        oldDelegate.showTarget != showTarget ||
        oldDelegate.shotPower != shotPower;
  }
}
