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

        // Human-paced sequence: settle, approach, plant, strike, flight,
        // goalkeeper reaction and recovery. The goalkeeper deliberately reacts
        // only after the ball has left the foot.
        final runT = _phase(0.12, 0.47, Curves.easeInOutCubic);
        final plantT = _phase(0.43, 0.55, Curves.easeOutCubic);
        final strikeT = _phase(0.52, 0.67, Curves.easeInOutCubic);
        final flightT = _phase(0.60, 0.86, Curves.easeInCubic);
        final keeperDiveT = _phase(0.66, 0.92, Curves.easeOutCubic);
        final recoveryT = _phase(0.90, 1.00, Curves.easeOutCubic);
        final impactT = _phase(0.82, 0.91, Curves.easeOutCubic);

        final pose = shotProgress < 0.12
            ? FootballSpritePose.playerReady
            : shotProgress < 0.48
                ? FootballSpritePose.playerRun
                : shotProgress < 0.68
                    ? FootballSpritePose.playerKick
                    : keeperDiveT < 0.08
                        ? FootballSpritePose.keeperReady
                        : FootballSpritePose.keeperDive;

        final photoAlignment = switch (pose) {
          FootballSpritePose.playerReady => const Alignment(0.15, 0.05),
          FootballSpritePose.playerRun => const Alignment(0.10, -0.04),
          FootballSpritePose.playerKick => const Alignment(-0.08, -0.02),
          FootballSpritePose.keeperReady => const Alignment(0.05, -0.05),
          FootballSpritePose.keeperDive => const Alignment(-0.05, -0.10),
        };

        final photoScale = 1.04 + runT * 0.045 + strikeT * 0.035;
        final panX = -runT * 0.045 + keeperDiveT * (keeperX - 0.5) * 0.07;
        final panY = plantT * 0.018 - keeperDiveT * 0.025 + recoveryT * 0.02;
        final photoOpacity = shotProgress == 0
            ? 0.42
            : _lerp(0.62, 0.88, min(1.0, runT + strikeT + keeperDiveT));

        final shake = sin(impactT * pi * 7) *
            (1 - impactT) *
            (1.2 + shotPower * 1.8);

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
                  CustomPaint(
                    painter: _ArenaBackgroundPainter(
                      ambientProgress: ambientProgress,
                    ),
                  ),
                  Positioned.fill(
                    child: Transform.translate(
                      offset: Offset(size.width * panX, size.height * panY),
                      child: Transform.scale(
                        scale: photoScale,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 360),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: Tween<double>(begin: 1.035, end: 1.0)
                                    .animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: Opacity(
                            key: ValueKey<FootballSpritePose>(pose),
                            opacity: photoOpacity,
                            child: RealisticFootballSprite(
                              pose: pose,
                              primary: shootingTeam.primary,
                              secondary: shootingTeam.secondary,
                              mirror: pose == FootballSpritePose.keeperDive &&
                                  keeperX < 0.5,
                              alignment: photoAlignment,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Positioned.fill(child: _BroadcastGrade()),
                  CustomPaint(
                    painter: _ArenaForegroundPainter(
                      shotProgress: shotProgress,
                      ambientProgress: ambientProgress,
                      targetX: targetX,
                      targetY: targetY,
                      shotPower: shotPower,
                      goal: goal,
                      showTarget: enabled,
                      flightT: flightT,
                      impactT: impactT,
                    ),
                  ),
                  if (enabled && shotProgress == 0)
                    Positioned.fromRect(
                      rect: goalRect,
                      child: const IgnorePointer(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0xB0000000),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(14),
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                child: Text(
                                  'المس الموضع الذي تريد تسديد الكرة إليه',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
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

class _BroadcastGrade extends StatelessWidget {
  const _BroadcastGrade();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              const Color(0xFF020710).withOpacity(0.18),
              Colors.transparent,
              const Color(0xFF020710).withOpacity(0.22),
              const Color(0xFF020710).withOpacity(0.62),
            ],
            stops: const <double>[0, 0.36, 0.68, 1],
          ),
        ),
      ),
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

class _ArenaBackgroundPainter extends CustomPainter {
  const _ArenaBackgroundPainter({required this.ambientProgress});

  final double ambientProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF02050B),
            Color(0xFF0A2535),
            Color(0xFF0A5935),
            Color(0xFF023D21),
          ],
          stops: <double>[0, 0.34, 0.54, 1],
        ).createShader(rect),
    );

    final glow = 0.18 + sin(ambientProgress * pi * 2) * 0.025;
    for (final x in <double>[0.08, 0.92]) {
      final center = Offset(size.width * x, size.height * 0.045);
      canvas.drawCircle(
        center,
        size.width * 0.18,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              Colors.white.withOpacity(glow),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: size.width * 0.18),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArenaBackgroundPainter oldDelegate) {
    return oldDelegate.ambientProgress != ambientProgress;
  }
}

class _ArenaForegroundPainter extends CustomPainter {
  const _ArenaForegroundPainter({
    required this.shotProgress,
    required this.ambientProgress,
    required this.targetX,
    required this.targetY,
    required this.shotPower,
    required this.goal,
    required this.showTarget,
    required this.flightT,
    required this.impactT,
  });

  final double shotProgress;
  final double ambientProgress;
  final double targetX;
  final double targetY;
  final double shotPower;
  final bool goal;
  final bool showTarget;
  final double flightT;
  final double impactT;

