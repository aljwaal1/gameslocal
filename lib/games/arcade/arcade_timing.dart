import 'dart:math';

class ArcadeTiming {
  const ArcadeTiming._();

  static const double referenceSeconds = .03;

  static double tickScale(double elapsedSeconds) =>
      (elapsedSeconds / referenceSeconds).clamp(.2, 3.0).toDouble();

  static double scaledProbability(double probabilityPerTick, double scale) {
    final safe = probabilityPerTick.clamp(0.0, 1.0).toDouble();
    return 1 - pow(1 - safe, scale).toDouble();
  }
}
