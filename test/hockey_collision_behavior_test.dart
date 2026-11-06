import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/air_hockey/hockey_physics.dart';

void main() {
  HockeyCollisionResult collide({
    Offset position = const Offset(0, 30),
    Offset velocity = const Offset(0, -100),
    Offset paddleVelocity = Offset.zero,
    bool touching = false,
  }) =>
      HockeyPhysics.resolvePaddleCollision(
        puckPosition: position,
        puckVelocity: velocity,
        paddlePosition: Offset.zero,
        paddleVelocity: paddleVelocity,
        combinedRadius: 40,
        wasTouching: touching,
      );
  test(
      'stationary paddle returns 90 percent of normal speed without tangential gain',
      () {
    final hit = collide(velocity: const Offset(60, -100));
    expect(hit.velocity.dx, closeTo(60, 1e-8));
    expect(hit.velocity.dy, closeTo(90, 1e-8));
    expect(hit.position, const Offset(0, 41));
    expect(hit.struck, isTrue);
  });
  test('moving paddle transfers only 65 percent of its normal speed', () {
    final hit = collide(
      velocity: const Offset(60, -100),
      paddleVelocity: const Offset(200, 200),
    );
    expect(hit.velocity.dx, closeTo(60, 1e-8));
    expect(hit.velocity.dy, closeTo(220, 1e-8));
  });
  test('separating and repeated contacts never inject another impulse', () {
    final separating = collide(velocity: const Offset(0, 100));
    expect(separating.velocity, const Offset(0, 100));
    expect(separating.struck, isFalse);
    var hit = collide();
    for (var i = 0; i < 100; i++) {
      hit = collide(
        velocity: hit.velocity,
        paddleVelocity: const Offset(0, 300),
        touching: true,
      );
      expect(hit.velocity, const Offset(0, 90));
      expect(hit.struck, isFalse);
    }
    expect(
      collide(position: const Offset(0, 44), touching: true).contact,
      isFalse,
    );
  });
  test('coincident stationary and moving centers stay finite', () {
    for (final velocity in [Offset.zero, const Offset(100, 200)]) {
      final hit = collide(position: Offset.zero, velocity: velocity);
      expect(hit.position.dx.isFinite && hit.position.dy.isFinite, isTrue);
      expect(hit.velocity.dx.isFinite && hit.velocity.dy.isFinite, isTrue);
      expect(hit.position.distance, closeTo(41, 1e-8));
    }
  });
  test(
    'speed cap applies before integration rather than after displacement',
    () {
      final next = HockeyPhysics.advancePuck(
        position: Offset.zero,
        velocity: const Offset(2000, 0),
        dt: .01,
      );
      expect(next.position, const Offset(9, 0));
      expect(next.velocity.distance, closeTo(900, 1e-8));
      expect(
        HockeyPhysics.limitVelocity(const Offset(double.nan, 0)),
        Offset.zero,
      );
    },
  );
  test('paddle, post and wall paths cap speed at 900 pixels per second', () {
    final paddle = collide(
      velocity: const Offset(100, -700),
      paddleVelocity: const Offset(0, 3000),
    );
    final post = HockeyPhysics.resolvePostCollision(
      puckPosition: const Offset(0, 10),
      puckVelocity: const Offset(2000, -4000),
      postPosition: Offset.zero,
      combinedRadius: 20,
    );
    final wall = HockeyPhysics.reflectWall(
      velocity: const Offset(-2000, 1000),
      normal: const Offset(1, 0),
    );
    for (final velocity in [paddle.velocity, post.velocity, wall]) {
      expect(velocity.distance, lessThanOrEqualTo(900 + 1e-8));
    }
    expect(post.position, const Offset(0, 21));
    expect(post.velocity.dy, greaterThan(0));
    expect(wall.dx, greaterThan(0));
    expect(
      HockeyPhysics.reflectWall(
        velocity: const Offset(100, 0),
        normal: const Offset(1, 0),
      ),
      const Offset(100, 0),
    );
  });
}
