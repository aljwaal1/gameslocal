import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/air_hockey/hockey_physics.dart';

void main() {
  test('pixel distance respects a tall field aspect ratio', () {
    const field = Size(360, 720);
    final delta = HockeyGeometry.pixelDelta(
      const Offset(.5, .5),
      const Offset(.5, .6),
      field,
    );
    expect(delta.dx, closeTo(0, .000001));
    expect(delta.dy, closeTo(-72, .000001));
  });

  test('normalized offset preserves a pixel collision radius', () {
    const field = Size(360, 720);
    final offset = HockeyGeometry.normalizedOffset(
      const Offset(0, 36),
      field,
    );
    expect(offset.dx, closeTo(0, .0001));
    expect(offset.dy, closeTo(.05, .0001));
  });
}
