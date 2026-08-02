import 'dart:math';

import 'package:flutter/material.dart';

import 'penalty_shootout_game.dart' show FootballTeam;

/// Professional penalty scene that keeps the complete cinematic artwork visible
/// while adding touch/swipe aiming, staged player motion, goalkeeper reaction,
/// curved ball physics, net ripple and broadcast-style lighting.
class StablePenaltyScene extends StatefulWidget {
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
  State<StablePenaltyScene> createState() => _StablePenaltySceneState();
}

class _StablePenaltySceneState extends State<StablePenaltyScene> {
  Offset? _dragStart;
  Offset? _dragCurrent;

  void _clearDrag() {
    if (_dragStart == null && _dragCurrent == null) return;
    setState(() {
      _dragStart = null;
      _dragCurrent = null;
    });
  }

  void _finishSwipe(Rect goalRect, Offset ballOrigin) {
    final current = _dragCurrent;
    if (!widget.enabled || current == null) {
      _clearDrag();
      return;
    }

    final delta = current - (_dragStart ?? ballOrigin);
    if (delta.dy > -24 && !goalRect.contains(current)) {
      _clearDrag();
      return;
    }

    final projected = Offset(
      current.dx.clamp(goalRect.left, goalRect.right),
      current.dy.clamp(goalRect.top, goalRect.bottom),
    );
    final x = ((projected.dx - goalRect.left) / goalRect.width)
        .clamp(0.0, 1.0)
        .toDouble();
    final y = ((projected.dy - goalRect.top) / goalRect.height)
        .clamp(0.0, 1.0)
        .toDouble();

    _clearDrag();
    widget.onShoot(x, y);
  }

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
        final ballOrigin = Offset(
          sceneRect.left + sceneRect.width * 0.52,
          sceneRect.top + sceneRect.height * 0.735,
        );

        final runT =
            _phase(widget.shotProgress, 0.08, 0.40, Curves.easeInOutCubic);
        final plantT =
            _phase(widget.shotProgress, 0.38, 0.52, Curves.easeOutCubic);
        final strikeT =
            _phase(widget.shotProgress, 0.48, 0.64, Curves.easeInOutCubic);
        final flightT =
            _phase(widget.shotProgress, 0.57, 0.89, Curves.easeInCubic);
        final keeperT =
            _phase(widget.shotProgress, 0.61, 0.91, Curves.easeOutCubic);
        final impactT =
            _phase(widget.shotProgress, 0.84, 0.97, Curves.easeOutCubic);
        final recoveryT =
            _phase(widget.shotProgress, 0.92, 1.00, Curves.easeOutCubic);

        final shake =
            sin(impactT * pi * 8) * (1 - impactT) * (widget.goal ? 2.6 : 4.0);

