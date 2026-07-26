import 'dart:math';

import 'package:flutter/material.dart';

import 'penalty_shootout_game.dart' show FootballTeam;

class ProfessionalPenaltyScene extends StatelessWidget {
  const ProfessionalPenaltyScene({
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
        final goalRect = _sceneGoalRect(size);
        final impactWindow = ((shotProgress - 0.29) / 0.18)
            .clamp(0.0, 1.0)
            .toDouble();
        final shake = sin(impactWindow * pi * 6) * (1 - impactWindow) * 3.2;

        return Transform.translate(
          offset: Offset(shake, -shake * 0.25),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
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
              child: CustomPaint(
                painter: _PenaltyArenaPainter(
                  shotProgress: shotProgress,
                  ambientProgress: ambientProgress,
                  shootingTeam: shootingTeam,
                  targetX: targetX,
                  targetY: targetY,
                  keeperX: keeperX,
                  keeperY: keeperY,
                  shotPower: shotPower,
                  goal: goal,
                  showTarget: enabled,
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

Rect _sceneGoalRect(Size size) {
  return Rect.fromLTWH(
    size.width * 0.105,
    size.height * 0.105,
    size.width * 0.79,
    size.height * 0.31,
  );
}

class _PenaltyArenaPainter extends CustomPainter {
  const _PenaltyArenaPainter({
    required this.shotProgress,
    required this.ambientProgress,
    required this.shootingTeam,
    required this.targetX,
    required this.targetY,
    required this.keeperX,
    required this.keeperY,
    required this.shotPower,
    required this.goal,
    required this.showTarget,
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
  final bool showTarget;

  @override
  void paint(Canvas canvas, Size size) {
    final goalRect = _sceneGoalRect(size);
    _drawSkyAndLights(canvas, size);
    _drawStands(canvas, size);
    _drawPitch(canvas, size);
    _drawAdvertising(canvas, size);
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

    _drawKeeper(canvas, size, goalRect);
    _drawShooter(canvas, size);
    _drawBallAndShadow(canvas, size, goalRect);

    if (shotProgress > 0.72 && goal) {
      _drawNetImpact(canvas, goalRect);
    }
  }

  void _drawSkyAndLights(Canvas canvas, Size size) {
    final skyRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.42);
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF020611),
          Color(0xFF071A2D),
          Color(0xFF14364A),
        ],
      ).createShader(skyRect);
    canvas.drawRect(skyRect, sky);

    final glow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white.withOpacity(0.20),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.5, size.height * 0.05),
          radius: size.width * 0.65,
        ),
      );
    canvas.drawRect(skyRect, glow);

    _drawFloodlight(
      canvas,
      Offset(size.width * 0.08, size.height * 0.05),
      true,
    );
    _drawFloodlight(
      canvas,
      Offset(size.width * 0.92, size.height * 0.05),
      false,
    );

    final beam = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.white.withOpacity(0.16),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.6));

