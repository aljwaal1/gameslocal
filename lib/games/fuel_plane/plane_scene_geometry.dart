import 'dart:math' as math;
import 'dart:ui';

/// Maps the simulation's normalized flight field to the canvas.
class PlaneSceneGeometry {
  PlaneSceneGeometry(Size viewport)
      : size = Size(_dimension(viewport.width), _dimension(viewport.height));

  static const playerY = .82;
  final Size size;

  static double _dimension(double value) =>
      value.isFinite ? value.clamp(1.0, 1000000.0) : 1;

  static double _finite(double value, double fallback) =>
      value.isFinite ? value : fallback;

  // Keep world x constant at every depth so fire travels along the same line
  // as the simulation and the sprite center remains under the player's touch.
  Offset project(double x, double y) => Offset(
        _finite(x, .5).clamp(-1.0, 2.0) * size.width,
        _finite(y, 0).clamp(-.35, 1.35) * size.height,
      );

  double depthScale(double y) =>
      .66 + .34 * (_finite(y, 0).clamp(-.08, 1.12) / playerY);

  static double bankForDelta(double delta) =>
      (_finite(delta, 0) * 3.2).clamp(-.28, .28);

  double worldXForTouch(double x) =>
      (_finite(x, size.width * .5) / size.width).clamp(.08, .92);

  Size aircraftSize(double y) {
    final span =
        math.min(size.width * .147, size.height * .205) * depthScale(y);
    return Size(span, span * 1.13);
  }
}