        return Transform.translate(
          offset: Offset(shake, -shake * 0.18),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: RepaintBoundary(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: widget.enabled
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
                        widget.onShoot(x, y);
                      }
                    : null,
                onPanStart: widget.enabled
                    ? (details) {
                        setState(() {
                          _dragStart = details.localPosition;
                          _dragCurrent = details.localPosition;
                        });
                      }
                    : null,
                onPanUpdate: widget.enabled
                    ? (details) {
                        setState(() => _dragCurrent = details.localPosition);
                      }
                    : null,
                onPanCancel: _clearDrag,
                onPanEnd: widget.enabled
                    ? (_) => _finishSwipe(goalRect, ballOrigin)
                    : null,
                child: Stack(
                  key: const ValueKey<String>(
                    'stable-full-player-keeper-scene',
                  ),
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
                      child: IgnorePointer(
                        child: _BroadcastLighting(
                          ambientProgress: widget.ambientProgress,
                          shotProgress: widget.shotProgress,
                        ),
                      ),
                    ),
                    if (widget.enabled && widget.shotProgress == 0)
                      Positioned.fromRect(
                        rect: goalRect,
                        child: const IgnorePointer(child: _GoalGrid()),
                      ),
                    if (widget.enabled && widget.shotProgress == 0)
                      Positioned(
                        left: goalRect.left +
                            goalRect.width * widget.targetX -
                            24,
                        top: goalRect.top +
                            goalRect.height * widget.targetY -
                            24,
                        child: const IgnorePointer(child: _TargetReticle()),
                      ),
                    CustomPaint(
                      painter: _ActorMotionPainter(
                        sceneRect: sceneRect,
                        goalRect: goalRect,
                        targetX: widget.targetX,
                        targetY: widget.targetY,
                        keeperX: widget.keeperX,
                        keeperY: widget.keeperY,
                        runT: runT,
                        plantT: plantT,
                        strikeT: strikeT,
                        keeperT: keeperT,
                        recoveryT: recoveryT,
                        goal: widget.goal,
                        teamColor: widget.shootingTeam.primary,
                      ),
                    ),
                    CustomPaint(
                      painter: _ShotOverlayPainter(
                        shotProgress: widget.shotProgress,
                        sceneRect: sceneRect,
                        goalRect: goalRect,
                        targetX: widget.targetX,
                        targetY: widget.targetY,
                        keeperX: widget.keeperX,
                        keeperY: widget.keeperY,
                        shotPower: widget.shotPower,
                        teamColor: widget.shootingTeam.primary,
                        flightT: flightT,
                        impactT: impactT,
                        goal: widget.goal,
                      ),
                    ),
                    if (_dragCurrent != null && widget.enabled)
                      CustomPaint(
                        painter: _SwipeGuidePainter(
                          start: _dragStart ?? ballOrigin,
                          current: _dragCurrent!,
                          ballOrigin: ballOrigin,
                          goalRect: goalRect,
                          color: widget.shootingTeam.primary,
                        ),
                      ),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: IgnorePointer(
                        child: _PowerBadge(power: widget.shotPower),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: IgnorePointer(
                        child: _PhaseBadge(
                          shotProgress: widget.shotProgress,
                          goal: widget.goal,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: IgnorePointer(
                        child: _InstructionBar(
                          enabled: widget.enabled,
                          shotProgress: widget.shotProgress,
                          keeperT: keeperT,
                          goal: widget.goal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

double _phase(double value, double start, double end, Curve curve) {
  return curve.transform(
    ((value - start) / (end - start)).clamp(0.0, 1.0).toDouble(),
  );
}

class _BroadcastLighting extends StatelessWidget {
  const _BroadcastLighting({
    required this.ambientProgress,
    required this.shotProgress,
  });

  final double ambientProgress;
  final double shotProgress;

  @override
  Widget build(BuildContext context) {
    final sweep = -1.4 + ambientProgress * 2.8;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(sweep - 0.45, -1),
              end: Alignment(sweep + 0.45, 1),
              colors: <Color>[
                Colors.transparent,
                Colors.white.withOpacity(0.035),
                Colors.transparent,
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.7),
              radius: 1.15,
              colors: <Color>[
                Colors.transparent,
                const Color(0xFF00111C).withOpacity(0.08),
                const Color(0xFF00040A).withOpacity(
                  0.34 + shotProgress * 0.10,
                ),
              ],
              stops: const <double>[0.24, 0.68, 1],
            ),
          ),
        ),
      ],
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
        border: Border.all(color: Colors.white70, width: 1.3),
        color: Colors.white.withOpacity(0.018),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF38D9FF).withOpacity(0.08),
            blurRadius: 16,
          ),
        ],
      ),
      child: CustomPaint(painter: _GridPainter()),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..strokeWidth = 0.9;
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
        color: const Color(0xFFE31B35).withOpacity(0.16),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0xFFE31B35), blurRadius: 14),
        ],
      ),
      child: const Center(
        child: Icon(Icons.add, color: Colors.white, size: 23),
      ),
    );
  }
}

class _ActorMotionPainter extends CustomPainter {
  const _ActorMotionPainter({
    required this.sceneRect,
    required this.goalRect,
    required this.targetX,
    required this.targetY,
    required this.keeperX,
    required this.keeperY,
    required this.runT,
    required this.plantT,
    required this.strikeT,
    required this.keeperT,
    required this.recoveryT,
    required this.goal,
    required this.teamColor,
  });

  final Rect sceneRect;
  final Rect goalRect;
  final double targetX;
  final double targetY;
  final double keeperX;
  final double keeperY;
  final double runT;
  final double plantT;
  final double strikeT;
  final double keeperT;
  final double recoveryT;
  final bool goal;
  final Color teamColor;

  @override
  void paint(Canvas canvas, Size size) {
    _paintPlayerMotion(canvas);
    _paintKeeperMotion(canvas);
  }

  void _paintPlayerMotion(Canvas canvas) {
    if (runT <= 0 && strikeT <= 0) return;

    final boot = Offset(
      sceneRect.left + sceneRect.width * (0.525 - runT * 0.012),
      sceneRect.top + sceneRect.height * (0.748 - runT * 0.018),
    );

    final glow = Paint()
      ..color = teamColor.withOpacity(0.20 * (1 - recoveryT))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13);
    canvas.drawOval(
      Rect.fromCenter(
        center: boot + Offset(-10 * runT, 2),
        width: 58 + strikeT * 24,
        height: 20 + strikeT * 12,
      ),
      glow,
    );

