import 'dart:math' as math;

import 'package:flutter/material.dart';

enum FootballSpritePose {
  playerReady,
  playerRun,
  playerKick,
  keeperReady,
  keeperDive,
}

/// Transparent broadcast-style football character.
///
/// The old implementation placed rectangular JPG crops over the pitch. Even
/// with a mask, the photograph background remained visible on some devices.
/// This component draws only the character, so the stadium always remains a
/// single continuous scene with no pasted rectangles.
class RealisticFootballSprite extends StatelessWidget {
  const RealisticFootballSprite({
    super.key,
    required this.pose,
    required this.primary,
    required this.secondary,
    this.mirror = false,
    this.alignment = Alignment.center,
  });

  final FootballSpritePose pose;
  final Color primary;
  final Color secondary;
  final bool mirror;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _BroadcastFootballCharacterPainter(
          pose: pose,
          primary: primary,
          secondary: secondary,
          mirror: mirror,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BroadcastFootballCharacterPainter extends CustomPainter {
  const _BroadcastFootballCharacterPainter({
    required this.pose,
    required this.primary,
    required this.secondary,
    required this.mirror,
  });

  final FootballSpritePose pose;
  final Color primary;
  final Color secondary;
  final bool mirror;

  bool get _isKeeper =>
      pose == FootballSpritePose.keeperReady ||
      pose == FootballSpritePose.keeperDive;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 310, size.height / 390);
    final origin = Offset(size.width / 2, size.height * .93);

    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    if (mirror) canvas.scale(-1, 1);
    canvas.scale(scale, scale);

    if (pose == FootballSpritePose.keeperDive) {
      canvas.translate(0, -18);
      canvas.rotate(-.30);
    } else if (pose == FootballSpritePose.playerRun) {
      canvas.rotate(-.055);
    } else if (pose == FootballSpritePose.playerKick) {
      canvas.rotate(-.035);
    }

    _drawGroundShadow(canvas);
    _drawCharacter(canvas);
    canvas.restore();
  }

