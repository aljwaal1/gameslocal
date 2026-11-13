import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/fuel_plane/plane_scene_geometry.dart';

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(640, 320),
  ]) {
    test('projected flight stays aligned with collision and touch at $size',
        () {
      final scene = PlaneSceneGeometry(size);
      for (final x in [.08, .23, .5, .67, .92]) {
        final point = scene.project(x, PlaneSceneGeometry.playerY);
        expect(point.dx, closeTo(size.width * x, .0001));
        expect(point.dy, closeTo(size.height * .82, .0001));
        expect(scene.worldXForTouch(point.dx), closeTo(x, .0001));
      }
      expect(scene.project(.5, .2).dx, size.width / 2);
      expect(scene.depthScale(-.08), lessThan(scene.depthScale(.4)));
      expect(scene.depthScale(.4), lessThan(scene.depthScale(.82)));
      expect(scene.depthScale(.82), lessThan(scene.depthScale(1.12)));
      expect(scene.aircraftSize(.82).longestSide,
          lessThan(size.shortestSide * .24));
      expect(scene.project(.5, -.08).dy, lessThan(0));
      expect(scene.project(.5, 1.12).dy, greaterThan(size.height));
    });
  }

  test('invalid and far offscreen positions are finite and bounded', () {
    final scene = PlaneSceneGeometry(const Size(320, 640));
    for (final value in [double.nan, double.infinity, -1e20, 1e20]) {
      final point = scene.project(value, value);
      expect(point.isFinite, isTrue);
      expect(point.dx, inInclusiveRange(-320, 640));
      expect(point.dy, inInclusiveRange(-640, 1280));
      expect(scene.depthScale(value), inInclusiveRange(.4, 1.4));
      expect(scene.worldXForTouch(value), inInclusiveRange(.08, .92));
    }
    final empty = PlaneSceneGeometry(const Size(double.nan, 0));
    expect(empty.project(.5, .82).isFinite, isTrue);
    expect(empty.aircraftSize(.82).isFinite, isTrue);
  });

  test('bank is symmetric, monotonic and capped for a large drag', () {
    expect(PlaneSceneGeometry.bankForDelta(0), 0);
    expect(PlaneSceneGeometry.bankForDelta(double.nan), 0);
    expect(PlaneSceneGeometry.bankForDelta(.02), greaterThan(0));
    expect(PlaneSceneGeometry.bankForDelta(.02),
        lessThan(PlaneSceneGeometry.bankForDelta(.1)));
    expect(PlaneSceneGeometry.bankForDelta(-.1),
        -PlaneSceneGeometry.bankForDelta(.1));
    expect(PlaneSceneGeometry.bankForDelta(10), lessThanOrEqualTo(.3));
    expect(PlaneSceneGeometry.bankForDelta(-10),
        -PlaneSceneGeometry.bankForDelta(10));
  });
}
