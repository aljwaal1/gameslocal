import 'dart:math';

import 'package:flutter/material.dart';

import 'penalty_shootout_game.dart' show FootballTeam;

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

  double _phase(double start, double end, [Curve curve = Curves.linear]) {
    final value = ((shotProgress - start) / (end - start))
        .clamp(0.0, 1.0)
        .toDouble();
    return curve.transform(value);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final goalRect = _goalRect(size);

        final runT = _phase(0.12, 0.47, Curves.easeInOutCubic);
        final plantT = _phase(0.43, 0.55, Curves.easeOutCubic);
        final strikeT = _phase(0.52, 0.67, Curves.easeInOutCubic);
        final flightT = _phase(0.60, 0.86, Curves.easeInCubic);
        final keeperDiveT = _phase(0.66, 0.92, Curves.easeOutCubic);
        final recoveryT = _phase(0.90, 1.00, Curves.easeOutCubic);
        final impactT = _phase(0.82, 0.91, Curves.easeOutCubic);

        final zoom = 1.02 + runT * 0.025 + strikeT * 0.035;
        final panX = (targetX - 0.5) * flightT * -18;
        final panY = -runT * 5 + recoveryT * 4;
        final shake = sin(impactT * pi * 8) * (1 - impactT) * 3.2;

        return Transform.translate(
          offset: Offset(shake, -shake * 0.18),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
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
                fit: StackFit.expand,
                children: <Widget>[
                  const ColoredBox(color: Color(0xFF03111E)),
                  Transform.translate(
                    offset: Offset(panX, panY),
                    child: Transform.scale(
                      scale: zoom,
                      child: Image.asset(
                        'assets/football/pro_penalty_arena.jpg',
                        fit: BoxFit.cover,
                        alignment: const Alignment(0.08, -0.06),
                        filterQuality: FilterQuality.high,
                        isAntiAlias: true,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                  const _CinematicGrade(),
                  if (enabled && shotProgress == 0)
                    Positioned.fromRect(
                      rect: goalRect,
                      child: const IgnorePointer(child: _GoalAimGrid()),
                    ),
                  if (enabled && shotProgress == 0)
                    Positioned(
                      left: goalRect.left + goalRect.width * targetX - 25,
                      top: goalRect.top + goalRect.height * targetY - 25,
                      child: const IgnorePointer(child: _AimReticle()),
                    ),
                  CustomPaint(
                    painter: _LiveShotPainter(
                      shotProgress: shotProgress,
                      ambientProgress: ambientProgress,
                      goalRect: goalRect,
                      targetX: targetX,
                      targetY: targetY,
                      keeperX: keeperX,
                      keeperY: keeperY,
                      shotPower: shotPower,
                      goal: goal,
                      flightT: flightT,
                      keeperDiveT: keeperDiveT,
                      impactT: impactT,
                      teamColor: shootingTeam.primary,
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: IgnorePointer(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        child: shotProgress == 0
                            ? _InstructionBar(
                                key: const ValueKey<String>('aim'),
                                enabled: enabled,
                              )
                            : _InstructionBar(
                                key: const ValueKey<String>('shot'),
                                enabled: false,
                                text: keeperDiveT < 0.08
                                    ? 'الكرة انطلقت...'
                                    : goal
                                        ? 'نحو الزاوية!'
                                        : 'الحارس قرأ التسديدة',
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

class _CinematicGrade extends StatelessWidget {
  const _CinematicGrade();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              const Color(0xFF020713).withOpacity(0.50),
              Colors.transparent,
              Colors.transparent,
              const Color(0xFF01040A).withOpacity(0.72),
            ],
            stops: const <double>[0, 0.24, 0.68, 1],
          ),
        ),
      ),
    );
  }
}

class _GoalAimGrid extends StatelessWidget {
  const _GoalAimGrid();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.30), width: 1.3),
        gradient: LinearGradient(
          colors: <Color>[
            Colors.transparent,
            const Color(0xFF1BD6A8).withOpacity(0.05),
          ],
        ),
      ),
      child: CustomPaint(painter: _AimGridPainter()),
    );
  }
}

class _AimGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.16)
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

class _AimReticle extends StatelessWidget {
  const _AimReticle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE51B32).withOpacity(0.18),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0xFFE51B32), blurRadius: 14),
        ],
      ),
      child: const Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFE51B32),
          ),
          child: SizedBox(width: 10, height: 10),
        ),
      ),
    );
  }
}

class _InstructionBar extends StatelessWidget {
  const _InstructionBar({
    super.key,
    required this.enabled,
    this.text,
  });