    if (strikeT > 0) {
      final arcPaint = Paint()
        ..color = Colors.white.withOpacity(0.50 * (1 - recoveryT))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4);
      final path = Path()
        ..moveTo(boot.dx - 34, boot.dy + 5)
        ..quadraticBezierTo(
          boot.dx - 2,
          boot.dy - 30 - strikeT * 12,
          boot.dx + 24 + strikeT * 12,
          boot.dy - 4,
        );
      canvas.drawPath(path, arcPaint);

      final impact = sin(strikeT * pi).clamp(0.0, 1.0);
      canvas.drawCircle(
        boot + const Offset(18, -3),
        9 + impact * 13,
        Paint()
          ..color = Colors.white.withOpacity(0.34 * impact)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      final turfPaint = Paint()..color = const Color(0xFF9BD26B);
      for (var i = 0; i < 7; i++) {
        final angle = -pi * 0.9 + i * 0.22;
        final distance = 10 + strikeT * (10 + i * 1.6);
        final particle =
            boot + Offset(cos(angle) * distance, sin(angle) * distance * 0.55);
        canvas.drawCircle(
          particle,
          max(0.7, 2.1 - strikeT),
          turfPaint..color = turfPaint.color.withOpacity(1 - strikeT * 0.65),
        );
      }
    }

    if (plantT > 0 && strikeT < 0.9) {
      canvas.drawOval(
        Rect.fromCenter(
          center: boot + const Offset(-18, 8),
          width: 28,
          height: 8,
        ),
        Paint()..color = Colors.black.withOpacity(0.32),
      );
    }
  }

  void _paintKeeperMotion(Canvas canvas) {
    if (keeperT <= 0) return;

    final start = Offset(
      goalRect.left + goalRect.width * 0.50,
      goalRect.top + goalRect.height * 0.57,
    );
    final destination = Offset(
      goalRect.left + goalRect.width * keeperX,
      goalRect.top + goalRect.height * keeperY,
    );
    final center = Offset.lerp(start, destination, keeperT)!;
    final direction = destination - start;
    final angle = atan2(direction.dy, direction.dx) * keeperT;

    final blurPaint = Paint()
      ..color = const Color(0xFF6BE7FF).withOpacity(0.22 * (1 - recoveryT))
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawLine(start, center, blurPaint);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle * 0.62);

    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF6BE7FF), Color(0xFF087FA5)],
      ).createShader(const Rect.fromLTWH(-16, -28, 32, 58));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-13, -24, 26, 49),
        const Radius.circular(12),
      ),
      bodyPaint,
    );

    final limbPaint = Paint()
      ..color = const Color(0xFF9AEFFF).withOpacity(0.96)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final stretch = 18 + keeperT * 17;
    canvas.drawLine(Offset.zero, Offset(-stretch, -6), limbPaint);
    canvas.drawLine(Offset.zero, Offset(stretch, -7), limbPaint);
    canvas.drawLine(const Offset(-5, 19), const Offset(-18, 33), limbPaint);
    canvas.drawLine(const Offset(5, 19), const Offset(18, 31), limbPaint);

    final glovePaint = Paint()
      ..color = Colors.white.withOpacity(0.95)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
    canvas.drawCircle(Offset(-stretch - 3, -7), 6.5, glovePaint);
    canvas.drawCircle(Offset(stretch + 3, -8), 6.5, glovePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ActorMotionPainter oldDelegate) {
    return oldDelegate.runT != runT ||
        oldDelegate.plantT != plantT ||
        oldDelegate.strikeT != strikeT ||
        oldDelegate.keeperT != keeperT ||
        oldDelegate.recoveryT != recoveryT ||
        oldDelegate.keeperX != keeperX ||
        oldDelegate.keeperY != keeperY ||
        oldDelegate.goal != goal;
  }
}

class _ShotOverlayPainter extends CustomPainter {
  const _ShotOverlayPainter({
    required this.shotProgress,
    required this.sceneRect,
    required this.goalRect,
    required this.targetX,
    required this.targetY,
    required this.keeperX,
    required this.keeperY,
    required this.shotPower,
    required this.teamColor,
    required this.flightT,
    required this.impactT,
    required this.goal,
  });

