import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'road_scene_geometry.dart';

enum RoadSceneWeather { day, sunset, night, fog, snow, rain }

@immutable
class RoadTrafficVisual {
  const RoadTrafficVisual(this.x, this.y, this.lane);
  final double x, y;
  final int lane;
}

/// Smooth vector presentation of the unchanged normalized road simulation.
class RoadScenePainter extends CustomPainter {
  const RoadScenePainter(
      {required this.playerX,
      this.opponentX,
      required this.traffic,
      required this.weather,
      required this.travel,
      this.steer = 0});
  final double playerX;
  final double? opponentX;
  final List<RoadTrafficVisual> traffic;
  final RoadSceneWeather weather;
  final double travel, steer;

  bool get dark => weather == RoadSceneWeather.night;
  bool get wet => weather == RoadSceneWeather.rain;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final g = RoadSceneGeometry(size);
    final bounds = Offset.zero & size;
    canvas.save();
    canvas.clipRect(bounds);
    _landscape(canvas, g, bounds);
    _road(canvas, g, bounds);
    final sorted = [...traffic]..sort((a, b) => a.y.compareTo(b.y));
    for (final car in sorted) {
      if (car.y < -.02 || car.y > 1.25) continue;
      _car(canvas, g, car.x, car.y, _palette[car.lane.abs() % _palette.length]);
    }
    if (dark || wet || weather == RoadSceneWeather.fog) _headlights(canvas, g);
    if (opponentX != null) {
      _car(canvas, g, opponentX!, RoadSceneGeometry.playerY,
          const Color(0xFFFFA45D),
          remote: true);
    }
    _car(canvas, g, playerX, RoadSceneGeometry.playerY, const Color(0xFF43C7F4),
        lean: steer);
    _atmosphere(canvas, g, bounds);
    canvas.restore();
  }

  static const _palette = [
    Color(0xFFEA665D),
    Color(0xFFF1CC65),
    Color(0xFF71C49A),
    Color(0xFFB29CDE),
    Color(0xFFF9A96C)
  ];

  void _landscape(Canvas c, RoadSceneGeometry g, Rect bounds) {
    final s = g.size;
    final sky = switch (weather) {
      RoadSceneWeather.day => const [Color(0xFF82BED1), Color(0xFFE5EEE5)],
      RoadSceneWeather.sunset => const [Color(0xFF686F96), Color(0xFFF3BE95)],
      RoadSceneWeather.night => const [Color(0xFF111F36), Color(0xFF42536D)],
      RoadSceneWeather.fog => const [Color(0xFFA9BEC6), Color(0xFFD8E1DF)],
      RoadSceneWeather.snow => const [Color(0xFFADC8D9), Color(0xFFE8F0F2)],
      RoadSceneWeather.rain => const [Color(0xFF566C82), Color(0xFF99ACB3)],
    };
    c.drawRect(
        bounds,
        Paint()
          ..shader = LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: sky)
              .createShader(Rect.fromLTWH(0, 0, s.width, s.height * .3)));
    if (weather == RoadSceneWeather.day ||
        weather == RoadSceneWeather.sunset ||
        dark) {
      final sun = Offset(s.width * .77, s.height * .065);
      final radius = math.min(s.width * .044, s.height * .043);
      c.drawCircle(
          sun,
          radius * 2.5,
          Paint()
            ..shader = RadialGradient(colors: [
              const Color(0xFFFFE3AF).withValues(alpha: .25),
              Colors.transparent
            ]).createShader(
                Rect.fromCircle(center: sun, radius: radius * 2.5)));
      c.drawCircle(
          sun,
          radius,
          Paint()
            ..color = dark ? const Color(0xFFDCE6EE) : const Color(0xFFFFE7AF));
    }
    final hills = Path()
      ..moveTo(0, s.height * .15)
      ..cubicTo(s.width * .1, s.height * .02, s.width * .2, s.height * .06,
          s.width * .34, s.height * .13)
      ..cubicTo(s.width * .53, s.height * .02, s.width * .64, s.height * .10,
          s.width * .76, s.height * .115)
      ..quadraticBezierTo(
          s.width * .9, s.height * .035, s.width, s.height * .13)
      ..lineTo(s.width, s.height * .25)
      ..lineTo(0, s.height * .25)
      ..close();
    c.drawPath(
        hills,
        Paint()
          ..color = dark
              ? const Color(0xFF344D58)
              : const Color(0xFF6F938D).withValues(alpha: .6));
    final ground = weather == RoadSceneWeather.snow
        ? const Color(0xFFD8E4E7)
        : dark
            ? const Color(0xFF263D39)
            : const Color(0xFF6F9677);
    c.drawRect(
        Rect.fromLTWH(0, s.height * .14, s.width, s.height),
        Paint()
          ..shader = LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.lerp(ground, sky.last, .35)!, ground])
              .createShader(bounds));
    for (var side = 0; side < 2; side++) {
      final verge = Path()..moveTo(side == 0 ? 0 : s.width, s.height * .18);
      for (var i = 0; i <= 16; i++) {
        final y = i / 16;
        final p = g.project(side == 0 ? -.02 : 1.02, y);
        verge.lineTo(
            p.dx +
                (side == 0 ? -1 : 1) * math.sin(i * 2.3) * 8 * g.depthScale(y),
            p.dy);
      }
      verge.lineTo(side == 0 ? 0 : s.width, s.height);
      verge.close();
      c.drawPath(
          verge,
          Paint()
            ..color = (dark ? const Color(0xFF1B322E) : const Color(0xFF52785D))
                .withValues(
                    alpha: weather == RoadSceneWeather.snow ? .12 : .35));
    }
  }

  Path _strip(RoadSceneGeometry g, double left, double right, double top,
          double bottom) =>
      Path()
        ..moveTo(g.project(left, top).dx, g.project(left, top).dy)
        ..lineTo(g.project(right, top).dx, g.project(right, top).dy)
        ..lineTo(g.project(right, bottom).dx, g.project(right, bottom).dy)
        ..lineTo(g.project(left, bottom).dx, g.project(left, bottom).dy)
        ..close();

  void _road(Canvas c, RoadSceneGeometry g, Rect bounds) {
    final shoulder = _strip(g, .072, .928, 0, 1.4);
    c.drawPath(
        shoulder,
        Paint()
          ..color = weather == RoadSceneWeather.snow
              ? const Color(0xFFF0F3EF)
              : const Color(0xFFB8B5A3));
    final road = _strip(g, .1, .9, 0, 1.4);
    c.drawPath(
        road,
        Paint()
          ..shader = LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: dark
                      ? const [Color(0xFF52616A), Color(0xFF303E49)]
                      : const [Color(0xFF879397), Color(0xFF4B565E)])
              .createShader(bounds));
    c.save();
    c.clipPath(road);
    // Deterministic low contrast aggregate texture, independent of gameplay RNG.
    for (var i = 0; i < 540; i++) {
      final y = ((i * 41.73 + travel * .23) % g.size.height);
      final x = ((i * 73.17) % g.size.width);
      c.drawCircle(
          Offset(x, y),
          .45 + (i % 3) * .16,
          Paint()
            ..color = (i.isEven ? Colors.white : Colors.black)
                .withValues(alpha: .045));
    }
    if (wet) {
      for (var i = 0; i < 7; i++) {
        final x = .2 + i * .1;
        c.drawPath(_strip(g, x, x + .015, .1, 1.3),
            Paint()..color = const Color(0xFFCADBE5).withValues(alpha: .06));
      }
    }
    c.restore();
    for (final edge in [.106, .894]) {
      c.drawPath(_strip(g, edge - .002, edge + .002, 0, 1.4),
          Paint()..color = const Color(0xFFF2EFE0).withValues(alpha: .88));
    }
    // Five traffic corridors share the same world projection as the cars.
    for (final x in [.22, .34, .46, .58, .70, .82]) {
      for (var i = 0; i < 15; i++) {
        final y = ((i / 15 + travel * .0014) % 1.25) - .12;
        if (y < 0) continue;
        c.drawPath(
            _strip(g, x - .0018, x + .0018, y, y + .043),
            Paint()
              ..color =
                  const Color(0xFFF4F1DF).withValues(alpha: dark ? .66 : .72));
      }
    }
    for (var i = 0; i < 11; i++) {
      final y = ((i / 11 + travel * .0014) % 1.2);
      for (final x in [.055, .945]) {
        final p = g.project(x, y);
        final scale = g.depthScale(y);
        c.drawLine(
            p,
            p.translate(0, -g.size.height * .021 * scale),
            Paint()
              ..color = const Color(0xFFE6E9E5)
              ..strokeWidth = math.max(1, g.size.width * .003 * scale));
        c.drawCircle(
            p.translate(0, -g.size.height * .021 * scale),
            math.max(.7, g.size.width * .003 * scale),
            Paint()..color = const Color(0xFFFFCF85));
      }
    }
    if (weather == RoadSceneWeather.fog) {
      final fog = Rect.fromLTWH(
          0, g.size.height * .12, g.size.width, g.size.height * .4);
      c.drawRect(
          fog,
          Paint()
            ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFE0E8E8).withValues(alpha: .62),
                  Colors.transparent
                ]).createShader(fog));
    }
  }

  void _headlights(Canvas c, RoadSceneGeometry g) {
    final p = g.project(playerX, RoadSceneGeometry.playerY);
    final top = g.project(playerX, .35);
    final width = g.carSize(.82).width;
    final beam = Path()
      ..moveTo(p.dx - width * .38, p.dy - width * .6)
      ..lineTo(top.dx - width * 1.8, top.dy)
      ..quadraticBezierTo(
          top.dx, top.dy - width * .3, top.dx + width * 1.8, top.dy)
      ..lineTo(p.dx + width * .38, p.dy - width * .6)
      ..close();
    c.drawPath(
        beam,
        Paint()
          ..shader = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                const Color(0xFFFFF0CB).withValues(alpha: .20),
                const Color(0xFFFFF0CB).withValues(alpha: .015)
              ]).createShader(beam.getBounds()));
  }

  void _car(Canvas c, RoadSceneGeometry g, double x, double y, Color body,
      {double lean = 0, bool remote = false}) {
    final center = g.project(x, y);
    final size = g.carSize(y);
    final w = size.width, h = size.height;
    c.save();
    c.translate(center.dx, center.dy);
    c.drawOval(
        Rect.fromCenter(
            center: Offset(w * .06, h * .08), width: w * 1.18, height: h * .94),
        Paint()
          ..color = const Color(0xFF0A1821).withValues(alpha: .32)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * .1));
    c.rotate(lean.clamp(-.065, .065));
    for (final side in [-1, 1]) {
      for (final axle in [-.28, .29]) {
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: Offset(side * w * .46, h * axle),
                    width: w * .18,
                    height: h * .20),
                Radius.circular(w * .055)),
            Paint()..color = const Color(0xFF15202B));
        c.drawLine(
            Offset(side * w * .49, h * axle - h * .065),
            Offset(side * w * .49, h * axle + h * .065),
            Paint()
              ..color = const Color(0xFF74808A)
              ..strokeWidth = w * .028);
      }
    }
    final shell = Path()
      ..moveTo(-w * .29, -h * .5)
      ..cubicTo(-w * .43, -h * .47, -w * .46, -h * .23, -w * .46, 0)
      ..lineTo(-w * .45, h * .36)
      ..quadraticBezierTo(-w * .43, h * .49, -w * .30, h * .5)
      ..lineTo(w * .30, h * .5)
      ..quadraticBezierTo(w * .43, h * .49, w * .45, h * .36)
      ..lineTo(w * .46, 0)
      ..cubicTo(w * .46, -h * .23, w * .43, -h * .47, w * .29, -h * .5)
      ..close();
    final carBounds = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    c.drawPath(
        shell,
        Paint()
          ..shader = LinearGradient(colors: [
            Color.lerp(body, Colors.black, .3)!,
            body,
            Color.lerp(body, Colors.white, .3)!,
            body,
            Color.lerp(body, Colors.black, .25)!
          ], stops: const [
            0,
            .22,
            .44,
            .72,
            1
          ]).createShader(carBounds));
    c.drawPath(
        shell,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(.5, w * .018)
          ..color = Colors.white.withValues(alpha: .24));
    final glass = Path()
      ..moveTo(-w * .30, -h * .235)
      ..quadraticBezierTo(0, -h * .30, w * .30, -h * .235)
      ..lineTo(w * .255, -h * .055)
      ..quadraticBezierTo(0, -h * .095, -w * .255, -h * .055)
      ..close();
    c.drawPath(
        glass,
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFC1E0E9), Color(0xFF213C54)])
              .createShader(carBounds));
    final roof = RRect.fromRectAndRadius(
        Rect.fromLTRB(-w * .265, -h * .045, w * .265, h * .20),
        Radius.circular(w * .07));
    c.drawRRect(roof, Paint()..color = Color.lerp(body, Colors.white, .12)!);
    final rear = Path()
      ..moveTo(-w * .265, h * .23)
      ..lineTo(w * .265, h * .23)
      ..lineTo(w * .32, h * .36)
      ..quadraticBezierTo(0, h * .39, -w * .32, h * .36)
      ..close();
    c.drawPath(rear, Paint()..color = const Color(0xFF253E50));
    c.drawLine(
        Offset(-w * .17, -h * .38),
        Offset(w * .20, -h * .38),
        Paint()
          ..strokeWidth = w * .024
          ..color = Colors.white.withValues(alpha: .4));
    c.drawLine(
        Offset(-w * .22, -h * .21),
        Offset(w * .1, -h * .12),
        Paint()
          ..strokeWidth = w * .033
          ..color = Colors.white.withValues(alpha: .3));
    for (final side in [-1, 1]) {
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(side * w * .295, -h * .405),
                  width: w * .20,
                  height: h * .055),
              Radius.circular(w * .04)),
          Paint()..color = const Color(0xFFFFF2C7));
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(side * w * .31, h * .405),
                  width: w * .18,
                  height: h * .04),
              Radius.circular(w * .02)),
          Paint()..color = const Color(0xFFEC5658));
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(side * w * .49, -h * .075),
                  width: w * .12,
                  height: h * .055),
              Radius.circular(w * .025)),
          Paint()..color = body);
    }
    c.drawLine(
        Offset(-w * .26, h * .46),
        Offset(w * .26, h * .46),
        Paint()
          ..color = const Color(0xFF283849)
          ..strokeWidth = w * .045);
    if (remote) {
      c.drawCircle(Offset(0, h * .1), w * .075,
          Paint()..color = const Color(0xFFFFEDD3));
    }
    c.restore();
  }

  void _atmosphere(Canvas c, RoadSceneGeometry g, Rect bounds) {
    if (weather != RoadSceneWeather.snow && !wet) return;
    for (var i = 0; i < 65; i++) {
      final x = (i * 67.39 + travel * (wet ? .6 : .17)) % g.size.width;
      final y = (i * 43.71 + travel * (wet ? 2.2 : .55)) % g.size.height;
      if (wet) {
        c.drawLine(
            Offset(x, y),
            Offset(x - 2, y + 8 + i % 6),
            Paint()
              ..strokeWidth = .7
              ..color = const Color(0xFFD7E6EC).withValues(alpha: .32));
      } else {
        c.drawCircle(Offset(x, y), .7 + i % 3 * .35,
            Paint()..color = Colors.white.withValues(alpha: .7));
      }
    }
  }

  @override
  bool shouldRepaint(covariant RoadScenePainter old) => true;
}