  final bool enabled;
  final String? text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xDD06101A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black54, blurRadius: 16),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            enabled ? Icons.ads_click : Icons.sports_soccer,
            color: const Color(0xFFFFD54F),
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text ??
                  (enabled
                      ? 'المس أي نقطة داخل المرمى لتنفيذ التسديدة'
                      : 'بانتظار دورك'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveShotPainter extends CustomPainter {
  const _LiveShotPainter({
    required this.shotProgress,
    required this.ambientProgress,
    required this.goalRect,
    required this.targetX,
    required this.targetY,
    required this.keeperX,
    required this.keeperY,
    required this.shotPower,
    required this.goal,
    required this.flightT,
    required this.keeperDiveT,
    required this.impactT,
    required this.teamColor,
  });

  final double shotProgress;
  final double ambientProgress;
  final Rect goalRect;
  final double targetX;
  final double targetY;
  final double keeperX;
  final double keeperY;
  final double shotPower;
  final bool goal;
  final double flightT;
  final double keeperDiveT;
  final double impactT;
  final Color teamColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (shotProgress == 0) return;

    final start = Offset(size.width * 0.54, size.height * 0.72);
    final end = Offset(
      goalRect.left + goalRect.width * targetX,
      goalRect.top + goalRect.height * targetY,
    );
    final control = Offset(
      (start.dx + end.dx) / 2 + (targetX - 0.5) * 45,
      min(start.dy, end.dy) - size.height * (0.16 + shotPower * 0.06),
    );
    final ball = _quadraticBezier(start, control, end, flightT);

    if (flightT > 0) {
      final trailStart = _quadraticBezier(
        start,
        control,
        end,
        max(0, flightT - 0.14),
      );
      final trailPaint = Paint()
        ..shader = LinearGradient(
          colors: <Color>[
            Colors.transparent,
            teamColor.withOpacity(0.48),
            Colors.white.withOpacity(0.88),
          ],
        ).createShader(Rect.fromPoints(trailStart, ball))
        ..strokeWidth = 9 - flightT * 5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(trailStart, ball, trailPaint);

      final radius = 15 - flightT * 7;
      canvas.drawCircle(
        ball + Offset(4, 6 + flightT * 3),
        radius * 0.82,
        Paint()..color = Colors.black.withOpacity(0.28),
      );
      canvas.drawCircle(
        ball,
        radius,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.35, -0.35),
            colors: <Color>[Colors.white, Color(0xFFD8DCE2), Color(0xFF272C34)],
            stops: <double>[0, 0.68, 1],
          ).createShader(Rect.fromCircle(center: ball, radius: radius)),
      );
      canvas.drawCircle(
        ball + Offset(radius * 0.22, -radius * 0.18),
        radius * 0.24,
        Paint()..color = const Color(0xFF14171C),
      );
    }

    if (keeperDiveT > 0) {
      final keeperPoint = Offset(
        goalRect.left + goalRect.width * keeperX,
        goalRect.top + goalRect.height * keeperY,
      );
      canvas.drawCircle(
        keeperPoint,
        24 + keeperDiveT * 8,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = const Color(0xFF38E29B).withOpacity(0.55 * (1 - impactT)),
      );
    }

    if (goal && impactT > 0) {
      _drawNetImpact(canvas, goalRect);
    }
  }

  void _drawNetImpact(Canvas canvas, Rect rect) {
    final center = Offset(
      rect.left + rect.width * targetX,
      rect.top + rect.height * targetY,
    );
    final ripple = 18 + impactT * 52;
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        center,
        ripple + i * 10,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 - i * 0.35
          ..color = Colors.white.withOpacity((1 - impactT) * (0.48 - i * 0.1)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LiveShotPainter oldDelegate) {
    return oldDelegate.shotProgress != shotProgress ||
        oldDelegate.ambientProgress != ambientProgress ||
        oldDelegate.targetX != targetX ||
        oldDelegate.targetY != targetY ||
        oldDelegate.goal != goal;
  }
}

Rect _goalRect(Size size) {
  return Rect.fromLTWH(
    size.width * 0.13,
    size.height * 0.29,
    size.width * 0.78,
    size.height * 0.25,
  );
}

Offset _quadraticBezier(Offset a, Offset b, Offset c, double t) {
  final inv = 1 - t;
  return Offset(
    inv * inv * a.dx + 2 * inv * t * b.dx + t * t * c.dx,
    inv * inv * a.dy + 2 * inv * t * b.dy + t * t * c.dy,
  );
}