  final double shotProgress;
  final Rect sceneRect;
  final Rect goalRect;
  final double targetX;
  final double targetY;
  final double keeperX;
  final double keeperY;
  final double shotPower;
  final Color teamColor;
  final double flightT;
  final double impactT;
  final bool goal;

  @override
  void paint(Canvas canvas, Size size) {
    if (shotProgress == 0 || flightT <= 0) return;

    final start = Offset(
      sceneRect.left + sceneRect.width * 0.52,
      sceneRect.top + sceneRect.height * 0.735,
    );
    final target = Offset(
      goalRect.left + goalRect.width * targetX,
      goalRect.top + goalRect.height * targetY,
    );
    final keeperImpact = Offset(
      goalRect.left + goalRect.width * keeperX,
      goalRect.top + goalRect.height * keeperY,
    );
    final end = goal ? target : Offset.lerp(target, keeperImpact, 0.68)!;

    final bend = (targetX - 0.5) * sceneRect.width * 0.24;
    final lift = sceneRect.height * (0.20 + shotPower * 0.08);
    final controlA = Offset(
      start.dx + bend * 0.22,
      start.dy - lift * 0.72,
    );
    final controlB = Offset(
      end.dx - bend * 0.30,
      end.dy - lift * 0.18,
    );

    final ball = _cubic(start, controlA, controlB, end, flightT);

    final trailPath = Path();
    for (var i = 0; i <= 9; i++) {
      final t = max(0.0, flightT - (9 - i) * 0.018);
      final point = _cubic(start, controlA, controlB, end, t);
      if (i == 0) {
        trailPath.moveTo(point.dx, point.dy);
      } else {
        trailPath.lineTo(point.dx, point.dy);
      }
    }

    canvas.drawPath(
      trailPath,
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[
            teamColor.withOpacity(0.02),
            teamColor.withOpacity(0.48),
            Colors.white.withOpacity(0.92),
          ],
        ).createShader(Rect.fromPoints(start, ball))
        ..strokeWidth = 8.5 - flightT * 4.8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
    );

    final radius = 15.5 - flightT * 7.2;
    canvas.drawOval(
      Rect.fromCenter(
        center: ball + Offset(4, 7 + flightT * 4),
        width: radius * 1.7,
        height: radius * 0.72,
      ),
      Paint()
        ..color = Colors.black.withOpacity(0.34)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    final ballPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.35, -0.4),
        colors: <Color>[
          Colors.white,
          Color(0xFFE1E5EA),
          Color(0xFF5B616A),
        ],
        stops: <double>[0, 0.72, 1],
      ).createShader(Rect.fromCircle(center: ball, radius: radius));
    canvas.drawCircle(ball, radius, ballPaint);

    canvas.save();
    canvas.translate(ball.dx, ball.dy);
    canvas.rotate(flightT * pi * (5 + shotPower * 4));
    final panelPaint = Paint()..color = const Color(0xFF20252B);
    canvas.drawCircle(const Offset(0, -1), radius * 0.27, panelPaint);
    canvas.drawCircle(
      Offset(radius * 0.34, radius * 0.20),
      radius * 0.20,
      panelPaint,
    );
    canvas.drawCircle(
      Offset(-radius * 0.31, radius * 0.26),
      radius * 0.18,
      panelPaint,
    );
    canvas.restore();

    if (impactT > 0) {
      if (goal) {
        _paintNetRipple(canvas, end);
      } else {
        _paintSaveImpact(canvas, ball, end);
      }
    }
  }

  void _paintNetRipple(Canvas canvas, Offset impact) {
    final wave = sin(impactT * pi).abs();
    final ripplePaint = Paint()
      ..color = Colors.white.withOpacity(0.56 * (1 - impactT * 0.45))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    for (var i = 0; i < 3; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: impact,
          width: 24 + i * 20 + wave * 26,
          height: 14 + i * 12 + wave * 18,
        ),
        ripplePaint..color = ripplePaint.color.withOpacity(0.55 - i * 0.12),
      );
    }

    final netLine = Paint()
      ..color = Colors.white.withOpacity(0.34 * (1 - impactT))
      ..strokeWidth = 1.3;
    for (var i = -3; i <= 3; i++) {
      final offset = i * 10.0;
      canvas.drawLine(
        impact + Offset(offset, -18 - wave * 8),
        impact + Offset(offset * 1.18, 20 + wave * 12),
        netLine,
      );
    }
  }

  void _paintSaveImpact(Canvas canvas, Offset ball, Offset end) {
    final flash = sin(impactT * pi).abs();
    canvas.drawCircle(
      Offset.lerp(ball, end, 0.5)!,
      16 + flash * 18,
      Paint()
        ..color = const Color(0xFF7FE9FF).withOpacity(0.32 * flash)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
  }

  Offset _cubic(
    Offset a,
    Offset b,
    Offset c,
    Offset d,
    double t,
  ) {
    final inv = 1 - t;
    return Offset(
      inv * inv * inv * a.dx +
          3 * inv * inv * t * b.dx +
          3 * inv * t * t * c.dx +
          t * t * t * d.dx,
      inv * inv * inv * a.dy +
          3 * inv * inv * t * b.dy +
          3 * inv * t * t * c.dy +
          t * t * t * d.dy,
    );
  }

  @override
  bool shouldRepaint(covariant _ShotOverlayPainter oldDelegate) {
    return oldDelegate.shotProgress != shotProgress ||
        oldDelegate.targetX != targetX ||
        oldDelegate.targetY != targetY ||
        oldDelegate.keeperX != keeperX ||
        oldDelegate.keeperY != keeperY ||
        oldDelegate.shotPower != shotPower ||
        oldDelegate.goal != goal;
  }
}

