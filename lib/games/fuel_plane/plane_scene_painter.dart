import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'plane_scene_geometry.dart';
import 'plane_scene_motion.dart';

enum PlaneObstacleKind { fuel, rock, enemy }

class PlaneObstacle {
  const PlaneObstacle(this.x, this.y, this.size, this.kind);
  final double x, y, size;
  final PlaneObstacleKind kind;
}

class PlaneProjectile {
  const PlaneProjectile(this.x, this.y, {this.remote = false});
  final double x, y;
  final bool remote;
}

enum _Aircraft {
  local(Color(0xff81efff), Color(0xff167ab0), Color(0xffe5faff)),
  remote(Color(0xffffc366), Color(0xffb95321), Color(0xfffff1c7)),
  enemy(Color(0xfff06765), Color(0xff8f283a), Color(0xffffb4a0));

  const _Aircraft(this.highlight, this.base, this.trim);
  final Color highlight, base, trim;
}

class PlaneScenePainter extends CustomPainter {
  PlaneScenePainter({
    required this.localX,
    this.remoteX,
    this.localAlive = true,
    this.remoteAlive = true,
    required this.distance,
    required this.obstacles,
    required this.projectiles,
    this.motion,
  }) : super(repaint: motion);

  final double localX;
  final double? remoteX;
  final bool localAlive, remoteAlive;
  final int distance;
  final List<PlaneObstacle> obstacles;
  final List<PlaneProjectile> projectiles;
  final PlaneSceneMotion? motion;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final geometry = PlaneSceneGeometry(size);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    _paintCoast(canvas, size);
    for (final obstacle in obstacles) {
      _paintObstacle(canvas, geometry, obstacle);
    }
    for (final projectile in projectiles) {
      _paintProjectile(canvas, geometry, projectile);
    }

    final span = geometry.aircraftSize(PlaneSceneGeometry.playerY);
    final peer = remoteX;
    if (peer != null && remoteAlive) {
      final center = geometry.project(peer, PlaneSceneGeometry.playerY);
      if (localAlive && (peer - localX).abs() * size.width < span.width * .55) {
        // When the two aircraft share a collision center, show the peer's
        // amber silhouette just beyond the local wings.
        final ring = Paint()
          ..color = _Aircraft.remote.highlight
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        final oval = Rect.fromCenter(
          center: center,
          width: span.width * 1.16,
          height: span.height * 1.15,
        );
        canvas.drawArc(oval, .2, .85, false, ring);
        canvas.drawArc(oval, math.pi + .2, .85, false, ring);
      }
      _paintAircraft(
        canvas,
        center,
        span,
        _Aircraft.remote,
        bank: motion?.remoteBank ?? 0,
        muzzle: motion?.muzzleOpacity(remote: true) ?? 0,
      );
    }
    if (localAlive) {
      _paintAircraft(
        canvas,
        geometry.project(localX, PlaneSceneGeometry.playerY),
        span,
        _Aircraft.local,
        bank: motion?.localBank ?? 0,
        muzzle: motion?.muzzleOpacity(remote: false) ?? 0,
      );
    }

