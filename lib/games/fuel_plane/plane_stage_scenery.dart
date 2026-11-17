import 'dart:math' as math;

import 'package:flutter/material.dart';

enum PlaneStageScenery {
  river('النهر الأخضر'),
  canyon('الوادي الصخري'),
  islands('جزر المرجان'),
  ice('المضيق الجليدي'),
  harbor('الميناء الليلي');

  const PlaneStageScenery(this.label);
  final String label;

  static PlaneStageScenery forStage(int stage) =>
      values[(math.max(1, stage) - 1) % values.length];

  void paint(Canvas canvas, Size size, int distance) {
    final colors = switch (this) {
      river => const [Color(0xff205568), Color(0xff12394b)],
      canyon => const [Color(0xff6d482e), Color(0xff412e2b)],
      islands => const [Color(0xff088c9c), Color(0xff124764)],
      ice => const [Color(0xff477d9a), Color(0xff254b67)],
      harbor => const [Color(0xff183048), Color(0xff091728)],
    };
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(bounds),
    );
    // Decorative scenery stays behind the playfield and never blocks flight.
    final travel = distance * .006;
    switch (this) {
      case river:
        break;
      case canyon:
        _cliffs(canvas, size, travel);
      case islands:
        _islands(canvas, size, travel);
      case ice:
        _ice(canvas, size, travel);
      case harbor:
        _harbor(canvas, size, travel);
    }
  }

  static void _cliffs(Canvas canvas, Size size, double travel) {
    final paint = Paint();
    for (final right in [false, true]) {
      for (final (inset, color) in const [
        (.23, Color(0xff372927)),
        (.20, Color(0xff95603c)),
        (.15, Color(0xffb87e4c)),
        (.10, Color(0xff754934)),
      ]) {
        final x = right ? size.width : 0.0;
        final cliff = Path()..moveTo(x, 0);
        final shift = travel % .12;
        for (var i = -1; i < 12; i++) {
          final y = i * .12 + shift;
          final phase = y - travel;
          final width = inset +
              .034 * math.sin(phase * 13 + (right ? 2 : 0)) +
              (i.isEven ? .03 : -.018);
          cliff.lineTo(
              x + (right ? -1 : 1) * size.width * width, y * size.height);
        }
        cliff
          ..lineTo(x, size.height * 1.4)
          ..close();
        canvas.drawPath(cliff, paint..color = color);
      }
    }
  }

  static void _islands(Canvas canvas, Size size, double travel) {
    final paint = Paint();
    final unit = size.shortestSide;
    for (var i = 0; i < 10; i++) {
      final center = Offset(size.width * (i.isEven ? .13 : .86),
          size.height * (((i * .173 + travel) % 1.7) - .32));
      final reef = Rect.fromCenter(
          center: center,
          width: unit * .29,
          height: unit * (.24 + (i % 3) * .079));
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i.isEven ? .42 : -.38);
      final local = reef.shift(-center);
      canvas.drawOval(local, paint..color = const Color(0xff32bdb0));
      canvas.drawOval(
          local.deflate(unit * .021), paint..color = const Color(0xffe5c793));
      canvas.drawOval(
          local.deflate(unit * .045), paint..color = const Color(0xff436d45));
      canvas.drawCircle(Offset(unit * .024, -unit * .036), unit * .041,
          paint..color = const Color(0xff315643));
      canvas.restore();
    }
  }

  static void _ice(Canvas canvas, Size size, double travel) {
    final paint = Paint();
    final unit = size.shortestSide;
    for (var i = 0; i < 13; i++) {
      final x = size.width * (i % 4 < 2 ? .12 + (i % 3) * .074 : .83);
      final y = size.height * (((i * .131 + travel * .83) % 1.7) - .34);
      final r = unit * (.046 + (i % 4) * .025);
      final floe = Path()
        ..moveTo(x - r, y - r * .28)
        ..lineTo(x - r * .25, y - r * .84)
        ..lineTo(x + r * .57, y - r * .61)
        ..lineTo(x + r, y + r * .15)
        ..lineTo(x + r * .32, y + r * .75)
        ..lineTo(x - r * .54, y + r * .6)
        ..close();
      canvas.drawPath(floe.shift(Offset(0, r * .18)),
          paint..color = const Color(0xff609eb7));
      canvas.drawPath(floe, paint..color = const Color(0xffc9e9ed));
      canvas.drawLine(
          Offset(x - r * .53, y + r * .17),
          Offset(x + r * .44, y - r * .31),
          paint
            ..color = const Color(0xff94bdca)
            ..strokeWidth = r * .06);
    }
  }

  static void _harbor(Canvas canvas, Size size, double travel) {
    final paint = Paint();
    final unit = size.shortestSide;
    for (final right in [false, true]) {
      final x = right ? size.width : 0.0;
      final dir = right ? -1 : 1;
      for (var i = 0; i < 7; i++) {
        final y = size.height * (((i * .242 + travel) % 1.7) - .32);
        final length = unit * (.13 + (i % 3) * .055);
        final end = x + dir * length;
        final pier = Rect.fromLTRB(
            math.min(x, end), y, math.max(x, end), y + unit * .066);
        canvas.drawRect(pier.shift(Offset(0, unit * .015)),
            paint..color = const Color(0xff071625));
        canvas.drawRect(pier, paint..color = const Color(0xff516375));
        for (var j = 1; j <= 3; j++) {
          final lamp = Offset(x + dir * length * j / 4, pier.center.dy);
          canvas.drawCircle(
              lamp, unit * .017, paint..color = const Color(0x44f6bd74));
          canvas.drawCircle(
              lamp, unit * .005, paint..color = const Color(0xffffd18c));
          canvas.drawLine(
              lamp.translate(0, unit * .046),
              lamp.translate(0, unit * .086),
              paint
                ..color = const Color(0x77d6ab70)
                ..strokeWidth = unit * .004);
        }
      }
    }
  }
}
