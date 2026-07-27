import 'dart:math';

import 'package:flutter/material.dart';

import 'penalty_shootout_game.dart' show FootballTeam;

/// Professional penalty scene drawn entirely with Flutter.
///
/// The scene does not depend on a JPEG or SVG, so the player, goalkeeper,
/// goal and ball cannot disappear because of an unsupported image decoder.
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
  Offset? _dragAim;

  Rect _goalRect(Size size) => Rect.fromLTWH(
        size.width * 0.115,
        size.height * 0.145,
        size.width * 0.77,
        size.height * 0.285,
      );

  Offset? _aimFromPosition(Offset position, Size size) {
    final rect = _goalRect(size);
    if (!rect.inflate(18).contains(position)) return null;
    return Offset(
      ((position.dx - rect.left) / rect.width).clamp(0.03, 0.97).toDouble(),
      ((position.dy - rect.top) / rect.height).clamp(0.05, 0.95).toDouble(),
    );
  }

  void _updateDrag(Offset position, Size size) {
    if (!widget.enabled) return;
    final aim = _aimFromPosition(position, size);
    if (aim != null) setState(() => _dragAim = aim);
  }

  void _finishDrag() {
    final aim = _dragAim;
    if (aim == null || !widget.enabled) return;
    widget.onShoot(aim.dx, aim.dy);
    setState(() => _dragAim = null);
  }

  @override
  void didUpdateWidget(covariant StablePenaltyScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || widget.shotProgress > 0) _dragAim = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final aim = _dragAim ?? Offset(widget.targetX, widget.targetY);

        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: GestureDetector(
            key: const ValueKey<String>('procedural-professional-penalty-scene'),
            behavior: HitTestBehavior.opaque,
            onTapUp: widget.enabled
                ? (details) {
                    final value = _aimFromPosition(details.localPosition, size);
                    if (value != null) widget.onShoot(value.dx, value.dy);
                  }
                : null,
            onPanStart: widget.enabled
                ? (details) => _updateDrag(details.localPosition, size)
                : null,
            onPanUpdate: widget.enabled
                ? (details) => _updateDrag(details.localPosition, size)
                : null,
            onPanEnd: widget.enabled ? (_) => _finishDrag() : null,
            child: RepaintBoundary(
              child: CustomPaint(
                key: const ValueKey<String>('always-visible-football-actors'),
                painter: _ProfessionalArenaPainter(
                  shotProgress: widget.shotProgress,
                  ambientProgress: widget.ambientProgress,
                  targetX: aim.dx,
                  targetY: aim.dy,
                  keeperX: widget.keeperX,
                  keeperY: widget.keeperY,
                  shotPower: widget.shotPower,
                  isGoal: widget.goal,
                  enabled: widget.enabled,
                  primary: widget.shootingTeam.primary,
                  secondary: widget.shootingTeam.secondary,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfessionalArenaPainter extends CustomPainter {
  const _ProfessionalArenaPainter({
    required this.shotProgress,
    required this.ambientProgress,
    required this.targetX,
    required this.targetY,
    required this.keeperX,
    required this.keeperY,
    required this.shotPower,
    required this.isGoal,
    required this.enabled,
    required this.primary,
    required this.secondary,
  });

  final double shotProgress;
  final double ambientProgress;
  final double targetX;
  final double targetY;
  final double keeperX;
  final double keeperY;
  final double shotPower;
  final bool isGoal;
  final bool enabled;
  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final runT = _phase(shotProgress, 0.04, 0.48, Curves.easeInOutCubic);
    final kickT = _phase(shotProgress, 0.40, 0.64, Curves.easeInOutCubic);
    final flightT = _phase(shotProgress, 0.55, 0.90, Curves.easeInCubic);
    final diveT = _phase(shotProgress, 0.64, 0.92, Curves.easeOutCubic);
    final impactT = _phase(shotProgress, 0.88, 1.0, Curves.easeOutCubic);
    final goalRect = Rect.fromLTWH(
      size.width * 0.115,
      size.height * 0.145,
      size.width * 0.77,
      size.height * 0.285,
    );

    _drawStadium(canvas, size);
    _drawPitch(canvas, size);
    _drawGoalNet(canvas, goalRect, impactT);
    _drawKeeper(canvas, size, goalRect, diveT);
    _drawGoalPosts(canvas, goalRect, impactT);
    _drawPitchLines(canvas, size);
    _drawStriker(canvas, size, runT, kickT);
    _drawBallAndShot(canvas, size, goalRect, flightT, impactT);
    _drawStatus(canvas, size, flightT, diveT);
  }

  void _drawStadium(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    canvas.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF020611),
            Color(0xFF0A2037),
            Color(0xFF123A4C),
          ],
        ).createShader(full),
    );

    final stands = Rect.fromLTWH(0, size.height * 0.06, size.width, size.height * 0.35);
    canvas.drawRect(
      stands,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF0B1220), Color(0xFF233D55), Color(0xFF08131E)],
        ).createShader(stands),
    );

    final columns = max(18, (size.width / 13).floor()).toInt();
    const rows = 12;
    final crowdPaint = Paint();
    const crowdColors = <Color>[
      Color(0xFFE8F2F8),
      Color(0xFF5BC8FF),
      Color(0xFFFFD45D),
      Color(0xFFEF6372),
      Color(0xFF6BE0A1),
    ];
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final value = sin(column * 11.73 + row * 8.21) * 0.5 + 0.5;
        crowdPaint.color = crowdColors[(value * 4.99).floor()].withOpacity(0.30 + value * 0.48);
        final x = (column + 0.5) * size.width / columns;
        final y = stands.top + 20 + row * (stands.height - 38) / rows;
        canvas.drawCircle(Offset(x, y), 1.3 + value * 1.5, crowdPaint);
      }
    }

    for (final factor in <double>[0.08, 0.92]) {
      final center = Offset(size.width * factor, size.height * 0.07);
      canvas.drawCircle(center, 23, Paint()..color = Colors.white.withOpacity(0.08));
      canvas.drawCircle(center, 10, Paint()..color = Colors.white.withOpacity(0.94));
      canvas.drawCircle(center, 17, Paint()..color = const Color(0xFF75D5FF).withOpacity(0.22));
    }
  }

  void _drawPitch(Canvas canvas, Size size) {
    final pitch = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.85, size.height * 0.39)
      ..lineTo(size.width * 0.15, size.height * 0.39)
      ..close();
    canvas.drawPath(
      pitch,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF08713D), Color(0xFF159653), Color(0xFF07512D)],
        ).createShader(fullRect(size)),
    );

    final stripePaint = Paint()..color = Colors.white.withOpacity(0.035);
    for (var i = 0; i < 7; i += 2) {
      final top = size.height * (0.40 + i * 0.082);
      final bottom = size.height * (0.40 + (i + 1) * 0.082);
      canvas.drawRect(Rect.fromLTRB(0, top, size.width, bottom), stripePaint);
    }
  }

  void _drawPitchLines(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withOpacity(0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.4, size.width * 0.004).toDouble();
    final penaltyBox = Path()
      ..moveTo(size.width * 0.25, size.height * 0.40)
      ..lineTo(size.width * 0.10, size.height * 0.68)
      ..lineTo(size.width * 0.90, size.height * 0.68)
      ..lineTo(size.width * 0.75, size.height * 0.40);
    canvas.drawPath(penaltyBox, line);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.72),
        width: size.width * 0.48,
        height: size.height * 0.16,
      ),
      line,
    );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.70),
      max(2.5, size.width * 0.008).toDouble(),
      Paint()..color = Colors.white.withOpacity(0.85),
    );
  }

  void _drawGoalNet(Canvas canvas, Rect goalRect, double impactT) {
    final ripple = isGoal && impactT > 0
        ? sin(impactT * pi * 4) * (1 - impactT) * 8
        : 0.0;
    final netRect = Rect.fromLTRB(
      goalRect.left,
      goalRect.top,
      goalRect.right,
      goalRect.bottom + ripple,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(netRect.inflate(5), const Radius.circular(8)),
      Paint()
        ..color = Colors.black.withOpacity(0.34)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawRect(netRect, Paint()..color = const Color(0xFFDAF4FF).withOpacity(0.08));

    final netPaint = Paint()
      ..color = Colors.white.withOpacity(0.36)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    for (var i = 0; i <= 12; i++) {
      final x = netRect.left + netRect.width * i / 12;
      canvas.drawLine(
        Offset(x, netRect.top),
        Offset(x + ripple * 0.18, netRect.bottom),
        netPaint,
      );
    }
    for (var i = 0; i <= 6; i++) {
      final y = netRect.top + netRect.height * i / 6;
      canvas.drawLine(
        Offset(netRect.left, y),
        Offset(netRect.right, y + ripple * 0.10),
        netPaint,
      );
    }
  }

  void _drawGoalPosts(Canvas canvas, Rect goalRect, double impactT) {
    final postWidth = max(5.0, goalRect.width * 0.018).toDouble();
    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.40)
      ..strokeWidth = postWidth + 5
      ..strokeCap = StrokeCap.round;
    final post = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Colors.white, Color(0xFFB6CCD8), Colors.white],
      ).createShader(goalRect)
      ..strokeWidth = postWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(goalRect.topLeft + const Offset(3, 5), goalRect.topRight + const Offset(3, 5), shadow);
    canvas.drawLine(goalRect.topLeft + const Offset(3, 5), goalRect.bottomLeft + const Offset(3, 5), shadow);
    canvas.drawLine(goalRect.topRight + const Offset(3, 5), goalRect.bottomRight + const Offset(3, 5), shadow);
    canvas.drawLine(goalRect.topLeft, goalRect.topRight, post);
    canvas.drawLine(goalRect.topLeft, goalRect.bottomLeft, post);
    canvas.drawLine(goalRect.topRight, goalRect.bottomRight, post);

    if (isGoal && impactT > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(goalRect, const Radius.circular(8)),
        Paint()
          ..color = Colors.white.withOpacity((1 - impactT) * 0.20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 + impactT * 5,
      );
    }
  }

  void _drawKeeper(Canvas canvas, Size size, Rect goalRect, double diveT) {
    final scale = size.width / 390;
    final bounce = sin(ambientProgress * pi * 2) * size.height * 0.0035;
    final ready = Offset(
      goalRect.center.dx,
      goalRect.top + goalRect.height * 0.63 + bounce,
    );
    final requested = Offset(
      goalRect.left + goalRect.width * keeperX,
      goalRect.top + goalRect.height * keeperY,
    );
    final destination = Offset(
      requested.dx
          .clamp(
            goalRect.left + goalRect.width * 0.08,
            goalRect.right - goalRect.width * 0.08,
          )
          .toDouble(),
      requested.dy
          .clamp(
            goalRect.top + goalRect.height * 0.18,
            goalRect.bottom - goalRect.height * 0.04,
          )
          .toDouble(),
    );
    final center = Offset.lerp(ready, destination, diveT)!;
    final direction = (destination.dx - ready.dx).sign;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(direction * diveT * 0.72);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, 36 * scale),
        width: 66 * scale,
        height: 13 * scale,
      ),
      Paint()..color = Colors.black.withOpacity(0.28),
    );

    const brightGreen = Color(0xFF20D78B);
    final darkGreen = Color.lerp(brightGreen, Colors.black, 0.30)!;
    const skin = Color(0xFFC98E68);
    final limb = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final reach = (30 + diveT * 24) * scale;
    final rise = (6 + diveT * 15) * scale;
    limb
      ..color = brightGreen
      ..strokeWidth = 12 * scale;
    canvas.drawLine(Offset(-9 * scale, -12 * scale), Offset(-reach, -rise), limb);
    canvas.drawLine(Offset(9 * scale, -12 * scale), Offset(reach, -rise), limb);
    canvas.drawCircle(Offset(-reach, -rise), 8.5 * scale, Paint()..color = const Color(0xFFFFE45E));
    canvas.drawCircle(Offset(reach, -rise), 8.5 * scale, Paint()..color = const Color(0xFFFFE45E));

    final torso = Path()
      ..moveTo(-17 * scale, -21 * scale)
      ..quadraticBezierTo(-22 * scale, 1 * scale, -15 * scale, 20 * scale)
      ..lineTo(15 * scale, 20 * scale)
      ..quadraticBezierTo(22 * scale, 1 * scale, 17 * scale, -21 * scale)
      ..close();
    canvas.drawPath(
      torso,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[brightGreen, darkGreen],
        ).createShader(Rect.fromLTWH(-22 * scale, -22 * scale, 44 * scale, 44 * scale)),
    );
    canvas.drawPath(
      torso,
      Paint()
        ..color = Colors.white.withOpacity(0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * scale,
    );

    final spread = (17 + diveT * 11) * scale;
    limb
      ..color = const Color(0xFF162435)
      ..strokeWidth = 13 * scale;
    canvas.drawLine(Offset(-8 * scale, 17 * scale), Offset(-spread, 43 * scale), limb);
    canvas.drawLine(Offset(8 * scale, 17 * scale), Offset(spread, 43 * scale), limb);
    limb
      ..color = const Color(0xFFDCE9F0)
      ..strokeWidth = 7 * scale;
    canvas.drawLine(Offset(-spread, 43 * scale), Offset(-spread - 9 * scale, 45 * scale), limb);
    canvas.drawLine(Offset(spread, 43 * scale), Offset(spread + 9 * scale, 45 * scale), limb);

    canvas.drawCircle(Offset(0, -32 * scale), 12 * scale, Paint()..color = skin);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(0, -34 * scale), radius: 12 * scale),
      pi,
      pi,
      true,
      Paint()..color = const Color(0xFF251A18),
    );
    canvas.drawCircle(Offset(-4 * scale, -32 * scale), 1.1 * scale, Paint()..color = Colors.black87);
    canvas.drawCircle(Offset(4 * scale, -32 * scale), 1.1 * scale, Paint()..color = Colors.black87);
    canvas.restore();
  }

  void _drawStriker(Canvas canvas, Size size, double runT, double kickT) {
    final scale = size.width / 390;
    final start = Offset(size.width * 0.23, size.height * 0.80);
    final contact = Offset(size.width * 0.43, size.height * 0.755);
    final center = Offset.lerp(start, contact, runT)! +
        Offset(0, sin(runT * pi * 5) * 4 * scale);
    const skin = Color(0xFFC58A62);
    final darkKit = Color.lerp(primary, Colors.black, 0.34)!;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.08 - runT * 0.07 + kickT * 0.17);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(7 * scale, 69 * scale),
        width: 80 * scale,
        height: 15 * scale,
      ),
      Paint()..color = Colors.black.withOpacity(0.28),
    );

    final limb = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final armSwing = sin(runT * pi * 4) * 10 * scale;
    limb
      ..color = skin
      ..strokeWidth = 10 * scale;
    canvas.drawLine(Offset(-17 * scale, -18 * scale), Offset(-32 * scale, 6 * scale + armSwing), limb);
    canvas.drawLine(Offset(17 * scale, -17 * scale), Offset(32 * scale, 4 * scale - armSwing), limb);

    final jersey = Path()
      ..moveTo(-19 * scale, -28 * scale)
      ..lineTo(-28 * scale, -13 * scale)
      ..lineTo(-18 * scale, -7 * scale)
      ..lineTo(-14 * scale, 20 * scale)
      ..lineTo(15 * scale, 20 * scale)
      ..lineTo(18 * scale, -7 * scale)
      ..lineTo(28 * scale, -13 * scale)
      ..lineTo(19 * scale, -28 * scale)
      ..close();
    canvas.drawPath(
      jersey,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[primary, darkKit],
        ).createShader(Rect.fromLTWH(-29 * scale, -29 * scale, 58 * scale, 51 * scale)),
    );
    canvas.drawLine(
      Offset(-9 * scale, -24 * scale),
      Offset(-7 * scale, 16 * scale),
      Paint()
        ..color = secondary.withOpacity(0.88)
        ..strokeWidth = 3.5 * scale,
    );
    canvas.drawLine(
      Offset(9 * scale, -24 * scale),
      Offset(7 * scale, 16 * scale),
      Paint()
        ..color = secondary.withOpacity(0.88)
        ..strokeWidth = 3.5 * scale,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, 26 * scale),
          width: 36 * scale,
          height: 20 * scale,
        ),
        Radius.circular(5 * scale),
      ),
      Paint()..color = darkKit,
    );

    final plantedHip = Offset(-8 * scale, 32 * scale);
    final plantedKnee = Offset(-18 * scale, 54 * scale);
    final plantedFoot = Offset(-24 * scale, 74 * scale);
    final kickHip = Offset(8 * scale, 32 * scale);
    final kickKnee = Offset((16 - kickT * 4) * scale, (53 - kickT * 18) * scale);
    final kickFoot = Offset((22 + kickT * 35) * scale, (72 - kickT * 26) * scale);

    limb
      ..color = skin
      ..strokeWidth = 12 * scale;
    canvas.drawLine(plantedHip, plantedKnee, limb);
    canvas.drawLine(kickHip, kickKnee, limb);
    limb
      ..color = primary
      ..strokeWidth = 10 * scale;
    canvas.drawLine(plantedKnee, plantedFoot - Offset(0, 8 * scale), limb);
    canvas.drawLine(kickKnee, kickFoot - Offset(0, 8 * scale), limb);
    limb
      ..color = const Color(0xFFF3F6F8)
      ..strokeWidth = 8 * scale;
    canvas.drawLine(plantedFoot - Offset(0, 9 * scale), plantedFoot, limb);
    canvas.drawLine(kickFoot - Offset(0, 9 * scale), kickFoot, limb);
    limb
      ..color = const Color(0xFF17212C)
      ..strokeWidth = 7 * scale;
    canvas.drawLine(plantedFoot, plantedFoot + Offset(13 * scale, 1 * scale), limb);
    canvas.drawLine(kickFoot, kickFoot + Offset(14 * scale, -1 * scale), limb);

    canvas.drawCircle(Offset(0, -42 * scale), 13 * scale, Paint()..color = skin);
    final hair = Path()
      ..moveTo(-12 * scale, -44 * scale)
      ..quadraticBezierTo(0, -59 * scale, 12 * scale, -44 * scale)
      ..lineTo(9 * scale, -52 * scale)
      ..lineTo(4 * scale, -48 * scale)
      ..lineTo(0, -55 * scale)
      ..lineTo(-5 * scale, -48 * scale)
      ..lineTo(-10 * scale, -52 * scale)
      ..close();
    canvas.drawPath(hair, Paint()..color = const Color(0xFF211918));
    canvas.restore();
  }

  void _drawBallAndShot(
    Canvas canvas,
    Size size,
    Rect goalRect,
    double flightT,
    double impactT,
  ) {
    final start = Offset(size.width * 0.49, size.height * 0.82);
    final target = Offset(
      goalRect.left + goalRect.width * targetX,
      goalRect.top + goalRect.height * targetY,
    );
    final keeperTarget = Offset(
      goalRect.left + goalRect.width * keeperX,
      goalRect.top + goalRect.height * keeperY,
    );
    final end = isGoal ? target : Offset.lerp(target, keeperTarget, 0.72)!;
    final control = Offset(
      (start.dx + end.dx) / 2 + (targetX - 0.5) * size.width * 0.16,
      min(start.dy, end.dy) - size.height * (0.13 + shotPower * 0.065),
    );

    if (shotProgress == 0) {
      _drawBall(canvas, start, max(13.0, size.width * 0.038).toDouble(), ambientProgress * pi * 2);
      if (enabled) {
        _drawAimGuide(canvas, start, target);
        _drawTarget(canvas, target, size);
      }
      return;
    }

    if (flightT <= 0) {
      _drawBall(canvas, start, max(13.0, size.width * 0.038).toDouble(), 0);
      return;
    }

    final ball = _quadratic(start, control, end, flightT);
    final previous = _quadratic(start, control, end, max(0.0, flightT - 0.10).toDouble());
    canvas.drawLine(
      previous,
      ball,
      Paint()
        ..color = Colors.white.withOpacity(0.58)
        ..strokeWidth = max(3.0, size.width * 0.014 * (1 - flightT * 0.45)).toDouble()
        ..strokeCap = StrokeCap.round,
    );

    final groundY = _lerp(size.height * 0.84, goalRect.bottom, flightT);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(ball.dx + 4, groundY + 5),
        width: max(8.0, size.width * 0.055 * (1 - flightT * 0.62)).toDouble(),
        height: max(3.0, size.height * 0.012 * (1 - flightT * 0.55)).toDouble(),
      ),
      Paint()..color = Colors.black.withOpacity(0.30 * (1 - flightT * 0.42)),
    );

    final radius = max(5.5, size.width * (0.038 - flightT * 0.022)).toDouble();
    _drawBall(canvas, ball, radius, flightT * pi * 9 * shotPower);

    if (impactT > 0) {
      canvas.drawCircle(
        end,
        radius + impactT * 25,
        Paint()
          ..color = (isGoal ? Colors.white : const Color(0xFFFFD65C))
              .withOpacity((1 - impactT) * 0.42)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  void _drawAimGuide(Canvas canvas, Offset start, Offset target) {
    final distance = (target - start).distance;
    if (distance <= 0) return;
    final direction = (target - start) / distance;
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.58)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (double position = 20; position < distance - 25; position += 18) {
      canvas.drawLine(
        start + direction * position,
        start + direction * (position + 8),
        paint,
      );
    }
  }

  void _drawTarget(Canvas canvas, Offset target, Size size) {
    final pulse = 1 + sin(ambientProgress * pi * 2) * 0.07;
    final radius = max(20.0, size.width * 0.064).toDouble() * pulse;
    canvas.drawCircle(target, radius + 8, Paint()..color = const Color(0xFFE7273F).withOpacity(0.16));
    canvas.drawCircle(target, radius, Paint()..color = const Color(0xFFE7273F).withOpacity(0.54));
    canvas.drawCircle(
      target,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    final cross = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(target - Offset(radius * 0.45, 0), target + Offset(radius * 0.45, 0), cross);
    canvas.drawLine(target - Offset(0, radius * 0.45), target + Offset(0, radius * 0.45), cross);
  }

  void _drawBall(Canvas canvas, Offset center, double radius, double rotation) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.drawCircle(
      const Offset(3, 5),
      radius * 0.95,
      Paint()
        ..color = Colors.black.withOpacity(0.34)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.35),
    );
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          colors: <Color>[Colors.white, Color(0xFFE4E9ED), Color(0xFFAAB5BF)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius)),
    );

    final panelPaint = Paint()..color = const Color(0xFF17212B);
    final panel = Path();
    for (var index = 0; index < 5; index++) {
      final angle = -pi / 2 + index * pi * 2 / 5;
      final point = Offset(cos(angle), sin(angle)) * radius * 0.34;
      if (index == 0) {
        panel.moveTo(point.dx, point.dy);
      } else {
        panel.lineTo(point.dx, point.dy);
      }
    }
    panel.close();
    canvas.drawPath(panel, panelPaint);
    for (var index = 0; index < 5; index++) {
      final angle = index * pi * 2 / 5 + 0.2;
      canvas.drawCircle(
        Offset(cos(angle), sin(angle)) * radius * 0.68,
        radius * 0.15,
        panelPaint,
      );
    }
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = Colors.white.withOpacity(0.48)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, radius * 0.08).toDouble(),
    );
    canvas.restore();
  }

  void _drawStatus(Canvas canvas, Size size, double flightT, double diveT) {
    final label = shotProgress == 0
        ? (enabled ? 'اسحب داخل المرمى للتسديد' : 'بانتظار الدور')
        : flightT == 0
            ? 'اقتراب وتسديد'
            : diveT < 0.7
                ? 'الكرة في طريقها'
                : (isGoal ? 'هـــدف' : 'تصـــدٍ');
    final accent = shotProgress == 0
        ? const Color(0xFF72E4AE)
        : (isGoal ? const Color(0xFF5AF1A0) : const Color(0xFFFFD45D));

    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: max(12.0, size.width * 0.034).toDouble(),
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: size.width * 0.74);
    final box = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.94),
      width: text.width + 38,
      height: text.height + 20,
    );
    final rounded = RRect.fromRectAndRadius(box, Radius.circular(box.height / 2));
    canvas.drawRRect(rounded, Paint()..color = const Color(0xE607111A));
    canvas.drawRRect(
      rounded,
      Paint()
        ..color = accent.withOpacity(0.80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    text.paint(
      canvas,
      Offset(box.center.dx - text.width / 2, box.center.dy - text.height / 2),
    );
  }

  Rect fullRect(Size size) => Offset.zero & size;

  Offset _quadratic(Offset a, Offset b, Offset c, double t) {
    final inverse = 1 - t;
    return Offset(
      inverse * inverse * a.dx + 2 * inverse * t * b.dx + t * t * c.dx,
      inverse * inverse * a.dy + 2 * inverse * t * b.dy + t * t * c.dy,
    );
  }

  @override
  bool shouldRepaint(covariant _ProfessionalArenaPainter oldDelegate) {
    return oldDelegate.shotProgress != shotProgress ||
        oldDelegate.ambientProgress != ambientProgress ||
        oldDelegate.targetX != targetX ||
        oldDelegate.targetY != targetY ||
        oldDelegate.keeperX != keeperX ||
        oldDelegate.keeperY != keeperY ||
        oldDelegate.shotPower != shotPower ||
        oldDelegate.isGoal != isGoal ||
        oldDelegate.enabled != enabled ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary;
  }
}

double _phase(double value, double start, double end, Curve curve) {
  return curve.transform(((value - start) / (end - start)).clamp(0.0, 1.0));
}

double _lerp(double start, double end, double t) => start + (end - start) * t;