    final effects = motion;
    if (effects != null) {
      for (final burst in effects.bursts) {
        _paintBurst(canvas, geometry, burst);
      }
    }
    canvas.restore();
  }

  void _paintCoast(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final paint = Paint();
    canvas.drawRect(
      bounds,
      paint
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff164a65), Color(0xff176681), Color(0xff103b57)],
        ).createShader(bounds),
    );
    paint.shader = null;
    final width = size.width, height = size.height;
    final travel = distance * .006;

    // The shoreline follows the terrain layer while finer water markings
    // and atmospheric elements move at their own rates.
    for (final right in [false, true]) {
      for (final (offset, color) in const [
        (.074, Color(0xff287b87)),
        (.044, Color(0xff38888a)),
        (.016, Color(0xff78b7a0)),
        (.007, Color(0xffa0ad78)),
        (.0, Color(0xff406b4a)),
        (-.035, Color(0xff345c43)),
        (-.082, Color(0xff2b503f)),
      ]) {
        double shore(double y) {
          final phase = (y - travel) * 2.5 + (right ? 1.8 : .6);
          final inlet = .14 +
              math.sin(phase) * .062 +
              math.sin(phase * 2.0 + .4) * .025 +
              math.sin(phase * 4) * .012;
          final fraction = inlet + offset + (right ? .015 : 0);
          return width * (right ? 1 - fraction : fraction);
        }

        final edge = right ? width : 0.0;
        final land = Path()
          ..moveTo(edge, 0)
          ..lineTo(shore(0), 0);
        const segments = 20;
        for (var i = 1; i <= segments; i++) {
          final y = i / segments;
          final middle = (i - .5) / segments;
          land.quadraticBezierTo(
            shore(middle),
            middle * height,
            shore(y),
            y * height,
          );
        }
        land
          ..lineTo(edge, height)
          ..close();
        canvas.drawPath(land, paint..color = color);
      }
    }

    final unit = size.shortestSide;
    for (var i = 0; i < 5; i++) {
      final y = ((i * .326 + travel * .77) % 1.63) - .27;
      final x = [.3, .72, .35, .75, .27][i] * width;
      final scale = unit * [.102, .061, .036, .115, .05][i];
      canvas.save();
      canvas.translate(x, y * height);
      canvas.rotate(i * .7 - .8);
      canvas.scale(scale);
      final island = Path()
        ..moveTo(-.88, -.27)
        ..cubicTo(-.8, -.69, -.28, -.55, .02, -.78)
        ..cubicTo(.47, -.95, .4, -.23, .7, -.25)
        ..cubicTo(1.07, -.2, .86, .21, .48, .36)
        ..cubicTo(.23, .72, -.15, .8, -.37, .58)
        ..cubicTo(-.48, .34, -1.12, .27, -.88, -.27)
        ..close();
      for (final (layer, color) in const [
        (1.65, Color(0x553ec3b6)),
        (1.29, Color(0xff62ab9c)),
        (1.11, Color(0xffb8b680)),
        (1.0, Color(0xff4b7852)),
        (.65, Color(0xff345e46)),
      ]) {
        canvas.save();
        canvas.scale(layer);
        canvas.drawPath(island, paint..color = color);
        canvas.restore();
      }
      canvas.restore();
    }

    // Thin, curved reflections across the open water and moving cloud banks.
    paint
      ..color = const Color(0x387ac6d3)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1;
    for (var i = 0; i < 42; i++) {
      final x = width * (.24 + ((i * 37) % 59) / 100);
      final y = height * (((i * .061 + travel * .49) % 1.12) - .06);
      final length = unit * (.025 + (i % 7) * .011);
      final ripple = Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(x + length * .52, y - 3, x + length, y - 1);
      canvas.drawPath(ripple, paint);
    }
    paint.style = PaintingStyle.fill;

    for (var i = 0; i < 6; i++) {
      final x = width * (.12 + ((i * 29) % 85) / 100);
      final y = height * (((i * .268 + travel * 1.32) % 1.6) - .3);
      final cloud = Rect.fromCenter(
        center: Offset(x, y),
        width: unit * (.46 + (i % 3) * .14),
        height: unit * (.19 + (i % 2) * .13),
      );
      for (var j = 0; j < 3; j++) {
        final lobe = cloud.shift(Offset(unit * .12 * j, unit * -.024 * j));
        canvas.drawOval(
          lobe,
          paint
            ..shader = const RadialGradient(
              colors: [Color(0x65dcf5f7), Color(0x0edcf5f7), Color(0x00dcf5f7)],
              stops: [0, .68, 1],
            ).createShader(lobe),
        );
      }
    }
    canvas.drawRect(
      bounds,
      paint
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x58b7d9e5), Color(0x00b7d9e5), Color(0x1a082b46)],
          stops: [0, .3, 1],
        ).createShader(bounds),
    );
  }

  void _paintObstacle(
      Canvas canvas, PlaneSceneGeometry geometry, PlaneObstacle obstacle) {
    final center = geometry.project(obstacle.x, obstacle.y);
    final scale = geometry.aircraftSize(obstacle.y) *
        (obstacle.size / .066).clamp(.65, 1.3);
    switch (obstacle.kind) {
      case PlaneObstacleKind.enemy:
        _paintAircraft(canvas, center, scale * .83, _Aircraft.enemy);
      case PlaneObstacleKind.rock:
        _paintRock(canvas, center, scale.width * .78);
      case PlaneObstacleKind.fuel:
        _paintFuel(canvas, center, scale.width * .70);
    }
  }

  void _paintFuel(Canvas canvas, Offset center, double size) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(size / 30);
    final shadow = Paint()..color = const Color(0x660a3026);
    canvas.drawOval(const Rect.fromLTWH(-17, -12, 36, 29), shadow);
    final ring = Paint()
      ..color = const Color(0x9e9bfbb5)
      ..strokeWidth = 1.15
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset.zero, 18, ring);
    final can = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-10, -11, 20, 24),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      can,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xffc6ffd0), Color(0xff61ef94), Color(0xff21a969)],
        ).createShader(can.outerRect),
    );
    final dark = Paint()..color = const Color(0xff145943);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-7, -16, 14, 6), const Radius.circular(2)),
      dark,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-4, -14, 8, 3), const Radius.circular(1)),
      Paint()..color = const Color(0xffb8f9c8),
    );
    final drop = Path()
      ..moveTo(0, -6)
      ..cubicTo(-3, -1, -6, 1, -5, 5)
      ..cubicTo(-4, 9, 4, 9, 5, 5)
      ..cubicTo(6, 1, 3, -1, 0, -6)
      ..close();
    canvas.drawPath(drop, dark);
    canvas.restore();
  }

  void _paintRock(Canvas canvas, Offset center, double size) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(size / 36);
    canvas.drawOval(
      const Rect.fromLTWH(-16, -8, 37, 25),
      Paint()..color = const Color(0x850b2533),
    );
    final outline = Path()
      ..moveTo(-17, 3)
      ..quadraticBezierTo(-18, 0, -15, -5)
      ..lineTo(-8, -12)
      ..quadraticBezierTo(-4, -15, 0, -14)
      ..lineTo(10, -12)
      ..quadraticBezierTo(13, -12, 15, -8)
      ..lineTo(18, 2)
      ..quadraticBezierTo(19, 5, 15, 8)
      ..lineTo(6, 13)
      ..lineTo(-9, 12)
      ..quadraticBezierTo(-15, 10, -17, 3)
      ..close();
    canvas.drawPath(
      outline,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xffd5d0c1), Color(0xffa2a49d), Color(0xff555c61)],
        ).createShader(outline.getBounds()),
    );
    final face = Path()
      ..moveTo(-7, -11)
      ..lineTo(4, -8)
      ..lineTo(11, -2)
      ..lineTo(5, 5)
      ..lineTo(-9, 8)
      ..lineTo(-4, 0);
    canvas.drawPath(face, Paint()..color = const Color(0x56808283));
    final facet = Path()
      ..moveTo(11, -2)
      ..lineTo(16, 5)
      ..lineTo(6, 12)
      ..lineTo(5, 5)
      ..close();
    canvas.drawPath(facet, Paint()..color = const Color(0x74434a50));
    canvas.restore();
  }

  void _paintProjectile(
      Canvas canvas, PlaneSceneGeometry geometry, PlaneProjectile shot) {
    final center = geometry.project(shot.x, shot.y);
    final radius = (geometry.aircraftSize(shot.y).width * .055).clamp(1.3, 3.4);
    final color =
        shot.remote ? const Color(0xffffc475) : const Color(0xffa4f5ff);
    final glow =
        Rect.fromCenter(center: center, width: radius * 7, height: radius * 9);
    canvas.drawOval(
      glow,
      Paint()
        ..shader =
            RadialGradient(colors: [color.withAlpha(135), color.withAlpha(0)])
                .createShader(glow),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: center, width: radius * 1.45, height: radius * 4.9),
        Radius.circular(radius),
      ),
      Paint()..color = color,
    );
    canvas.drawCircle(center - Offset(0, radius), radius * .55,
        Paint()..color = Colors.white);
  }

  void _paintAircraft(
    Canvas canvas,
    Offset center,
    Size size,
    _Aircraft kind, {
    double bank = 0,
    double muzzle = 0,
  }) {
    final hostile = kind == _Aircraft.enemy;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(hostile ? math.pi : bank);
    canvas.scale(size.width / 100 * (1 - bank.abs() * .23), size.height / 100);
    final paint = Paint();
    final wings = Path()
      ..moveTo(-6, -22)
      ..cubicTo(-13, -21, -19, -12, -26, -7)
      ..lineTo(-47, hostile ? -12 : 3)
      ..quadraticBezierTo(-50, 4, -50, 10)
      ..lineTo(-48, 21)
      ..quadraticBezierTo(-46, 25, -41, 23)
      ..lineTo(-10, 15)
      ..quadraticBezierTo(0, 13, 10, 15)
      ..lineTo(41, 23)
      ..quadraticBezierTo(46, 25, 48, 21)
      ..lineTo(50, 10)
      ..quadraticBezierTo(50, 4, 47, hostile ? -12 : 3)
      ..lineTo(26, -7)
      ..cubicTo(19, -12, 13, -21, 6, -22)
      ..close();
    final body = Path()
      ..moveTo(0, -50)
      ..cubicTo(-10, -48, -12, -32, -12, -15)
      ..cubicTo(-12, 7, -10, 21, -7, 36)
      ..quadraticBezierTo(-5, 46, 0, 48)
      ..quadraticBezierTo(5, 46, 7, 36)
      ..cubicTo(10, 21, 12, 7, 12, -15)
      ..cubicTo(12, -32, 10, -48, 0, -50)
      ..close();
    final tail = Path()
      ..moveTo(-5, 23)
      ..quadraticBezierTo(-12, 31, -23, 36)
      ..quadraticBezierTo(-27, 39, -24, 43)
      ..lineTo(-5, 39)
      ..lineTo(5, 39)
      ..lineTo(24, 43)
      ..quadraticBezierTo(27, 39, 23, 36)
      ..quadraticBezierTo(12, 31, 5, 23)
      ..close();

    paint
      ..color = const Color(0x7506212d)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.save();
    canvas.translate(4 + bank * 10, 9);
    canvas.drawPath(wings, paint);
    canvas.drawPath(body, paint);
    canvas.drawPath(tail, paint);
    canvas.restore();
    paint.maskFilter = null;

    paint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [kind.trim, kind.highlight, kind.base],
      stops: const [0, .47, 1],
    ).createShader(wings.getBounds());
    canvas.drawPath(wings, paint);
    paint.shader = null;
    canvas.drawPath(tail, paint..color = kind.highlight);

    for (final side in [-1, 1]) {
      final exhaust = Path()
        ..moveTo(side * 14, 29)
        ..quadraticBezierTo(side * 12, 41, side * 18, 59 + (distance % 4) * 1.3)
        ..quadraticBezierTo(side * 23, 43, side * 22, 29)
        ..close();
      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          kind.trim,
          kind.highlight.withAlpha(170),
          kind.highlight.withAlpha(0)
        ],
      ).createShader(exhaust.getBounds());
      canvas.drawPath(exhaust, paint);
      paint.shader = null;
      final pod = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(side * 18, 13), width: 11, height: 40),
        const Radius.circular(5.5),
      );
      canvas.drawRRect(pod, paint..color = kind.base);
      final nacelle = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(side * 18 - 1, 11), width: 6, height: 30),
        const Radius.circular(3),
      );
      canvas.drawRRect(nacelle, paint..color = kind.highlight);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(side * 18, 30), width: 8, height: 5),
        paint..color = kind.trim,
      );
      canvas.drawLine(
        Offset(side * 32, 8),
        Offset(side * 44, 13),
        paint
          ..color = kind.trim
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    paint.shader = LinearGradient(
      colors: [kind.base, kind.trim, kind.highlight, kind.base],
      stops: const [0, .33, .65, 1],
    ).createShader(body.getBounds());
    canvas.drawPath(body, paint);
    final cockpit = Path()
      ..moveTo(0, -33)
      ..cubicTo(-7, -32, -8, -18, -5, -10)
      ..quadraticBezierTo(0, -7, 5, -10)
      ..cubicTo(8, -18, 7, -32, 0, -33)
      ..close();
    paint.shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xffd7f6ff), Color(0xff3c82a0), Color(0xff0e324e)],
    ).createShader(cockpit.getBounds());
    canvas.drawPath(cockpit, paint);
    paint.shader = null;
    canvas.drawLine(
      const Offset(-2, 0),
      const Offset(-1, 27),
      paint
        ..color = kind.trim
        ..strokeWidth = 2,
    );

    if (muzzle > 0) {
      final tip = Offset(0, -55 - (1 - muzzle) * 13);
      final glow = Rect.fromCircle(center: tip, radius: 18);
      canvas.drawCircle(
        tip,
        18,
        paint
          ..shader = RadialGradient(
            colors: [
              kind.trim.withAlpha((230 * muzzle).round()),
              kind.trim.withAlpha(0)
            ],
          ).createShader(glow),
      );
      paint.shader = null;
      canvas.drawOval(
        Rect.fromCenter(center: tip, width: 6 * muzzle, height: 18 * muzzle),
        paint..color = kind.trim,
      );
    }
    canvas.restore();
  }

  void _paintBurst(
      Canvas canvas, PlaneSceneGeometry geometry, PlaneBurstFrame burst) {
    final center = geometry.project(burst.x, burst.y);
    final progress = burst.progress;
    final remaining = 1 - progress;
    final extent =
        geometry.aircraftSize(burst.y).width * (burst.crash ? .94 : .67);
    final radius = extent * (.32 + progress * .68);
    final hot =
        Color.lerp(const Color(0xffffefae), const Color(0xfff57649), progress)!;
    final paint = Paint();
    final glow = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      paint
        ..shader = RadialGradient(
          colors: [hot.withAlpha((220 * remaining).round()), hot.withAlpha(0)],
        ).createShader(glow),
    );
    paint
      ..shader = null
      ..color = hot.withAlpha((175 * remaining).round())
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius * .74, paint);
    paint.style = PaintingStyle.fill;
    final count = burst.crash ? 11 : 7;
    for (var i = 0; i < count; i++) {
      final angle = i * math.pi * 2 / count + burst.x * 3;
      final reach = radius * (.64 + (i % 3) * .18);
      final particle =
          center + Offset(math.cos(angle), math.sin(angle)) * reach;
      canvas.drawCircle(
        particle,
        (extent * .07 * remaining).clamp(.4, 4.4),
        paint..color = hot.withAlpha((225 * remaining).round()),
      );
    }
  }

  @override
  bool shouldRepaint(covariant PlaneScenePainter oldDelegate) =>
      oldDelegate.localX != localX ||
      oldDelegate.remoteX != remoteX ||
      oldDelegate.localAlive != localAlive ||
      oldDelegate.remoteAlive != remoteAlive ||
      oldDelegate.distance != distance ||
      oldDelegate.obstacles != obstacles ||
      oldDelegate.projectiles != projectiles ||
      oldDelegate.motion != motion;
}
