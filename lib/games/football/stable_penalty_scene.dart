import 'dart:math';

import 'package:flutter/material.dart';

import 'penalty_shootout_game.dart' show FootballTeam;

/// Stable penalty scene that always keeps the complete player, goalkeeper and
/// goal artwork on screen. The background artwork is never cropped, zoomed or
/// panned outside the viewport.
class StablePenaltyScene extends StatelessWidget {
  const StablePenaltyScene({
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
        final side = min(size.width, size.height);
        final sceneRect = Rect.fromLTWH(
          (size.width - side) / 2,
          (size.height - side) / 2,
          side,
          side,
        );
        final goalRect = Rect.fromLTWH(
          sceneRect.left + sceneRect.width * 0.12,
          sceneRect.top + sceneRect.height * 0.205,
          sceneRect.width * 0.76,
          sceneRect.height * 0.315,
        );
        final flightT = _phase(shotProgress, 0.58, 0.86, Curves.easeInCubic);
        final impactT = _phase(shotProgress, 0.82, 0.94, Curves.easeOutCubic);
        final shake = sin(impactT * pi * 7) * (1 - impactT) * 2.2;

        return Transform.translate(
          offset: Offset(shake, -shake * 0.15),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: enabled
                  ? (details) {
                      if (!goalRect.contains(details.localPosition)) return;
                      final x = ((details.localPosition.dx - goalRect.left) /
                              goalRect.width)
                          .clamp(0.0, 1.0)
                          .toDouble();
                      final y = ((details.localPosition.dy - goalRect.top) /
                              goalRect.height)
                          .clamp(0.0, 1.0)
                          .toDouble();
                      onShoot(x, y);
                    }
                  : null,
              child: Stack(
                key: const ValueKey<String>('stable-full-player-keeper-scene'),
                fit: StackFit.expand,
                children: <Widget>[
                  const ColoredBox(color: Color(0xFF020711)),
                  Positioned.fromRect(
                    rect: sceneRect,
                    child: Image.asset(
                      'assets/football/pro_penalty_arena.jpg',
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      filterQuality: FilterQuality.high,
                      isAntiAlias: true,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) {
                        return const ColoredBox(
                          color: Color(0xFF401018),
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'تعذر تحميل مشهد كرة القدم',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned.fromRect(
                    rect: sceneRect,
                    child: const IgnorePointer(child: _SoftGrade()),
                  ),
                  if (enabled && shotProgress == 0)
                    Positioned.fromRect(
                      rect: goalRect,
                      child: const IgnorePointer(child: _GoalGrid()),
                    ),
                  if (enabled && shotProgress == 0)
                    Positioned(
                      left: goalRect.left + goalRect.width * targetX - 24,
                      top: goalRect.top + goalRect.height * targetY - 24,
                      child: const IgnorePointer(child: _TargetReticle()),
                    ),
                  CustomPaint(
                    painter: _ShotOverlayPainter(
                      shotProgress: shotProgress,
                      sceneRect: sceneRect,
                      goalRect: goalRect,
                      targetX: targetX,
                      targetY: targetY,
                      shotPower: shotPower,
                      teamColor: shootingTeam.primary,
                      flightT: flightT,
                      goal: goal,
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xD906101A),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          shotProgress == 0
                              ? (enabled
                                  ? 'المس الزاوية المطلوبة داخل المرمى'
                                  : 'بانتظار دورك')
                              : (goal ? 'تسديدة نحو المرمى' : 'محاولة تصدٍ'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
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

double _phase(double value, double start, double end, Curve curve) {
  return curve.transform(((value - start) / (end - start)).clamp(0.0, 1.0));
}

class _SoftGrade extends StatelessWidget {
  const _SoftGrade();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            const Color(0xFF020713).withOpacity(0.12),
            Colors.transparent,
            Colors.transparent,
            const Color(0xFF01040A).withOpacity(0.26),
          ],
          stops: const <double>[0, 0.24, 0.74, 1],
        ),
      ),
    );
  }
}

class _GoalGrid extends StatelessWidget {
  const _GoalGrid();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white70, width: 1.4),
        color: Colors.white.withOpacity(0.025),
      ),
      child: CustomPaint(painter: _GridPainter()),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.24)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(size.width * i / 3, 0),
        Offset(size.width * i / 3, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(0, size.height * i / 3),
        Offset(size.width, size.height * i / 3),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TargetReticle extends StatelessWidget {
  const _TargetReticle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE31B35).withOpacity(0.18),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0xFFE31B35), blurRadius: 13),
        ],
      ),
      child: const Center(
        child: Icon(Icons.add, color: Colors.white, size: 23),
      ),
    );
  }
}

class _ShotOverlayPainter extends CustomPainter {
  const _ShotOverlayPainter({
    required this.shotProgress,
    required this.sceneRect,
    required this.goalRect,
    required this.targetX,
    required this.targetY,
    required this.shotPower,
    required this.teamColor,
    required this.flightT,
    required this.goal,
  });

  final double shotProgress;
  final Rect sceneRect;
  final Rect goalRect;
  final double targetX;
  final double targetY;
  final double shotPower;
  final Color teamColor;
  final double flightT;
  final bool goal;

  @override
  void paint(Canvas canvas, Size size) {
    if (shotProgress == 0 || flightT <= 0) return;

    final start = Offset(
      sceneRect.left + sceneRect.width * 0.44,
      sceneRect.top + sceneRect.height * 0.76,
    );
    final end = Offset(
      goalRect.left + goalRect.width * targetX,
      goalRect.top + goalRect.height * targetY,
    );
    final control = Offset(
      (start.dx + end.dx) / 2 + (targetX - 0.5) * 42,
      min(start.dy, end.dy) - sceneRect.height * (0.13 + shotPower * 0.05),
    );
    final ball = _quadratic(start, control, end, flightT);
    final previous = _quadratic(start, control, end, max(0, flightT - 0.13));

    canvas.drawLine(
      previous,
      ball,
      Paint()
        ..color = teamColor.withOpacity(0.58)
        ..strokeWidth = 7 - flightT * 3.5
        ..strokeCap = StrokeCap.round,
    );

    final radius = 14 - flightT * 6;
    canvas.drawCircle(
      ball + Offset(3, 5),
      radius * 0.8,
      Paint()..color = Colors.black.withOpacity(0.30),
    );
    canvas.drawCircle(ball, radius, Paint()..color = Colors.white);
    canvas.drawCircle(
      ball - Offset(radius * 0.2, radius * 0.15),
      radius * 0.28,
      Paint()..color = const Color(0xFF242A33),
    );

    if (goal && flightT > 0.96) {
      canvas.drawCircle(
        end,
        22 + sin(flightT * pi * 8).abs() * 8,
        Paint()
          ..color = Colors.white.withOpacity(0.32)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  Offset _quadratic(Offset a, Offset b, Offset c, double t) {
    final inv = 1 - t;
    return Offset(
      inv * inv * a.dx + 2 * inv * t * b.dx + t * t * c.dx,
      inv * inv * a.dy + 2 * inv * t * b.dy + t * t * c.dy,
    );
  }

  @override
  bool shouldRepaint(covariant _ShotOverlayPainter oldDelegate) {
    return oldDelegate.shotProgress != shotProgress ||
        oldDelegate.targetX != targetX ||
        oldDelegate.targetY != targetY ||
        oldDelegate.shotPower != shotPower ||
        oldDelegate.goal != goal;
  }
}