  void _drawGroundShadow(Canvas canvas) {
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: .46)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    final width = pose == FootballSpritePose.keeperDive ? 210.0 : 122.0;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(4, -6), width: width, height: 24),
      shadow,
    );
  }

  void _drawCharacter(Canvas canvas) {
    final readyKeeper = pose == FootballSpritePose.keeperReady;
    final divingKeeper = pose == FootballSpritePose.keeperDive;
    final kicking = pose == FootballSpritePose.playerKick;
    final running = pose == FootballSpritePose.playerRun;

    final skin = const Color(0xFFD8A07A);
    final skinShade = const Color(0xFF9D6247);
    final shorts = secondary;
    final sock = Color.lerp(primary, Colors.white, .20)!;
    final boot = const Color(0xFF111827);

    if (divingKeeper) {
      _limb(canvas, const Offset(-22, -112), const Offset(-69, -70), 24,
          shorts, shorts.withValues(alpha: .80));
      _limb(canvas, const Offset(19, -111), const Offset(75, -75), 24,
          shorts, shorts.withValues(alpha: .80));
      _limb(canvas, const Offset(-69, -70), const Offset(-103, -39), 19,
          sock, sock.withValues(alpha: .72));
      _limb(canvas, const Offset(75, -75), const Offset(112, -51), 19,
          sock, sock.withValues(alpha: .72));
      _boot(canvas, const Offset(-111, -35), -.18, boot);
      _boot(canvas, const Offset(119, -47), .16, boot);
    } else {
      final leftKnee = Offset(
        kicking ? -17 : (running ? -31 : -29),
        kicking ? -94 : -78,
      );
      final rightKnee = Offset(
        kicking ? 42 : (running ? 25 : 30),
        kicking ? -76 : -82,
      );
      final leftFoot = Offset(
        kicking ? -18 : (running ? -49 : -39),
        -14,
      );
      final rightFoot = Offset(
        kicking ? 103 : (running ? 49 : 41),
        kicking ? -48 : -13,
      );
      _limb(canvas, const Offset(-20, -128), leftKnee, 27, shorts,
          shorts.withValues(alpha: .82));
      _limb(canvas, const Offset(20, -128), rightKnee, 27, shorts,
          shorts.withValues(alpha: .82));
      _limb(canvas, leftKnee, leftFoot, 20, sock, sock.withValues(alpha: .72));
      _limb(canvas, rightKnee, rightFoot, 20, sock, sock.withValues(alpha: .72));
      _boot(canvas, leftFoot, -.06, boot);
      _boot(canvas, rightFoot, kicking ? -.34 : .08, boot);
    }

    final torsoRect = Rect.fromCenter(
      center: Offset(divingKeeper ? 0 : 0, -203),
      width: _isKeeper ? 95 : 82,
      height: _isKeeper ? 112 : 104,
    );
    final torso = Path()
      ..moveTo(torsoRect.left + 16, torsoRect.top)
      ..quadraticBezierTo(0, torsoRect.top - 8, torsoRect.right - 16, torsoRect.top)
      ..lineTo(torsoRect.right, torsoRect.bottom - 18)
      ..quadraticBezierTo(0, torsoRect.bottom + 8, torsoRect.left, torsoRect.bottom - 18)
      ..close();
    final jersey = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color.lerp(primary, Colors.white, .22)!,
          primary,
          Color.lerp(primary, secondary, .42)!,
        ],
        stops: const <double>[0, .48, 1],
      ).createShader(torsoRect);
    canvas.drawPath(torso, jersey);

    final jerseyEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.white.withValues(alpha: .26);
    canvas.drawPath(torso, jerseyEdge);

    if (readyKeeper) {
      _limb(canvas, const Offset(-37, -230), const Offset(-92, -189), 20,
          primary, primary.withValues(alpha: .72));
      _limb(canvas, const Offset(37, -230), const Offset(92, -189), 20,
          primary, primary.withValues(alpha: .72));
      _limb(canvas, const Offset(-92, -189), const Offset(-117, -158), 15,
          skin, skinShade);
      _limb(canvas, const Offset(92, -189), const Offset(117, -158), 15,
          skin, skinShade);
      _glove(canvas, const Offset(-123, -153), primary);
      _glove(canvas, const Offset(123, -153), primary);
    } else if (divingKeeper) {
      _limb(canvas, const Offset(-32, -229), const Offset(-104, -242), 21,
          primary, primary.withValues(alpha: .75));
      _limb(canvas, const Offset(34, -229), const Offset(116, -263), 21,
          primary, primary.withValues(alpha: .75));
      _limb(canvas, const Offset(-104, -242), const Offset(-154, -240), 15,
          skin, skinShade);
      _limb(canvas, const Offset(116, -263), const Offset(167, -278), 15,
          skin, skinShade);
      _glove(canvas, const Offset(-164, -239), primary);
      _glove(canvas, const Offset(178, -282), primary);
    } else {
      final leftHand = Offset(running ? -86 : -72, running ? -188 : -196);
      final rightHand = Offset(kicking ? 88 : 74, kicking ? -176 : -198);
      _limb(canvas, const Offset(-34, -230), leftHand, 17, primary,
          primary.withValues(alpha: .72));
      _limb(canvas, const Offset(34, -230), rightHand, 17, primary,
          primary.withValues(alpha: .72));
      canvas.drawCircle(leftHand, 10, Paint()..color = skin);
      canvas.drawCircle(rightHand, 10, Paint()..color = skin);
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-12, -283, 24, 34),
        const Radius.circular(8),
      ),
      Paint()..color = skinShade,
    );
    final headRect = const Rect.fromLTWH(-27, -323, 54, 64);
    canvas.drawOval(
      headRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[skin, skinShade],
        ).createShader(headRect),
    );

    final hair = Path()
      ..moveTo(-25, -302)
      ..quadraticBezierTo(-22, -335, 8, -334)
      ..quadraticBezierTo(29, -326, 25, -300)
      ..quadraticBezierTo(5, -315, -25, -302)
      ..close();
    canvas.drawPath(hair, Paint()..color = const Color(0xFF171717));
    canvas.drawArc(
      const Rect.fromLTWH(-18, -296, 36, 22),
      .1,
      math.pi - .2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.black.withValues(alpha: .24),
    );

    final chest = Paint()
      ..color = Colors.white.withValues(alpha: .82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(const Offset(0, -213), 13, chest);
    canvas.drawLine(const Offset(-6, -213), const Offset(6, -213), chest);

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = Colors.white.withValues(alpha: .18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4);
    canvas.drawPath(torso, rim);
  }

  void _limb(
    Canvas canvas,
    Offset start,
    Offset end,
    double width,
    Color a,
    Color b,
  ) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[a, b],
      ).createShader(Rect.fromPoints(start, end).inflate(width));
    paint.strokeCap = StrokeCap.round;
    paint.strokeWidth = width;
    canvas.drawLine(start, end, paint);
  }

  void _glove(Canvas canvas, Offset center, Color accent) {
    canvas.drawCircle(
      center,
      16,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[Colors.white, Color.lerp(Colors.white, accent, .62)!],
        ).createShader(Rect.fromCircle(center: center, radius: 16)),
    );
    canvas.drawCircle(
      center,
      16,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: .70),
    );
  }

  void _boot(Canvas canvas, Offset center, double angle, Color color) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-15, -6, 38, 15),
      const Radius.circular(7),
    );
    canvas.drawRRect(rect, Paint()..color = color);
    canvas.drawLine(
      const Offset(-8, 5),
      const Offset(18, 5),
      Paint()
        ..color = Colors.white.withValues(alpha: .18)
        ..strokeWidth = 2,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BroadcastFootballCharacterPainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.mirror != mirror;
  }
}
