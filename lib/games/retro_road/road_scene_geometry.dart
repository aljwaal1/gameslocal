import 'dart:math' as math;
import 'dart:ui';

/// A presentation projection. The simulation's contact plane stays at y=.82,
/// where world x and touch x are identical in every aspect ratio.
class RoadSceneGeometry {
  RoadSceneGeometry(Size viewport)
      : size = Size(_dimension(viewport.width), _dimension(viewport.height));
  final Size size;
  static const playerY = .82;
  static double _dimension(double value) =>
      value.isFinite && value > 0 ? value.clamp(1.0, 1000000.0) : 1;
  static double _safe(double value, double fallback) =>
      value.isFinite ? value : fallback;

  double depthScale(double y) =>
      .20 + .80 * (_safe(y, 0).clamp(0.0, 1.4) / playerY);

  Offset project(double x, double y) => Offset(
      size.width * (.5 + (_safe(x, .5).clamp(-1.0, 2.0) - .5) * depthScale(y)),
      size.height * (.14 + _safe(y, 0).clamp(-.3, 1.4) * (.68 / playerY)));

  double roadHalfWidth(double y) => size.width * .40 * depthScale(y);

  Size carSize(double y) {
    final width =
        math.min(size.width * .088, size.height * .15) * depthScale(y);
    return Size(width, width * 1.9);
  }

  double worldXForTouch(double pixelX) =>
      .5 +
      (_safe(pixelX, size.width * .5) / size.width - .5) / depthScale(playerY);
}