  @override
  void paint(Canvas canvas, Size size) {
    final goalRect = _goalRect(size);
    _drawPitchPerspective(canvas, size);
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
    if (goal && impactT > 0) {
      _drawNetImpact(canvas, goalRect);
    }
    _drawVignette(canvas, size);
  }

  void _drawPitchPerspective(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withOpacity(0.48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7;
    final box = Path()
      ..moveTo(size.width * 0.18, size.height * 0.43)
      ..lineTo(size.width * 0.82, size.height * 0.43)
      ..lineTo(size.width * 0.95, size.height * 0.76)
      ..lineTo(size.width * 0.05, size.height * 0.76)
      ..close();
    canvas.drawPath(box, line);
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.80),
      3.5,
      Paint()..color = Colors.white.withOpacity(0.8),
    );
  }

  void _drawGoal(Canvas canvas, Rect rect) {
    final net = Paint()
      ..color = Colors.white.withOpacity(0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    for (var i = 0; i <= 14; i++) {
      final t = i / 14;
      canvas.drawLine(
        Offset(_lerp(rect.left, rect.right, t), rect.top),
        Offset(
          _lerp(
            rect.left + rect.width * 0.035,
            rect.right - rect.width * 0.035,
            t,
          ),
          rect.bottom,
        ),
        net,
      );
    }
    for (var i = 0; i <= 9; i++) {
      final t = i / 9;
      final inset = rect.width * 0.035 * t;
      canvas.drawLine(
        Offset(rect.left + inset, _lerp(rect.top, rect.bottom, t)),
        Offset(rect.right - inset, _lerp(rect.top, rect.bottom, t)),
        net,
      );
    }

    canvas.drawRect(
      rect.shift(const Offset(2, 4)),
      Paint()
        ..color = Colors.black.withOpacity(0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Colors.white, Color(0xFFB7C3CF), Colors.white],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawTarget(Canvas canvas, Offset center) {
    final pulse = 1 + sin(ambientProgress * pi * 2) * 0.08;
    final radius = 17.0 * pulse;
    final paint = Paint()
      ..color = const Color(0xFFFFD25A).withOpacity(0.94)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(center, radius * 0.5, paint);
    canvas.drawLine(
      Offset(center.dx - radius - 7, center.dy),
      Offset(center.dx + radius + 7, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius - 7),
      Offset(center.dx, center.dy + radius + 7),
      paint,
    );
  }

  void _drawBall(Canvas canvas, Size size, Rect goalRect) {
    final start = Offset(size.width * 0.515, size.height * 0.815);
    final end = Offset(
      goalRect.left + goalRect.width * targetX,
      goalRect.top + goalRect.height * targetY,
    );

    Offset center;
    double scale;
    if (shotProgress < 0.60) {
      center = start;
      scale = 1;
    } else {
      final sideBend = (targetX - 0.5) * size.width * 0.13;
      final lift = size.height * (0.21 + shotPower * 0.09);
      final control = Offset(
        (start.dx + end.dx) / 2 + sideBend,
        min(start.dy, end.dy) - lift,
      );
      center = _quadraticBezier(start, control, end, flightT);
      scale = _lerp(1.0, 0.42, flightT);

      if (shotPower > 0.82 && flightT > 0.08 && flightT < 0.92) {
        final previous = _quadraticBezier(
          start,
          control,
          end,
          max(0, flightT - 0.07),
        );
        canvas.drawLine(
          previous,
          center,
          Paint()
            ..color = Colors.white.withOpacity(0.20 * shotPower)
            ..strokeWidth = 3.2 * scale
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    final groundY = _lerp(start.dy + 15, goalRect.bottom + 8, flightT);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, groundY),
        width: 38 * scale * (1 - flightT * 0.3),
        height: 11 * scale,
      ),
      Paint()
        ..color = Colors.black.withOpacity(0.34)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(flightT * pi * (5 + shotPower * 5));
    final radius = 14.5 * scale;
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: <Color>[
            Colors.white,
            Color(0xFFF0F2F4),
            Color(0xFF9CA7B2),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, -radius * 0.45)
        ..lineTo(radius * 0.42, -radius * 0.12)
        ..lineTo(radius * 0.26, radius * 0.38)
        ..lineTo(-radius * 0.26, radius * 0.38)
        ..lineTo(-radius * 0.42, -radius * 0.12)
        ..close(),
      Paint()..color = const Color(0xFF151A20),
    );
    canvas.restore();
  }

  void _drawNetImpact(Canvas canvas, Rect rect) {
    final impact = sin(impactT * pi).abs();
    final center = Offset(
      rect.left + rect.width * targetX,
      rect.top + rect.height * targetY,
    );
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.44 * impact)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (var ring = 1; ring <= 4; ring++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: ring * 28.0 * impact,
          height: ring * 18.0 * impact,
        ),
        paint,
      );
    }
  }

  void _drawVignette(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.88,
          colors: <Color>[
            Colors.transparent,
            Colors.black.withOpacity(0.06),
            Colors.black.withOpacity(0.44),
          ],
          stops: const <double>[0.56, 0.80, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _ArenaForegroundPainter oldDelegate) {
    return oldDelegate.shotProgress != shotProgress ||
        oldDelegate.ambientProgress != ambientProgress ||
        oldDelegate.targetX != targetX ||
        oldDelegate.targetY != targetY ||
        oldDelegate.shotPower != shotPower ||
        oldDelegate.goal != goal ||
        oldDelegate.showTarget != showTarget;
  }
}
