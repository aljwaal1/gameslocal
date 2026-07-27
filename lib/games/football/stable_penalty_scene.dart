import 'dart:math';

import 'package:flutter/material.dart';

import 'penalty_shootout_game.dart' show FootballTeam;

/// A self-contained penalty scene rendered entirely by Flutter.
///
/// No bitmap is required, so the striker, goalkeeper, goal and ball remain
/// visible on old and new Android devices alike.
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

  @override
  void didUpdateWidget(covariant StablePenaltyScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || widget.shotProgress > 0) {
      _dragAim = null;
    }
  }

  Rect _goalRect(Size size) {
    return Rect.fromLTWH(
      size.width * 0.12,
      size.height * 0.155,
      size.width * 0.76,
      size.height * 0.275,
    );
  }

  Offset? _normalizedAim(Offset localPosition, Size size) {
    final goal = _goalRect(size);
    if (!goal.inflate(18).contains(localPosition)) return null;
    return Offset(
      ((localPosition.dx - goal.left) / goal.width).clamp(0.03, 0.97),
      ((localPosition.dy - goal.top) / goal.height).clamp(0.05, 0.95),
    );
  }

  void _updateAim(Offset localPosition, Size size) {
    if (!widget.enabled) return;
    final aim = _normalizedAim(localPosition, size);
    if (aim == null) return;
    setState(() => _dragAim = aim);
  }

  void _commitAim() {
    final aim = _dragAim;
    if (!widget.enabled || aim == null) return;
    widget.onShoot(aim.dx, aim.dy);
    setState(() => _dragAim = null);
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
                    final value = _normalizedAim(details.localPosition, size);
                    if (value != null) widget.onShoot(value.dx, value.dy);
                  }
                : null,
            onPanStart: widget.enabled
                ? (details) => _updateAim(details.localPosition, size)
                : null,
            onPanUpdate: widget.enabled
                ? (details) => _updateAim(details.localPosition, size)
                : null,
            onPanEnd: widget.enabled ? (_) => _commitAim() : null,
            child: RepaintBoundary(
              child: CustomPaint(
                key: const ValueKey<String>('always-visible-football-actors'),
                painter: _ArenaPainter(
                  shotProgress: widget.shotProgress,
                  ambientProgress: widget.ambientProgress,
                  targetX: aim.dx,
                  targetY: aim.dy,
                  keeperX: widget.keeperX,
                  keeperY: widget.keeperY,
                  shotPower: widget.shotPower,
                  goal: widget.goal,
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

class _ArenaPainter extends CustomPainter {
  const _ArenaPainter({
    required this.shotProgress,
    required this.ambientProgress,
    required this.targetX,
    required this.targetY,
    required this.keeperX,
    required this.keeperY,
    required this.shotPower,
    required this.goal,
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
  final bool goal;
  final bool enabled;
  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final runT = _phase(shotProgress, 0.04, 0.48, Curves.easeInOutCubic);
    final kickT = _phase(shotProgress, 0.40, 0.64, Curves.easeInOutCubic);
    final flightT = _phase(shotProgress, 0.55, 0.90, Curves.easeInCubic);
    final keeperT = _phase(shotProgress, 0.63, 0.91, Curves.easeOutCubic);
    final impactT = _phase(shotProgress, 0.87, 1.0, Curves.easeOutCubic);

    _drawBackground(canvas, size);
    final pitch = _drawPitch(canvas, size);
    final goalRect = Rect.fromLTWH(
      size.width * 0.12,
      size.height * 0.155,
      size.width * 0.76,
      size.height * 0.275,
    );

    _drawGoalBack(canvas, goalRect, impactT);
    _drawKeeper(canvas, size, goalRect, keeperT);
    _drawGoalFront(canvas, goalRect, impactT);
    _drawPitchDetails(canvas, size, pitch);
    _drawStriker(canvas, size, runT, kickT);
    _drawShot(canvas, size, goalRect, flightT, impactT);
    _drawHud(canvas, size, runT, flightT, keeperT);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF030712),
          Color(0xFF091A2C),
          Color(0xFF123047),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final standRect = Rect.fromLTWH(0, size.height * 0.07, size.width, size.height * 0.34);
    canvas.drawRect(
      standRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF11182A), Color(0xFF22344B), Color(0xFF07111C)],
        ).createShader(standRect),
    );

    final crowd = Paint()..style = PaintingStyle.fill;
    final columns = max(16, (size.width / 13).floor());
    final rows = 12;
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final seed = sin(column * 12.73 + row * 7.91) * 0.5 + 0.5;
        crowd.color = <Color>[
          const Color(0xFFDFE7F1),
          const Color(0xFF42B9FF),
          const Color(0xFFFFC857),
          const Color(0xFFE95D6A),
          const Color(0xFF70E0A5),
        ][(seed * 4.99).floor()];
        crowd.color = crowd.color.withOpacity(0.28 + seed * 0.42);
        final x = (column + 0.5 + sin(row + column) * 0.16) * size.width / columns;
        final y = standRect.top + 20 + row * (standRect.height - 35) / rows;
        canvas.drawCircle(Offset(x, y), 1.2 + seed * 1.6, crowd);
      }
    }

    final beam = Paint()
      ..shader = RadialGradient(
        colors: <Color>[Colors.white.withOpacity(0.50), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.5, 0), radius: size.width));
    canvas.drawRect(Offset.zero & Size(size.width, size.height * 0.42), beam);

    for (final x in <double>[0.08, 0.92]) {
      final center = Offset(size.width * x, size.height * 0.075);
      canvas.drawCircle(center, 22, Paint()..color = Colors.white.withOpacity(0.08));
      canvas.drawCircle(center, 9, Paint()..color = Colors.white.withOpacity(0.92));
      canvas.drawCircle(center, 17, Paint()..color = const Color(0xFF87D7FF).withOpacity(0.26));
    }
  }

  Path _drawPitch(Canvas canvas, Size size) {
    final pitch = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.84, size.height * 0.39)
      ..lineTo(size.width * 0.16, size.height * 0.39)
      ..close();
    canvas.drawPath(
      pitch,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF0B6A3A), Color(0xFF159650), Color(0xFF07502D)],
          stops: <double>[0, 0.62, 1],
        ).createShader(Offset.zero & size),
    );

    final stripe = Paint()..color = Colors.white.withOpacity(0.035);
    for (var i = 0; i < 8; i += 2) {
      final top = size.height * (0.40 + i * 0.072);
      final bottom = size.height * (0.40 + (i + 1) * 0.072);
      canvas.drawRect(Rect.fromLTRB(0, top, size.width, bottom), stripe);
    }
    return pitch;
  }

  void _drawPitchDetails(Canvas canvas, Size size, Path pitch) {
    canvas.save();
    canvas.clipPath(pitch);
    final line = Paint()
      ..color = Colors.white.withOpacity(0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.4, size.width * 0.004);

    final box = Path()
      ..moveTo(size.width * 0.24, size.height * 0.40)
      ..lineTo(size.width * 0.10, size.height * 0.69)
      ..lineTo(size.width * 0.90, size.height * 0.69)
      ..lineTo(size.width * 0.76, size.height * 0.40);
    canvas.drawPath(box, line);
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
      max(2.5, size.width * 0.008),
      Paint()..color = Colors.white.withOpacity(0.85),
    );
    canvas.restore();
  }

  void _drawGoalBack(Canvas canvas, Rect goal, double impactT) {
    final ripple = goal && impactT > 0 ? sin(impactT * pi * 4) * (1 - impactT) * 8 : 0.0;
    final netRect = Rect.fromLTRB(goal.left, goal.top, goal.right, goal.bottom + ripple);

    canvas.drawRRect(
      RRect.fromRectAndRadius(netRect.inflate(4), const Radius.circular(8)),
      Paint()
        ..color = Colors.black.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawRect(netRect, Paint()..color = const Color(0xFFDAF3FF).withOpacity(0.08));

    final net = Paint()
      ..color = Colors.white.withOpacity(0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    for (var i = 0; i <= 12; i++) {
      final x = netRect.left + netRect.width * i / 12;
      canvas.drawLine(Offset(x, netRect.top), Offset(x + ripple * 0.20, netRect.bottom), net);
    }
    for (var i = 0; i <= 6; i++) {
      final y = netRect.top + netRect.height * i / 6;
      canvas.drawLine(Offset(netRect.left, y), Offset(netRect.right, y + ripple * 0.10), net);
    }
  }

  void _drawGoalFront(Canvas canvas, Rect goal, double impactT) {
    final postWidth = max(5.0, goal.width * 0.018);
    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.42)
      ..strokeWidth = postWidth + 5
      ..strokeCap = StrokeCap.round;
    final post = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Colors.white, Color(0xFFB9CFDA), Colors.white],
      ).createShader(goal)
      ..strokeWidth = postWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(goal.topLeft + const Offset(3, 5), goal.topRight + const Offset(3, 5), shadow);
    canvas.drawLine(goal.topLeft + const Offset(3, 5), goal.bottomLeft + const Offset(3, 5), shadow);
    canvas.drawLine(goal.topRight + const Offset(3, 5), goal.bottomRight + const Offset(3, 5), shadow);
    canvas.drawLine(goal.topLeft, goal.topRight, post);
    canvas.drawLine(goal.topLeft, goal.bottomLeft, post);
    canvas.drawLine(goal.topRight, goal.bottomRight, post);

    if (goal && impactT > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(goal, const Radius.circular(8)),
        Paint()
          ..color = Colors.white.withOpacity((1 - impactT) * 0.16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 + impactT * 5,
      );
    }
  }

  void _drawKeeper(Canvas canvas, Size size, Rect goalRect, double diveT) {
    final readyBounce = sin(ambientProgress * pi * 2) * size.height * 0.0035;
    final start = Offset(goalRect.center.dx, goalRect.top + goalRect.height * 0.63 + readyBounce);
    final requested = Offset(
      goalRect.left + goalRect.width * keeperX,
      goalRect.top + goalRect.height * keeperY,
    );
    final end = Offset(
      requested.dx.clamp(goalRect.left + goalRect.width * 0.08, goalRect.right - goalRect.width * 0.08),
      requested.dy.clamp(goalRect.top + goalRect.height * 0.18, goalRect.bottom - goalRect.height * 0.04),
    );
    final center = Offset.lerp(start, end, diveT)!;
    final direction = (end.dx - start.dx).sign;
    final rotation = direction * diveT * 0.72;
    final scale = size.width / 390;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    final shadow = Paint()..color = Colors.black.withOpacity(0.30 * (1 - diveT * 0.5));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, 34 * scale), width: 64 * scale, height: 12 * scale),
      shadow,
    );

    final keeperColor = Color.lerp(const Color(0xFF16C784), const Color(0xFF7CFF6B), 0.42)!;
    final darkKeeper = Color.lerp(keeperColor, Colors.black, 0.28)!;
    final skin = const Color(0xFFC98E68);
    final limb = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final reach = 30 * scale + diveT * 24 * scale;
    final armRise = 6 * scale + diveT * 15 * scale;
    limb
      ..color = keeperColor
      ..strokeWidth = 12 * scale;
    canvas.drawLine(Offset(-9 * scale, -12 * scale), Offset(-reach, -armRise), limb);
    canvas.drawLine(Offset(9 * scale, -12 * scale), Offset(reach, -armRise), limb);

    final glove = Paint()..color = const Color(0xFFFFE45E);
    canvas.drawCircle(Offset(-reach, -armRise), 8.5 * scale, glove);
    canvas.drawCircle(Offset(reach, -armRise), 8.5 * scale, glove);

    final torso = Path()
      ..moveTo(-17 * scale, -20 * scale)
      ..quadraticBezierTo(-22 * scale, 2 * scale, -15 * scale, 19 * scale)
      ..lineTo(15 * scale, 19 * scale)
      ..quadraticBezierTo(22 * scale, 2 * scale, 17 * scale, -20 * scale)
      ..close();
    canvas.drawPath(
      torso,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[keeperColor, darkKeeper],
        ).createShader(Rect.fromLTWH(-22 * scale, -22 * scale, 44 * scale, 44 * scale)),
    );
    canvas.drawPath(torso, Paint()..color = Colors.white.withOpacity(0.07)..style = PaintingStyle.stroke..strokeWidth = 1.2 * scale);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 19 * scale, height: 12 * scale),
        Radius.circular(4 * scale),
      ),
      Paint()..color = Colors.white.withOpacity(0.12),
    );

    limb
      ..color = const Color(0xFF172434)
      ..strokeWidth = 13 * scale;
    final legSpread = 17 * scale + diveT * 11 * scale;
    canvas.drawLine(Offset(-8 * scale, 16 * scale), Offset(-legSpread, 42 * scale), limb);
    canvas.drawLine(Offset(8 * scale, 16 * scale), Offset(legSpread, 42 * scale), limb);
    limb
      ..color = const Color(0xFFB9D4E6)
      ..strokeWidth = 6 * scale;
    canvas.drawLine(Offset(-legSpread, 42 * scale), Offset(-legSpread - 8 * scale, 44 * scale), limb);
    canvas.drawLine(Offset(legSpread, 42 * scale), Offset(legSpread + 8 * scale, 44 * scale), limb);

    canvas.drawCircle(Offset(0, -31 * scale), 11.5 * scale, Paint()..color = skin);
    final hair = Path()
      ..addArc(Rect.fromCircle(center: Offset(0, -33 * scale), radius: 11.5 * scale), pi, pi);
    canvas.drawPath(hair, Paint()..color = const Color(0xFF261B18));
    canvas.drawCircle(Offset(-3.8 * scale, -31 * scale), 1.1 * scale, Paint()..color = Colors.black87);
    canvas.drawCircle(Offset(3.8 * scale, -31 * scale), 1.1 * scale, Paint()..color = Colors.black87);

    canvas.restore();
  }

  void _drawStriker(Canvas canvas, Size size, double runT, double kickT) {
    final scale = size.width / 390;
    final start = Offset(size.width * 0.24, size.height * 0.80);
    final contact = Offset(size.width * 0.43, size.height * 0.755);
    final center = Offset.lerp(start, contact, runT)! + Offset(0, sin(runT * pi * 5) * 4 * scale);
    final lean = -0.08 - runT * 0.07 + kickT * 0.17;
    final skin = const Color(0xFFC58A62);
    final darkKit = Color.lerp(primary, Colors.black, 0.32)!;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(lean);

    canvas.drawOval(
      Rect.fromCenter(center: Offset(6 * scale, 67 * scale), width: 78 * scale, height: 15 * scale),
      Paint()..color = Colors.black.withOpacity(0.28),
    );

    final limb = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final armSwing = sin(runT * pi * 4) * 10 * scale;
    limb
      ..color = skin
      ..strokeWidth = 10 * scale;
    canvas.drawLine(Offset(-16 * scale, -18 * scale), Offset(-31 * scale, 6 * scale + armSwing), limb);
    canvas.drawLine(Offset(16 * scale, -17 * scale), Offset(31 * scale, 4 * scale - armSwing), limb);

    final jersey = Path()
      ..moveTo(-19 * scale, -27 * scale)
      ..lineTo(-27 * scale, -13 * scale)
      ..lineTo(-18 * scale, -7 * scale)
      ..lineTo(-14 * scale, 19 * scale)
      ..lineTo(15 * scale, 19 * scale)
      ..lineTo(18 * scale, -7 * scale)
      ..lineTo(27 * scale, -13 * scale)
      ..lineTo(19 * scale, -27 * scale)
      ..close();
    canvas.drawPath(
      jersey,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[primary, darkKit],
        ).createShader(Rect.fromLTWH(-28 * scale, -28 * scale, 56 * scale, 50 * scale)),
    );
    canvas.drawLine(
      Offset(-10 * scale, -23 * scale),
      Offset(-7 * scale, 15 * scale),
      Paint()..color = secondary.withOpacity(0.85)..strokeWidth = 3.5 * scale,
    );
    canvas.drawLine(
      Offset(10 * scale, -23 * scale),
      Offset(7 * scale, 15 * scale),
      Paint()..color = secondary.withOpacity(0.85)..strokeWidth = 3.5 * scale,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, 25 * scale), width: 35 * scale, height: 19 * scale),
        Radius.circular(5 * scale),
      ),
      Paint()..color = darkKit,
    );

    final plantedHip = Offset(-8 * scale, 31 * scale);
    final plantedKnee = Offset(-18 * scale, 53 * scale);
    final plantedFoot = Offset(-24 * scale, 72 * scale);
    final kickHip = Offset(8 * scale, 31 * scale);
    final kickKnee = Offset(
      (16 - kickT * 4) * scale,
      (52 - kickT * 18) * scale,
    );
    final kickFoot = Offset(
      (22 + kickT * 34) * scale,
      (70 - kickT * 25) * scale,
    );

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
      ..color = const Color(0xFFF2F5F8)
      ..strokeWidth = 8 * scale;
    canvas.drawLine(plantedFoot - Offset(0, 9 * scale), plantedFoot, limb);
    canvas.drawLine(kickFoot - Offset(0, 9 * scale), kickFoot, limb);
    limb
      ..color = const Color(0xFF18202A)
      ..strokeWidth = 7 * scale;
    canvas.drawLine(plantedFoot, plantedFoot + Offset(12 * scale, 1 * scale), limb);
    canvas.drawLine(kickFoot, kickFoot + Offset(14 * scale, -1 * scale), limb);

    canvas.drawCircle(Offset(0, -41 * scale), 13 * scale, Paint()..color = skin);
    final hair = Path()
      ..moveTo(-12 * scale, -44 * scale)
      ..quadraticBezierTo(0, -59 * scale, 12 * scale, -44 * scale)
      ..lineTo(9 * scale, -51 * scale)
      ..lineTo(4 * scale, -47 * scale)
      ..lineTo(0, -54 * scale)
      ..lineTo(-4 * scale, -47 * scale)
      ..lineTo(-10 * scale, -51 * scale)
      ..close();
    canvas.drawPath(hair, Paint()..color = const Color(0xFF211918));

    canvas.restore();
  }

  void _drawShot(Canvas canvas, Size size, Rect goalRect, double flightT, double impactT) {
    final start = Offset(size.width * 0.48, size.height * 0.82);
    final target = Offset(
      goalRect.left + goalRect.width * targetX,
      goalRect.top + goalRect.height * targetY,
    );
    final keeperTarget = Offset(
      goalRect.left + goalRect.width * keeperX,
      goalRect.top + goalRect.height * keeperY,
    );
    final end = goal ? target : Offset.lerp(target, keeperTarget, 0.72)!;
    final curve = Offset(
      (start.dx + end.dx) / 2 + (targetX - 0.5) * size.width * 0.16,
      min(start.dy, end.dy) - size.height * (0.13 + shotPower * 0.065),
    );

    if (shotProgress == 0) {
      _drawBall(canvas, start, max(13, size.width * 0.038), ambientProgress * pi * 2);
      if (enabled) {
        _drawAimGuide(canvas, start, target, size);
        _drawTarget(canvas, target, size);
      }
      return;
    }

    if (flightT <= 0) {
      _drawBall(canvas, start, max(13, size.width * 0.038), 0);
      return;
    }

    final ball = _quadratic(start, curve, end, flightT);
    final previous = _quadratic(start, curve, end, max(0, flightT - 0.10));
    final speed = Paint()
      ..shader = LinearGradient(
        colors: <Color>[Colors.transparent, Colors.white.withOpacity(0.72)],
      ).createShader(Rect.fromPoints(previous, ball))
      ..strokeWidth = max(3, size.width * 0.014 * (1 - flightT * 0.45))
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(previous, ball, speed);

    final groundY = _lerp(size.height * 0.84, goalRect.bottom, flightT);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(ball.dx + 4, groundY + 5),
        width: max(8, size.width * 0.055 * (1 - flightT * 0.62)),
        height: max(3, size.height * 0.012 * (1 - flightT * 0.55)),
      ),
      Paint()..color = Colors.black.withOpacity(0.30 * (1 - flightT * 0.42)),
    );

    final radius = max(5.5, size.width * (0.038 - flightT * 0.022));
    _drawBall(canvas, ball, radius, flightT * pi * 9 * shotPower);

    if (impactT > 0) {
      canvas.drawCircle(
        end,
        radius + impactT * 25,
        Paint()
          ..color = (goal ? Colors.white : const Color(0xFFFFD65C)).withOpacity((1 - impactT) * 0.42)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  void _drawAimGuide(Canvas canvas, Offset start, Offset target, Size size) {
    final guide = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final distance = (target - start).distance;
    final direction = (target - start) / distance;
    for (double d = 20; d < distance - 25; d += 18) {
      canvas.drawLine(start + direction * d, start + direction * (d + 8), guide);
    }
  }

  void _drawTarget(Canvas canvas, Offset target, Size size) {
    final pulse = 1 + sin(ambientProgress * pi * 2) * 0.07;
    final radius = max(20.0, size.width * 0.065) * pulse;
    canvas.drawCircle(target, radius + 8, Paint()..color = const Color(0xFFE7273F).withOpacity(0.16));
    canvas.drawCircle(
      target,
      radius,
      Paint()
        ..color = const Color(0xFFE7273F).withOpacity(0.52)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      target,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawLine(target - Offset(radius * 0.45, 0), target + Offset(radius * 0.45, 0), Paint()..color = Colors.white..strokeWidth = 2.2);
    canvas.drawLine(target - Offset(0, radius * 0.45), target + Offset(0, radius * 0.45), Paint()..color = Colors.white..strokeWidth = 2.2);
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
          colors: <Color>[Colors.white, Color(0xFFE5E9ED), Color(0xFFAEB8C2)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius)),
    );

    final panel = Paint()..color = const Color(0xFF17202A);
    final centerPanel = Path();
    for (var i = 0; i < 5; i++) {
      final angle = -pi / 2 + i * pi * 2 / 5;
      final point = Offset(cos(angle), sin(angle)) * radius * 0.34;
      if (i == 0) {
        centerPanel.moveTo(point.dx, point.dy);
      } else {
        centerPanel.lineTo(point.dx, point.dy);
      }
    }
    centerPanel.close();
    canvas.drawPath(centerPanel, panel);
    for (var i = 0; i < 5; i++) {
      final angle = i * pi * 2 / 5 + 0.2;
      canvas.drawCircle(Offset(cos(angle), sin(angle)) * radius * 0.68, radius * 0.15, panel);
    }
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = Colors.white.withOpacity(0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, radius * 0.08),
    );
    canvas.restore();
  }

  void _drawHud(Canvas canvas, Size size, double runT, double flightT, double keeperT) {
    final label = shotProgress == 0
        ? (enabled ? 'اسحب علامة التصويب ثم ارفع إصبعك' : 'بانتظار الدور')
        : flightT == 0
            ? 'اللاعب يقترب من الكرة'
            : keeperT < 0.7
                ? 'التسديدة في طريقها'
                : (goal ? 'هـــدف' : 'تصـــدٍ');
    final accent = shotProgress == 0
        ? const Color(0xFF77E5B1)
        : (goal ? const Color(0xFF63F2A5) : const Color(0xFFFFD65C));

    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: max(12, size.width * 0.034),
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: size.width * 0.72);
    final box = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.94),
      width: text.width + 38,
      height: text.height + 20,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, Radius.circular(box.height / 2)),
      Paint()..color = const Color(0xE609141E),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, Radius.circular(box.height / 2)),
      Paint()
        ..color = accent.withOpacity(0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    text.paint(canvas, Offset(box.center.dx - text.width / 2, box.center.dy - text.height / 2));

    final phaseWidth = size.width * 0.32;
    final phaseRect = Rect.fromLTWH(size.width * 0.04, size.height * 0.04, phaseWidth, 7);
    canvas.drawRRect(RRect.fromRectAndRadius(phaseRect, const Radius.circular(5)), Paint()..color = Colors.white.withOpacity(0.14));
    final progress = shotProgress == 0 ? 0.04 + ambientProgress * 0.05 : shotProgress;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(phaseRect.left, phaseRect.top, phaseRect.width * progress, phaseRect.height), const Radius.circular(5)),
      Paint()..color = accent,
    );
  }

  Offset _quadratic(Offset a, Offset b, Offset c, double t) {
    final inv = 1 - t;
    return Offset(
      inv * inv * a.dx + 2 * inv * t * b.dx + t * t * c.dx,
      inv * inv * a.dy + 2 * inv * t * b.dy + t * t * c.dy,
    );
  }

  @override
  bool shouldRepaint(covariant _ArenaPainter oldDelegate) {
    return oldDelegate.shotProgress != shotProgress ||
        oldDelegate.ambientProgress != ambientProgress ||
        oldDelegate.targetX != targetX ||
        oldDelegate.targetY != targetY ||
        oldDelegate.keeperX != keeperX ||
        oldDelegate.keeperY != keeperY ||
        oldDelegate.shotPower != shotPower ||
        oldDelegate.goal != goal ||
        oldDelegate.enabled != enabled ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary;
  }
}

double _phase(double value, double start, double end, Curve curve) {
  return curve.transform(((value - start) / (end - start)).clamp(0.0, 1.0));
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
