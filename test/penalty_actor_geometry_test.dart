import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/football/penalty_actor_painter.dart';
import 'package:gameslocal/games/football/penalty_motion_timeline.dart';

void main() {
  test('defensive actor projection bounds malformed keeper coordinates', () {
    for (final target in [
      const Offset(100, 100),
      const Offset(-100, -100),
      const Offset(double.nan, double.infinity)
    ]) {
      final layout = PenaltyActorLayout(
          size: const Size(320, 640),
          goal: const Rect.fromLTWH(48, 90, 224, 186),
          keeperTarget: target,
          frame: const PenaltyMotionTimeline().frame(.9));
      expect(layout.keeperBounds.left, greaterThanOrEqualTo(0));
      expect(layout.keeperBounds.right, lessThanOrEqualTo(320));
      expect(layout.keeperBounds.top, greaterThanOrEqualTo(0));
      expect(layout.keeperBounds.bottom, lessThanOrEqualTo(640));
    }
  });
  test('the image boot reaches the stationary ball during the contact window',
      () {
    for (final size in [
      const Size(320, 640),
      const Size(390, 844),
      const Size(640, 320)
    ]) {
      final ball = Offset(size.width * .5, size.height * .805);
      final radius = math.min(size.width * .041, size.height * .045);
      for (final time in [.34, .36, .38]) {
        final layout = PenaltyActorLayout(
            size: size,
            goal: Rect.fromLTRB(size.width * .15, size.height * .14,
                size.width * .85, size.height * .43),
            keeperTarget: const Offset(.5, .5),
            frame: const PenaltyMotionTimeline().frame(time));
        expect((layout.kickFootPosition - ball).distance,
            lessThanOrEqualTo(radius));
      }
    }
  });
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(640, 320),
    const Size(844, 390),
    const Size(320, 180)
  ]) {
    test('full player and keeper body remain inside $size at every phase', () {
      final goal = Rect.fromLTRB(size.width * .15, size.height * .14,
          size.width * .85, size.height * .43);
      for (final target in [
        const Offset(.04, .08),
        const Offset(.96, .92),
        const Offset(.5, .5)
      ]) {
        for (var i = 0; i <= 100; i++) {
          final layout = PenaltyActorLayout(
              size: size,
              goal: goal,
              keeperTarget: target,
              frame: const PenaltyMotionTimeline().frame(i / 100));
          for (final rect in [
            layout.playerRect,
            layout.kickBounds,
            layout.keeperBounds
          ]) {
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.top, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(size.width));
            expect(rect.bottom, lessThanOrEqualTo(size.height));
          }
        }
      }
    });
  }
}
