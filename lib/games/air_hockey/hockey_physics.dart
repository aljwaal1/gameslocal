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

class HockeyCollisionResult {
  const HockeyCollisionResult({
    required this.position,
    required this.velocity,
    required this.contact,
    this.struck = false,
  });

  final Offset position;
  final Offset velocity;
  final bool contact;
  final bool struck;
}

/// Contact calculations use logical pixels throughout, independent of aspect.
class HockeyPhysics {
  const HockeyPhysics._();

  static const maximumPuckSpeed = 900.0;
  static const restitution = .90;
  static const paddleNormalTransfer = .65;
  static const separation = 1.0;

  static Offset limitVelocity(Offset velocity) {
    if (!velocity.dx.isFinite || !velocity.dy.isFinite) return Offset.zero;
    return velocity.distance > maximumPuckSpeed
        ? velocity / velocity.distance * maximumPuckSpeed
        : velocity;
  }

  static ({Offset position, Offset velocity}) advancePuck({
    required Offset position,
    required Offset velocity,
    required double dt,
  }) {
    final safeVelocity = limitVelocity(velocity);
    final elapsed = !dt.isFinite || dt <= 0 ? 0.0 : dt.clamp(0.0, .034);
    return (
      position: position + safeVelocity * elapsed,
      velocity: safeVelocity
    );
  }

  static HockeyCollisionResult resolvePaddleCollision({
    required Offset puckPosition,
    required Offset puckVelocity,
    required Offset paddlePosition,
    required Offset paddleVelocity,
    required double combinedRadius,
    bool wasTouching = false,
  }) {
    final velocity = limitVelocity(puckVelocity);
    final delta = puckPosition - paddlePosition;
    final distance = delta.distance;
    // Two pixels of release hysteresis stop a resting/continuously pushed puck
    // from receiving a new strike as the one-pixel separation is integrated.
    if (distance >= combinedRadius + (wasTouching ? 2 : 0)) {
      return HockeyCollisionResult(
          position: puckPosition, velocity: velocity, contact: false);
    }
    final relative = velocity - paddleVelocity;
    final normal = distance > 1e-8
        ? delta / distance
        : relative.distance > 1e-8
            ? -relative / relative.distance
            : const Offset(0, 1);
    final position = distance < combinedRadius + separation
        ? paddlePosition + normal * (combinedRadius + separation)
        : puckPosition;
    final approach = _dot(relative, normal);
    if (wasTouching || approach >= 0) {
      return HockeyCollisionResult(
          position: position, velocity: velocity, contact: true);
    }
    final normalSpeed = _dot(velocity, normal);
    final paddleSpeed = _dot(paddleVelocity, normal);
    // Only the normal component is transferred; tangential motion adds no
    // energy and separating contacts never generate an impulse.
    final reflectedNormal =
        normalSpeed < 0 ? -normalSpeed * restitution : normalSpeed;
    final result = velocity +
        normal *
            (reflectedNormal -
                normalSpeed +
                paddleSpeed * paddleNormalTransfer);
    return HockeyCollisionResult(
        position: position,
        velocity: limitVelocity(result),
        contact: true,
        struck: true);
  }

  static HockeyCollisionResult resolvePostCollision({
    required Offset puckPosition,
    required Offset puckVelocity,
    required Offset postPosition,
    required double combinedRadius,
  }) =>
      resolvePaddleCollision(
        puckPosition: puckPosition,
        puckVelocity: puckVelocity,
        paddlePosition: postPosition,
        paddleVelocity: Offset.zero,
        combinedRadius: combinedRadius,
      );

  static Offset reflectWall({
    required Offset velocity,
    required Offset normal,
    double restitution = .94,
  }) {
    final current = limitVelocity(velocity);
    if (normal.distance < 1e-8) return current;
    final n = normal / normal.distance;
    final approach = _dot(current, n);
    return approach >= 0
        ? current
        : limitVelocity(
            current - n * ((1 + restitution.clamp(0.0, 1.0)) * approach));
  }

  static double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
}
