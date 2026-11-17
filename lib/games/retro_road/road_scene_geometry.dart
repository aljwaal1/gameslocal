import 'dart:math' as math;
import 'dart:ui';

/// A presentation projection. The simulation's contact plane stays at y=.82,
/// where world x and touch x are identical in every aspect ratio.
class RoadSceneGeometry {
  RoadSceneGeometry(Size viewport, {this.travel = 0})
      : size = Size(_dimension(viewport.width), _dimension(viewport.height));
  final Size size;
  final double travel;
  static const horizon = .20;
  static const playerY = .82;
  static double _dimension(double value) =>
      value.isFinite && value > 0 ? value.clamp(1.0, 1000000.0) : 1;
  static double _safe(double value, double fallback) =>
      value.isFinite ? value : fallback;

  double depthScale(double y) {
    final t = _safe(y, 0).clamp(0.0, 1.4) / playerY;
    return .035 + .965 * math.pow(t, 1.28).toDouble();
  }

  Offset project(double x, double y) {
    final depth = _safe(y, 0).clamp(-.3, 1.4);
    final t = depth / playerY;
    final forward = (1 - t).clamp(0.0, 1.0);
    // Anchor bends at the contact line so they never shift a collision.
    final bend = .24 *
        forward *
        forward *
        math.cos(_safe(travel, 0) * .00165 + forward * 1.45);
    final vertical = t < 0 ? t * .32 : math.pow(t, 1.28).toDouble();
    return Offset(
      size.width *
          (.5 +
              bend +
              (_safe(x, .5).clamp(-1.0, 2.0) - .5) * depthScale(depth)),
      size.height * (horizon + vertical * (playerY - horizon)),
    );
  }

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