class _SwipeGuidePainter extends CustomPainter {
  const _SwipeGuidePainter({
    required this.start,
    required this.current,
    required this.ballOrigin,
    required this.goalRect,
    required this.color,
  });

  final Offset start;
  final Offset current;
  final Offset ballOrigin;
  final Rect goalRect;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final end = Offset(
      current.dx.clamp(goalRect.left, goalRect.right),
      current.dy.clamp(goalRect.top, goalRect.bottom),
    );

    final path = Path()
      ..moveTo(ballOrigin.dx, ballOrigin.dy)
      ..quadraticBezierTo(
        (ballOrigin.dx + end.dx) / 2,
        min(ballOrigin.dy, end.dy) - 48,
        end.dx,
        end.dy,
      );

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.42)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withOpacity(0.88)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
      end,
      19,
      Paint()
        ..color = const Color(0xFFE31B35).withOpacity(0.18)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      end,
      19,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _SwipeGuidePainter oldDelegate) {
    return oldDelegate.start != start || oldDelegate.current != current;
  }
}

class _PowerBadge extends StatelessWidget {
  const _PowerBadge({required this.power});

  final double power;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xD906101A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.bolt, color: Color(0xFFFFD45C), size: 17),
          const SizedBox(width: 5),
          Text(
            '${(power * 100).round()}%',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseBadge extends StatelessWidget {
  const _PhaseBadge({
    required this.shotProgress,
    required this.goal,
  });

  final double shotProgress;
  final bool goal;

  @override
  Widget build(BuildContext context) {
    final String label;
    final IconData icon;
    if (shotProgress == 0) {
      label = 'READY';
      icon = Icons.sports_soccer;
    } else if (shotProgress < 0.57) {
      label = 'RUN-UP';
      icon = Icons.directions_run;
    } else if (shotProgress < 0.90) {
      label = 'SHOT';
      icon = Icons.speed;
    } else {
      label = goal ? 'GOAL' : 'SAVE';
      icon = goal ? Icons.check_circle : Icons.pan_tool_alt;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xD906101A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionBar extends StatelessWidget {
  const _InstructionBar({
    required this.enabled,
    required this.shotProgress,
    required this.keeperT,
    required this.goal,
  });

  final bool enabled;
  final double shotProgress;
  final double keeperT;
  final bool goal;

  @override
  Widget build(BuildContext context) {
    final String text;
    final IconData icon;
    if (shotProgress == 0) {
      text = enabled
          ? 'اسحب من الكرة نحو الزاوية أو المس داخل المرمى'
          : 'بانتظار دورك';
      icon = enabled ? Icons.swipe_up_alt : Icons.hourglass_top;
    } else if (shotProgress < 0.48) {
      text = 'اقتراب اللاعب...';
      icon = Icons.directions_run;
    } else if (shotProgress < 0.61) {
      text = 'لحظة التسديد';
      icon = Icons.sports_soccer;
    } else if (keeperT < 0.18) {
      text = 'الكرة في طريقها';
      icon = Icons.speed;
    } else {
      text = goal ? 'نحو الشباك!' : 'الحارس يطير للتصدي';
      icon = goal ? Icons.stadium : Icons.pan_tool_alt;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xE006101A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black54, blurRadius: 14),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, color: const Color(0xFFFFD45C), size: 19),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