    final leftBeam = Path()
      ..moveTo(size.width * 0.02, size.height * 0.08)
      ..lineTo(size.width * 0.48, size.height * 0.58)
      ..lineTo(size.width * 0.12, size.height * 0.58)
      ..close();
    final rightBeam = Path()
      ..moveTo(size.width * 0.98, size.height * 0.08)
      ..lineTo(size.width * 0.88, size.height * 0.58)
      ..lineTo(size.width * 0.52, size.height * 0.58)
      ..close();
    canvas.drawPath(leftBeam, beam);
    canvas.drawPath(rightBeam, beam);
  }

  void _drawFloodlight(Canvas canvas, Offset center, bool left) {
    final mast = Paint()
      ..color = const Color(0xFF5E6B78)
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(center.dx, center.dy + 18),
      Offset(center.dx + (left ? 8 : -8), center.dy + 92),
      mast,
    );

    final panel = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 54, height: 20),
      const Radius.circular(4),
    );
    canvas.drawRRect(panel, Paint()..color = const Color(0xFF263544));
    final bulb = Paint()..color = const Color(0xFFFFF5C4);
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 6; col++) {
        canvas.drawCircle(
          Offset(center.dx - 21 + col * 8.4, center.dy - 4 + row * 8),
          2.4,
          bulb,
        );
      }
    }
  }

  void _drawStands(Canvas canvas, Size size) {
    final stand = Path()
      ..moveTo(0, size.height * 0.13)
      ..lineTo(size.width, size.height * 0.13)
      ..lineTo(size.width, size.height * 0.39)
      ..lineTo(0, size.height * 0.39)
      ..close();
    canvas.drawPath(stand, Paint()..color = const Color(0xFF0C1723));

    for (var band = 0; band < 4; band++) {
      final y = size.height * (0.16 + band * 0.055);
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, size.height * 0.045),
        Paint()
          ..color = band.isEven
              ? const Color(0xFF142435)
              : const Color(0xFF101D2A),
      );
    }

    final random = Random(31);
    final crowdColors = <Color>[
      const Color(0xFFE7EFF6),
      const Color(0xFFFFCF5C),
      const Color(0xFFEE5365),
      const Color(0xFF4DB8FF),
      const Color(0xFF61D68A),
    ];
    final pulse = 0.65 + sin(ambientProgress * pi * 2) * 0.12;
    for (var i = 0; i < 420; i++) {
      final x = random.nextDouble() * size.width;
      final y = size.height * 0.155 + random.nextDouble() * size.height * 0.205;
      final radius = 0.65 + random.nextDouble() * 1.05;
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = crowdColors[i % crowdColors.length].withOpacity(pulse),
      );
    }
  }

  void _drawPitch(Canvas canvas, Size size) {
    final pitch = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.84, size.height * 0.37)
      ..lineTo(size.width * 0.16, size.height * 0.37)
      ..close();

    final pitchPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF118148),
          Color(0xFF08703B),
          Color(0xFF04562D),
        ],
      ).createShader(
        Rect.fromLTWH(0, size.height * 0.35, size.width, size.height * 0.65),
      );
    canvas.drawPath(pitch, pitchPaint);

    for (var stripe = 0; stripe < 8; stripe++) {
      final t0 = stripe / 8;
      final t1 = (stripe + 1) / 8;
      final y0 = _lerp(size.height * 0.37, size.height, t0);
      final y1 = _lerp(size.height * 0.37, size.height, t1);
      final left0 = _lerp(size.width * 0.16, 0, t0);
      final left1 = _lerp(size.width * 0.16, 0, t1);
      final right0 = _lerp(size.width * 0.84, size.width, t0);
      final right1 = _lerp(size.width * 0.84, size.width, t1);
      final stripePath = Path()
        ..moveTo(left0, y0)
        ..lineTo(right0, y0)
        ..lineTo(right1, y1)
        ..lineTo(left1, y1)
        ..close();
      canvas.drawPath(
        stripePath,
        Paint()
          ..color = stripe.isEven
              ? Colors.white.withOpacity(0.025)
              : Colors.black.withOpacity(0.055),
      );
    }

    final line = Paint()
      ..color = Colors.white.withOpacity(0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final box = Path()
      ..moveTo(size.width * 0.18, size.height * 0.42)
      ..lineTo(size.width * 0.82, size.height * 0.42)
      ..lineTo(size.width * 0.94, size.height * 0.73)
      ..lineTo(size.width * 0.06, size.height * 0.73)
      ..close();
    canvas.drawPath(box, line);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.79),
        width: size.width * 0.34,
        height: size.height * 0.15,
      ),
      line,
    );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.74),
      4,
      Paint()..color = Colors.white,
    );
  }

  void _drawAdvertising(Canvas canvas, Size size) {
    final top = size.height * 0.355;
    canvas.drawRect(
      Rect.fromLTWH(0, top, size.width, size.height * 0.035),
      Paint()..color = const Color(0xFF07131F),
    );
    final painter = TextPainter(
      text: const TextSpan(
        text: 'GAMESLOCAL  •  PENALTY ARENA  •  PLAY LOCAL',
        style: TextStyle(
          color: Color(0xFFFFCF5C),
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 1.1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: size.width - 20);
    painter.paint(canvas, Offset(10, top + 3));
  }

  void _drawGoal(Canvas canvas, Rect goalRect) {
    final back = goalRect.shift(Offset(0, goalRect.height * 0.10));
    canvas.drawRRect(
      RRect.fromRectAndRadius(back.inflate(3), const Radius.circular(4)),
      Paint()
        ..color = Colors.black.withOpacity(0.34)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    final net = Paint()
      ..color = Colors.white.withOpacity(0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var i = 0; i <= 12; i++) {
      final t = i / 12;
      final xTop = _lerp(goalRect.left, goalRect.right, t);
      final xBottom = _lerp(
        goalRect.left + goalRect.width * 0.035,
        goalRect.right - goalRect.width * 0.035,
        t,
      );
      canvas.drawLine(
        Offset(xTop, goalRect.top),
        Offset(xBottom, goalRect.bottom),
        net,
      );
    }
    for (var i = 0; i <= 8; i++) {
      final t = i / 8;
      final y = _lerp(goalRect.top, goalRect.bottom, t);
      final inset = goalRect.width * 0.035 * t;
      canvas.drawLine(
        Offset(goalRect.left + inset, y),
        Offset(goalRect.right - inset, y),
        net,
      );
    }

    final postShadow = Paint()
      ..color = Colors.black45
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawRect(goalRect.shift(const Offset(2, 4)), postShadow);

    final posts = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Colors.white, Color(0xFFB9C4CF), Colors.white],
      ).createShader(goalRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.5
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRect(goalRect, posts);
  }

  void _drawTarget(Canvas canvas, Offset center) {
    final pulse = 1 + sin(ambientProgress * pi * 2) * 0.08;
    final radius = 17.0 * pulse;
    final target = Paint()
      ..color = const Color(0xFFFFCF5C).withOpacity(0.90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawCircle(center, radius, target);
    canvas.drawCircle(center, radius * 0.52, target);
    canvas.drawLine(
      Offset(center.dx - radius - 7, center.dy),
      Offset(center.dx + radius + 7, center.dy),
      target,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius - 7),
      Offset(center.dx, center.dy + radius + 7),
      target,
    );
  }

  void _drawKeeper(Canvas canvas, Size size, Rect goalRect) {
    final diveT = Curves.easeOutCubic.transform(
      ((shotProgress - 0.22) / 0.52).clamp(0.0, 1.0).toDouble(),
    );
    final start = Offset(
      goalRect.center.dx,
      goalRect.bottom - goalRect.height * 0.13,
    );
    final target = Offset(
      goalRect.left + goalRect.width * keeperX,
      goalRect.top + goalRect.height * keeperY,
    );
    final center = Offset.lerp(start, target, diveT)!;
    final horizontal = (keeperX - 0.5) * 2;
    final rotation = horizontal * diveT * 0.78;
    final scale = goalRect.width / 360;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.scale(scale, scale);
    _drawKeeperBody(canvas, diveT, horizontal);
    canvas.restore();
  }

  void _drawKeeperBody(Canvas canvas, double dive, double horizontal) {
    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.32)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 47), width: 86, height: 18),
      shadow,
    );

    final skin = Paint()..color = const Color(0xFFC88458);
    final dark = Paint()..color = const Color(0xFF111820);
    final jersey = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0xFFFFB000), Color(0xFFF06A00)],
      ).createShader(const Rect.fromLTWH(-34, -34, 68, 76));
    final shorts = Paint()..color = const Color(0xFF17212C);
    final gloves = Paint()..color = const Color(0xFFEFF7FF);

    final torso = Path()
      ..moveTo(-25, -28)
      ..quadraticBezierTo(-35, -5, -30, 28)
      ..lineTo(30, 28)
      ..quadraticBezierTo(35, -5, 25, -28)
      ..close();
    canvas.drawPath(torso, jersey);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-30, 22, 60, 27),
        const Radius.circular(8),
      ),
      shorts,
    );

    final arm = Paint()
      ..color = const Color(0xFFFF8A00)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 14;
    final extension = 42 + dive * 22;
    canvas.drawLine(
      const Offset(-23, -18),
      Offset(-extension, -22 - dive * 15),
      arm,
    );
    canvas.drawLine(
      const Offset(23, -18),
      Offset(extension, -22 - dive * 15),
      arm,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-extension - 3, -23 - dive * 15),
        width: 19,
        height: 15,
      ),
      gloves,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(extension + 3, -23 - dive * 15),
        width: 19,
        height: 15,
      ),
      gloves,
    );

    final leg = Paint()
      ..color = const Color(0xFFCF8A5A)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 13;
    canvas.drawLine(const Offset(-17, 42), Offset(-26, 70 + dive * 5), leg);
    canvas.drawLine(const Offset(17, 42), Offset(29, 68 - dive * 3), leg);
    final boot = Paint()
      ..color = dark.color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 9;
    canvas.drawLine(const Offset(-31, 72), const Offset(-15, 72), boot);
    canvas.drawLine(const Offset(23, 70), const Offset(40, 69), boot);

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -48), width: 33, height: 39),
      skin,
    );
    final hair = Path()
      ..moveTo(-16, -54)
      ..quadraticBezierTo(-7, -72, 12, -64)
      ..quadraticBezierTo(19, -59, 15, -47)
      ..lineTo(-15, -47)
      ..close();
    canvas.drawPath(hair, dark);
    canvas.drawCircle(const Offset(-6, -49), 1.8, dark);
    canvas.drawCircle(const Offset(6, -49), 1.8, dark);
    canvas.drawLine(
      const Offset(-5, -39),
      const Offset(5, -39),
      Paint()
        ..color = const Color(0xFF111820)
        ..strokeWidth = 1.6,
    );

    final badge = Paint()..color = Colors.white.withOpacity(0.92);
    canvas.drawCircle(const Offset(0, -5), 9, badge);
    final number = TextPainter(
      text: const TextSpan(
        text: '1',
        style: TextStyle(
          color: Color(0xFF15202B),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    number.paint(canvas, Offset(-number.width / 2, -5 - number.height / 2));
  }

  void _drawShooter(Canvas canvas, Size size) {
    final runT = Curves.easeInOutCubic.transform(
      (shotProgress / 0.34).clamp(0.0, 1.0).toDouble(),
    );
    final kickT = Curves.easeOutBack.transform(
      ((shotProgress - 0.22) / 0.30).clamp(0.0, 1.0).toDouble(),
    );
    final start = Offset(size.width * 0.18, size.height * 0.86);
    final end = Offset(size.width * 0.47, size.height * 0.80);
    final center = Offset.lerp(start, end, runT)!;
    final scale = size.width / 360;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale, scale);
    _drawFootballerBody(canvas, runT, kickT);
    canvas.restore();
  }

  void _drawFootballerBody(Canvas canvas, double runT, double kickT) {
    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.36)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 72), width: 92, height: 19),
      shadow,
    );

    final skin = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0xFFF0B37D), Color(0xFFB86F43)],
      ).createShader(const Rect.fromLTWH(-25, -75, 50, 70));
    final jersey = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          shootingTeam.primary,
          Color.lerp(shootingTeam.primary, Colors.black, 0.22)!,
        ],
      ).createShader(const Rect.fromLTWH(-34, -30, 68, 76));
    final shorts = Paint()..color = shootingTeam.secondary.withOpacity(0.96);
    final socks = Paint()..color = shootingTeam.primary;
    final boots = Paint()..color = const Color(0xFF11161C);
    final hair = Paint()..color = const Color(0xFF17100D);

    final bodyLean = kickT * 0.10;
    canvas.save();
    canvas.rotate(bodyLean);

    final torso = Path()
      ..moveTo(-28, -28)
      ..quadraticBezierTo(-36, -2, -29, 31)
      ..lineTo(29, 31)
      ..quadraticBezierTo(36, -2, 28, -28)
      ..close();
    canvas.drawPath(torso, jersey);

    final shoulderSwing = sin(runT * pi * 3) * 10;
    final arm = Paint()
      ..color = shootingTeam.primary
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 13;
    canvas.drawLine(
      const Offset(-25, -16),
      Offset(-45, 6 + shoulderSwing - kickT * 12),
      arm,
    );
    canvas.drawLine(
      const Offset(25, -16),
      Offset(46, 5 - shoulderSwing + kickT * 9),
      arm,
    );
    canvas.drawCircle(
      Offset(-47, 9 + shoulderSwing - kickT * 12),
      7,
      skin,
    );
    canvas.drawCircle(
      Offset(48, 8 - shoulderSwing + kickT * 9),
      7,
      skin,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-30, 26, 60, 28),
        const Radius.circular(8),
      ),
      shorts,
    );

    final plantKnee = Offset(-15 - runT * 2, 83);
    final kickingKnee = Offset(18 + kickT * 24, 73 - kickT * 18);
    final thigh = Paint()
      ..color = const Color(0xFFCB8456)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 15;
    canvas.drawLine(const Offset(-15, 49), plantKnee, thigh);
    canvas.drawLine(const Offset(15, 49), kickingKnee, thigh);

    final shin = Paint()
      ..color = socks.color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 13;
    canvas.drawLine(plantKnee, const Offset(-12, 121), shin);
    final kickFoot = Offset(58 + kickT * 30, 92 - kickT * 22);
    canvas.drawLine(kickingKnee, kickFoot, shin);

    final bootPaint = Paint()
      ..color = boots.color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10;
    canvas.drawLine(const Offset(-18, 122), const Offset(3, 122), bootPaint);
    canvas.drawLine(
      kickFoot.translate(-5, 0),
      kickFoot.translate(18, -1),
      bootPaint,
    );

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -48), width: 37, height: 43),
      skin,
    );
    final hairPath = Path()
      ..moveTo(-18, -53)
      ..quadraticBezierTo(-11, -72, 5, -70)
      ..quadraticBezierTo(19, -68, 18, -49)
      ..quadraticBezierTo(7, -57, -18, -53)
      ..close();
    canvas.drawPath(hairPath, hair);
    canvas.drawCircle(const Offset(-6, -49), 1.8, hair);
    canvas.drawCircle(const Offset(6, -49), 1.8, hair);
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(0, -39), width: 12, height: 6),
      0,
      pi,
      false,
      Paint()
        ..color = const Color(0xFF7A3526)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    final numberBackground = Paint()..color = Colors.white.withOpacity(0.88);
    canvas.drawCircle(const Offset(0, -2), 10, numberBackground);
    final number = TextPainter(
      text: TextSpan(
        text: '9',
        style: TextStyle(
          color: shootingTeam.primary.computeLuminance() > 0.52
              ? const Color(0xFF111820)
              : shootingTeam.primary,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    number.paint(canvas, Offset(-number.width / 2, -2 - number.height / 2));

    canvas.restore();
  }

  void _drawBallAndShadow(Canvas canvas, Size size, Rect goalRect) {
    final ballT = Curves.easeOutCubic.transform(
      ((shotProgress - 0.25) / 0.50).clamp(0.0, 1.0).toDouble(),
    );
    final start = Offset(size.width * 0.52, size.height * 0.78);
    final end = Offset(
      goalRect.left + goalRect.width * targetX,
      goalRect.top + goalRect.height * targetY,
    );
    final curveHeight = size.height * (0.18 + shotPower * 0.08);
    final control = Offset(
      _lerp(start.dx, end.dx, 0.52),
      min(start.dy, end.dy).toDouble() - curveHeight,
    );
    final ball = _quadraticBezier(start, control, end, ballT);

    final groundY = _lerp(start.dy + 13, goalRect.bottom + 8, ballT);
    final shadowWidth = _lerp(34, 13, ballT);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(ball.dx, groundY),
        width: shadowWidth,
        height: shadowWidth * 0.28,
      ),
      Paint()
        ..color = Colors.black.withOpacity(_lerp(0.34, 0.12, ballT))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    final radius = _lerp(17.5, 9.0, ballT);
    _drawBall(canvas, ball, radius, ballT * pi * 9);
  }

  void _drawBall(Canvas canvas, Offset center, double radius, double rotation) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    final outer = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.35, -0.38),
        colors: <Color>[
          Colors.white,
          Color(0xFFD5DCE2),
          Color(0xFF8B98A5),
        ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));
    canvas.drawCircle(Offset.zero, radius, outer);

    final panel = Paint()
      ..color = const Color(0xFF111820)
      ..style = PaintingStyle.fill;
    final pentagon = Path();
    for (var i = 0; i < 5; i++) {
      final angle = -pi / 2 + i * 2 * pi / 5;
      final point = Offset(cos(angle), sin(angle)) * radius * 0.32;
      if (i == 0) {
        pentagon.moveTo(point.dx, point.dy);
      } else {
        pentagon.lineTo(point.dx, point.dy);
      }
    }
    pentagon.close();
    canvas.drawPath(pentagon, panel);

    final seam = Paint()
      ..color = const Color(0xFF3C4751)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.7, radius * 0.07).toDouble();
    for (var i = 0; i < 5; i++) {
      final angle = -pi / 2 + i * 2 * pi / 5;
      final inner = Offset(cos(angle), sin(angle)) * radius * 0.34;
      final outerPoint = Offset(cos(angle), sin(angle)) * radius * 0.86;
      canvas.drawLine(inner, outerPoint, seam);
    }

    canvas.drawCircle(
      Offset(-radius * 0.32, -radius * 0.37),
      radius * 0.14,
      Paint()..color = Colors.white.withOpacity(0.75),
    );
    canvas.restore();
  }

  void _drawNetImpact(Canvas canvas, Rect goalRect) {
    final impactT = Curves.easeOut.transform(
      ((shotProgress - 0.72) / 0.28).clamp(0.0, 1.0).toDouble(),
    );
    final center = Offset(
      goalRect.left + goalRect.width * targetX,
      goalRect.top + goalRect.height * targetY,
    );
    final ripple = Paint()
      ..color = Colors.white.withOpacity((1 - impactT) * 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (var i = 1; i <= 3; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: (20 + i * 20) * impactT,
          height: (14 + i * 14) * impactT,
        ),
        ripple,
      );
    }
  }

  Offset _quadraticBezier(Offset a, Offset b, Offset c, double t) {
    final mt = 1 - t;
    return Offset(
      mt * mt * a.dx + 2 * mt * t * b.dx + t * t * c.dx,
      mt * mt * a.dy + 2 * mt * t * b.dy + t * t * c.dy,
    );
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(covariant _PenaltyArenaPainter oldDelegate) {
    return oldDelegate.shotProgress != shotProgress ||
        oldDelegate.ambientProgress != ambientProgress ||
        oldDelegate.shootingTeam != shootingTeam ||
        oldDelegate.targetX != targetX ||
        oldDelegate.targetY != targetY ||
        oldDelegate.keeperX != keeperX ||
        oldDelegate.keeperY != keeperY ||
        oldDelegate.shotPower != shotPower ||
        oldDelegate.goal != goal ||
        oldDelegate.showTarget != showTarget;
  }
}
