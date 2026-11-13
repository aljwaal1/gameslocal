import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/retro_road/road_scene_geometry.dart';

void main() {
  for (final size in [
    const Size(296, 430),
    const Size(366, 640),
    const Size(616, 180)
  ]) {
    test('perspective depth, symmetric lanes and collision anchor $size', () {
      final g = RoadSceneGeometry(size);
      var previous = 0.0;
      for (var i = 0; i <= 100; i++) {
        final y = i / 100;
        expect(g.depthScale(y), greaterThanOrEqualTo(previous));
        previous = g.depthScale(y);
        expect(g.project(.5, y).dx, closeTo(size.width / 2, .00001));
        expect(g.project(.28, y).dx + g.project(.72, y).dx,
            closeTo(size.width, .00001));
        expect(g.roadHalfWidth(y), greaterThan(0));
      }
      for (final x in [.16, .28, .5, .76, .84]) {
        final center = g.project(x, RoadSceneGeometry.playerY);
        expect(center.dx, closeTo(x * size.width, .00001));
        expect(center.dy, closeTo(size.height * .82, .00001));
        expect(g.worldXForTouch(center.dx), closeTo(x, .00001));
      }
      expect(g.project(.3, .1).dx, greaterThan(g.project(.3, .8).dx));
      expect(g.carSize(.8).width, greaterThan(g.carSize(.1).width));
    });
  }
  test('invalid and offscreen inputs remain finite and bounded', () {
    for (final size in [
      Size.zero,
      const Size(1e308, 1e308),
      const Size(double.infinity, double.nan),
      const Size(320, 640)
    ]) {
      final g = RoadSceneGeometry(size);
      for (final value in [
        double.nan,
        double.infinity,
        double.negativeInfinity,
        -100.0,
        100.0
      ]) {
        final p = g.project(value, value);
        expect(p.dx.isFinite && p.dy.isFinite, isTrue);
        expect(g.depthScale(value).isFinite, isTrue);
        expect(g.roadHalfWidth(value).isFinite, isTrue);
        expect(g.carSize(value).isFinite, isTrue);
      }
    }
  });
}
