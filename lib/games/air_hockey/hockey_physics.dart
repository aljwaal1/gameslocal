import 'package:flutter/widgets.dart';

class HockeyGeometry {
  const HockeyGeometry._();

  static Offset pixelDelta(Offset first, Offset second, Size field) => Offset(
        (first.dx - second.dx) * field.width,
        (first.dy - second.dy) * field.height,
      );

  static Offset normalizedOffset(Offset pixels, Size field) => Offset(
        field.width <= 0 ? 0 : pixels.dx / field.width,
        field.height <= 0 ? 0 : pixels.dy / field.height,
      );

  static Offset velocityToPixels(Offset velocity, Size field) => Offset(
        velocity.dx * field.width,
        velocity.dy * field.height,
      );

  static Offset velocityToNormalized(Offset velocity, Size field) =>
      normalizedOffset(velocity, field);
}
