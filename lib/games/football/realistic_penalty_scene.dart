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

  double _phase(
    double start,
    double end, [
    Curve curve = Curves.linear,
  ]) {
    final raw = ((shotProgress - start) / (end - start))
        .clamp(0.0, 1.0)
        .toDouble();
    return curve.transform(raw);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final goalRect = _goalRect(size);

        // A complete kick is deliberately split into human-readable phases:
        // settle -> run-up -> plant -> strike -> ball flight -> recovery.
        final runT = _phase(0.12, 0.47, Curves.easeInOutCubic);
        final plantT = _phase(0.43, 0.55, Curves.easeOutCubic);
        final strikeT = _phase(0.52, 0.67, Curves.easeInOutCubic);
        final flightT = _phase(0.60, 0.86, Curves.easeInCubic);
        final keeperDiveT = _phase(0.66, 0.92, Curves.easeOutCubic);
        final recoveryT = _phase(0.90, 1.00, Curves.easeOutCubic);
        final impactT = _phase(0.82, 0.91, Curves.easeOutCubic);

        final shakeStrength = sin(impactT * pi * 7) *
            (1 - impactT) *
            (1.5 + shotPower * 1.5);

        final shooterPose = shotProgress < 0.12
            ? FootballSpritePose.playerReady
            : shotProgress < 0.52
                ? FootballSpritePose.playerRun
                : FootballSpritePose.playerKick;

        final runBounce = sin(runT * pi * 5) * (1 - plantT) * size.height * 0.007;
        final shooterLeft = _lerp(
          -size.width * 0.04,
          size.width * 0.28,
          runT,
        );
        final shooterBottom = size.height * 0.025 + runBounce;
        final followThrough = strikeT * size.width * 0.035;
        final shooterRotation = _lerp(-0.035, 0.025, runT) - strikeT * 0.045;
        final shooterScaleY = 1.0 - plantT * 0.025 + recoveryT * 0.018;

        final keeperStart = Offset(
          goalRect.center.dx,
          goalRect.bottom - goalRect.height * 0.04,
        );
        final keeperTarget = Offset(
          goalRect.left + goalRect.width * keeperX,
          goalRect.top + goalRect.height * keeperY,
        );
        var keeperCenter = Offset.lerp(
          keeperStart,
          keeperTarget,
          keeperDiveT,
        )!;
        keeperCenter = keeperCenter.translate(
          0,
          recoveryT * goalRect.height * 0.08,
        );

        final diving = keeperDiveT > 0.015;
        final keeperDirection = (keeperX - 0.5).sign;
        final keeperRotation = diving
            ? keeperDirection * (0.18 + keeperDiveT * 0.78) * (1 - recoveryT * 0.35)
            : sin(ambientProgress * pi * 2) * 0.012;
        final keeperWidth = diving ? size.width * 0.48 : size.width * 0.27;
        final keeperHeight = diving ? size.height * 0.22 : size.height * 0.27;

        return Transform.translate(
          offset: Offset(shakeStrength, -shakeStrength * 0.18),
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
                    painter: _ArenaPainter(
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
                  Positioned(
                    left: keeperCenter.dx - keeperWidth / 2,
                    top: keeperCenter.dy - keeperHeight * 0.69,
                    width: keeperWidth,
                    height: keeperHeight,
                    child: Transform.rotate(
                      angle: keeperRotation,
                      alignment: Alignment.center,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: RealisticFootballSprite(
                          key: ValueKey<bool>(diving),
                          pose: diving
                              ? FootballSpritePose.keeperDive
                              : FootballSpritePose.keeperReady,
                          primary: const Color(0xFFFFA000),
                          secondary: const Color(0xFF18232D),
                          mirror: keeperDirection < 0,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: shooterLeft + followThrough,
                    bottom: shooterBottom,
                    width: size.width *
                        (shooterPose == FootballSpritePose.playerKick
                            ? 0.56
                            : 0.39),
                    height: size.height * 0.46,
                    child: Transform.rotate(
                      angle: shooterRotation,
                      alignment: Alignment.bottomCenter,
                      child: Transform.scale(
                        scaleY: shooterScaleY,
                        alignment: Alignment.bottomCenter,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: Tween<double>(begin: 0.96, end: 1.0)
                                    .animate(animation),
                                alignment: Alignment.bottomCenter,
                                child: child,
                              ),
                            );
                          },
                          child: RealisticFootballSprite(
                            key: ValueKey<FootballSpritePose>(shooterPose),
                            pose: shooterPose,
                            primary: shootingTeam.primary,
                            secondary: shootingTeam.secondary,
                          ),
                        ),
                      ),
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
                                color: Color(0xA6000000),
                                borderRadius: BorderRadius.all(Radius.circular(14)),
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

class _ArenaPainter extends CustomPainter {
  const _ArenaPainter({
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
    _drawSky(canvas, size);
    _drawStadium(canvas, size);
    _drawPitch(canvas, size);
    _drawGoal(canvas, goalRect);
    _drawPlayerAndKeeperShadows(canvas, size, goalRect);

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
  }

  void _drawSky(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF02050B),
            Color(0xFF071A2B),
            Color(0xFF123D50),
          ],
          stops: <double>[0, 0.36, 0.64],
        ).createShader(rect),
    );

    for (final x in <double>[0.08, 0.92]) {
      final center = Offset(size.width * x, size.height * 0.045);
      canvas.drawCircle(
        center,
        size.width * 0.17,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              Colors.white.withOpacity(0.28),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: size.width * 0.17),
          ),
      );
    }
  }

  void _drawStadium(Canvas canvas, Size size) {
    final stands = Rect.fromLTWH(
      0,
      size.height * 0.12,
      size.width,
      size.height * 0.27,
    );
    canvas.drawRect(stands, Paint()..color = const Color(0xFF07111C));

    for (var row = 0; row < 5; row++) {
      canvas.drawRect(
        Rect.fromLTWH(
          0,
          size.height * (0.14 + row * 0.047),
          size.width,
          size.height * 0.036,
        ),
        Paint()
          ..color = row.isEven
              ? const Color(0xFF142435)
              : const Color(0xFF0D1925),
      );
    }

    final random = Random(93);
    final pulse = 0.55 + sin(ambientProgress * pi * 2) * 0.07;
    const colors = <Color>[
      Color(0xFFFFE5A0),
      Color(0xFF9ED9FF),
      Color(0xFFFF8B8B),
      Color(0xFFB4F0C5),
    ];
    for (var i = 0; i < 500; i++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          size.height * 0.145 + random.nextDouble() * size.height * 0.20,
        ),
        0.55 + random.nextDouble() * 0.8,
        Paint()..color = colors[i % colors.length].withOpacity(pulse),
      );
    }

    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.355, size.width, size.height * 0.033),
      Paint()..color = const Color(0xFF020810),
    );
    final banner = TextPainter(
      text: const TextSpan(
        text: 'GAMESLOCAL   •   PENALTY NIGHT   •   PLAY LOCAL',
        style: TextStyle(
          color: Color(0xFFFFD25A),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: size.width - 20);
    banner.paint(canvas, Offset(10, size.height * 0.36));
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
          colors: <Color>[
            Color(0xFF1B9250),
            Color(0xFF08713A),
            Color(0xFF034923),
          ],
        ).createShader(
          Rect.fromLTWH(0, size.height * 0.35, size.width, size.height * 0.65),
        ),
    );

    for (var stripe = 0; stripe < 9; stripe++) {
      final t0 = stripe / 9;
      final t1 = (stripe + 1) / 9;
      final path = Path()
        ..moveTo(
          _lerp(size.width * 0.16, 0, t0),
          _lerp(size.height * 0.37, size.height, t0),
        )
        ..lineTo(
          _lerp(size.width * 0.84, size.width, t0),
          _lerp(size.height * 0.37, size.height, t0),
        )
        ..lineTo(
          _lerp(size.width * 0.84, size.width, t1),
          _lerp(size.height * 0.37, size.height, t1),
        )
        ..lineTo(
          _lerp(size.width * 0.16, 0, t1),
          _lerp(size.height * 0.37, size.height, t1),
        )
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = stripe.isEven
              ? Colors.white.withOpacity(0.025)
              : Colors.black.withOpacity(0.055),
      );
    }

    final line = Paint()
      ..color = Colors.white.withOpacity(0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final box = Path()
      ..moveTo(size.width * 0.18, size.height * 0.42)
      ..lineTo(size.width * 0.82, size.height * 0.42)
      ..lineTo(size.width * 0.95, size.height * 0.74)
      ..lineTo(size.width * 0.05, size.height * 0.74)
      ..close();
    canvas.drawPath(box, line);
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.79),
      4,
      Paint()..color = Colors.white,
    );
  }

  void _drawGoal(Canvas canvas, Rect rect) {
    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawRect(rect.shift(const Offset(2, 5)), shadow);

    final net = Paint()
      ..color = Colors.white.withOpacity(0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i <= 14; i++) {
      final t = i / 14;
      canvas.drawLine(
        Offset(_lerp(rect.left, rect.right, t), rect.top),
        Offset(
          _lerp(rect.left + rect.width * 0.035, rect.right - rect.width * 0.035, t),
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
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Colors.white, Color(0xFFB9C5D0), Colors.white],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawPlayerAndKeeperShadows(Canvas canvas, Size size, Rect goalRect) {
    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.42, size.height * 0.91),
        width: size.width * 0.28,
        height: size.height * 0.035,
      ),
      shadow,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(goalRect.center.dx, goalRect.bottom + 8),
        width: goalRect.width * 0.26,
        height: 12,
      ),
      shadow,
    );
  }

  void _drawTarget(Canvas canvas, Offset center) {
    final pulse = 1 + sin(ambientProgress * pi * 2) * 0.08;
    final radius = 17.0 * pulse;
    final paint = Paint()
      ..color = const Color(0xFFFFD25A).withOpacity(0.92)
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
    double ballScale;
    if (shotProgress < 0.60) {
      center = start;
      ballScale = 1;
    } else {
      final sideBend = (targetX - 0.5) * size.width * 0.12;
      final lift = size.height * (0.22 + shotPower * 0.08);
      final control = Offset(
        (start.dx + end.dx) / 2 + sideBend,
        min(start.dy, end.dy) - lift,
      );
      center = _quadraticBezier(start, control, end, flightT);
      ballScale = _lerp(1.0, 0.43, flightT);

      if (shotPower > 0.82 && flightT > 0.08 && flightT < 0.92) {
        final previousT = max(0.0, flightT - 0.075);
        final previous = _quadraticBezier(start, control, end, previousT);
        canvas.drawLine(
          previous,
          center,
          Paint()
            ..color = Colors.white.withOpacity(0.18 * shotPower)
            ..strokeWidth = 3.5 * ballScale
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    final groundY = _lerp(start.dy + 15, goalRect.bottom + 8, flightT);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, groundY),
        width: 38 * ballScale * (1 - flightT * 0.3),
        height: 11 * ballScale,
      ),
      Paint()
        ..color = Colors.black.withOpacity(0.32 * (1 - flightT * 0.25))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(flightT * pi * (5 + shotPower * 5));
    final radius = 14.5 * ballScale;
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
    final patch = Paint()..color = const Color(0xFF151A20);
    canvas.drawPath(
      Path()
        ..moveTo(0, -radius * 0.45)
        ..lineTo(radius * 0.42, -radius * 0.12)
        ..lineTo(radius * 0.26, radius * 0.38)
        ..lineTo(-radius * 0.26, radius * 0.38)
        ..lineTo(-radius * 0.42, -radius * 0.12)
        ..close(),
      patch,
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
      ..color = Colors.white.withOpacity(0.42 * impact)
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

  @override
  bool shouldRepaint(covariant _ArenaPainter oldDelegate) {
    return oldDelegate.shotProgress != shotProgress ||
        oldDelegate.ambientProgress != ambientProgress ||
        oldDelegate.targetX != targetX ||
        oldDelegate.targetY != targetY ||
        oldDelegate.shotPower != shotPower ||
        oldDelegate.goal != goal ||
        oldDelegate.showTarget != showTarget;
  }
}
