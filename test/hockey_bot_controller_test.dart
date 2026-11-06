import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/core/app_settings.dart';
import 'package:gameslocal/games/air_hockey/hockey_bot_controller.dart';

void main() {
  const field = Size(360, 720);
  final profiles =
      BotDifficulty.values.map(HockeyBotProfile.forDifficulty).toList();
  test(
    'difficulty orders reaction, pixel speed, acceleration and prediction',
    () {
      expect(profiles.map((p) => p.reactionInterval), [.24, .16, .09]);
      for (var i = 1; i < profiles.length; i++) {
        expect(profiles[i].maxSpeed, greaterThan(profiles[i - 1].maxSpeed));
        expect(
          profiles[i].maxAcceleration,
          greaterThan(profiles[i - 1].maxAcceleration),
        );
        expect(
          profiles[i].predictionSeconds,
          greaterThan(profiles[i - 1].predictionSeconds),
        );
        expect(profiles[i].accuracy, greaterThan(profiles[i - 1].accuracy));
      }
    },
  );
  for (final difficulty in BotDifficulty.values) {
    test('$difficulty holds target until its reaction interval', () {
      final bot = HockeyBotController(
        HockeyBotProfile.forDifficulty(difficulty),
      );
      var state = HockeyBotState.initial(const Offset(180, 115));
      state = bot.step(
        state: state,
        puckPosition: const Offset(50, 250),
        puckVelocity: const Offset(100, -100),
        field: field,
        dt: .01,
      );
      final target = state.target;
      final decisions = state.decisionCount;
      var elapsed = .01;
      while (elapsed + .01 < bot.profile.reactionInterval) {
        state = bot.step(
          state: state,
          puckPosition: const Offset(310, 200),
          puckVelocity: const Offset(-100, -100),
          field: field,
          dt: .01,
        );
        expect(state.target, target);
        expect(state.decisionCount, decisions);
        elapsed += .01;
      }
      for (var i = 0; i < 3; i++) {
        state = bot.step(
          state: state,
          puckPosition: const Offset(310, 200),
          puckVelocity: const Offset(-100, -100),
          field: field,
          dt: .01,
        );
      }
      expect(state.decisionCount, greaterThan(decisions));
    });
    test('$difficulty never exceeds pixel speed or acceleration', () {
      final bot = HockeyBotController(
        HockeyBotProfile.forDifficulty(difficulty),
      );
      var state = HockeyBotState.initial(const Offset(180, 115));
      for (var i = 0; i < 3000; i++) {
        final previous = state;
        state = bot.step(
          state: state,
          puckPosition: Offset(
            i % 240 < 120 ? 40 : 320,
            i % 300 < 150 ? 100 : 600,
          ),
          puckVelocity: const Offset(60, -80),
          field: field,
          dt: .016,
        );
        expect(
          state.velocity.distance,
          lessThanOrEqualTo(bot.profile.maxSpeed + 1e-7),
        );
        expect(
          (state.velocity - previous.velocity).distance,
          lessThanOrEqualTo(bot.profile.maxAcceleration * .016 + 1e-7),
        );
        expect(state.position.dx, inInclusiveRange(36, 324));
        expect(state.position.dy, inInclusiveRange(57.6, 309.6));
      }
    });
  }
  test('a distant puck returns the robot to a natural defensive position', () {
    final bot = HockeyBotController(
      HockeyBotProfile.forDifficulty(BotDifficulty.normal),
    );
    var state = HockeyBotState.initial(const Offset(60, 260));
    for (var i = 0; i < 600; i++) {
      state = bot.step(
        state: state,
        puckPosition: const Offset(320, 600),
        puckVelocity: Offset.zero,
        field: field,
        dt: .016,
      );
      expect(state.attacking, isFalse);
    }
    expect((state.position - const Offset(180, 115.2)).distance, lessThan(1));
  });
  test('attack requires a slow reachable puck inside the attacking half', () {
    final bot = HockeyBotController(
      HockeyBotProfile.forDifficulty(BotDifficulty.normal),
    );
    HockeyBotState decide(Offset puck, Offset velocity) => bot.step(
          state: HockeyBotState.initial(const Offset(180, 115)),
          puckPosition: puck,
          puckVelocity: velocity,
          field: field,
          dt: .016,
        );
    expect(
      decide(const Offset(180, 180), const Offset(30, 20)).attacking,
      isTrue,
    );
    expect(
      decide(const Offset(180, 180), const Offset(800, 0)).attacking,
      isFalse,
    );
    expect(decide(const Offset(320, 300), Offset.zero).attacking, isFalse);
    expect(decide(const Offset(180, 500), Offset.zero).attacking, isFalse);
  });
  test('pixel acceleration is independent of field dimensions', () {
    final bot = HockeyBotController(
      HockeyBotProfile.forDifficulty(BotDifficulty.hard),
    );
    HockeyBotState decide(Size size) => bot.step(
          state: HockeyBotState.initial(
            Offset(size.width * .5 - 40, size.height * .16 + 20),
          ),
          puckPosition: Offset(size.width * .5, size.height * .8),
          puckVelocity: Offset.zero,
          field: size,
          dt: .016,
        );
    final a = decide(field), b = decide(const Size(720, 1440));
    expect((a.velocity - b.velocity).distance, lessThan(1e-8));
  });
  test(
    'prediction reflects approaching trajectories with difficulty accuracy',
    () {
      final easy = HockeyBotController(profiles.first),
          hard = HockeyBotController(profiles.last);
      final initial = HockeyBotState.initial(const Offset(180, 115));
      final e = easy.step(
        state: initial,
        puckPosition: const Offset(100, 400),
        puckVelocity: const Offset(200, -400),
        field: field,
        dt: .016,
      );
      final h = hard.step(
        state: initial,
        puckPosition: const Offset(100, 400),
        puckVelocity: const Offset(200, -400),
        field: field,
        dt: .016,
      );
      expect(h.target.dx, greaterThan(e.target.dx));
    },
  );
  test(
    'invalid time does nothing and large time advances at most one safe step',
    () {
      final bot = HockeyBotController(profiles.last);
      final state = HockeyBotState.initial(const Offset(180, 115));
      for (final dt in [0.0, -1.0, double.nan, double.infinity]) {
        expect(
          identical(
            bot.step(
              state: state,
              puckPosition: const Offset(50, 200),
              puckVelocity: Offset.zero,
              field: field,
              dt: dt,
            ),
            state,
          ),
          isTrue,
        );
      }
      final a = bot.step(
        state: state,
        puckPosition: const Offset(50, 200),
        puckVelocity: Offset.zero,
        field: field,
        dt: 100,
      );
      final b = bot.step(
        state: state,
        puckPosition: const Offset(50, 200),
        puckVelocity: Offset.zero,
        field: field,
        dt: .034,
      );
      expect(a.position, b.position);
      expect(a.velocity, b.velocity);
      final reset = HockeyBotState.initial(a.position);
      expect(reset.velocity, Offset.zero);
      expect(reset.decisionCount, 0);
      expect(reset.timeUntilDecision, 0);
    },
  );
  test(
      'reflected prediction uses puck walls rather than paddle movement limits',
      () {
    final bot = HockeyBotController(profiles.last);
    final result = bot.step(
        state: HockeyBotState.initial(const Offset(180, 115)),
        puckPosition: const Offset(330, 400),
        puckVelocity: const Offset(300, -600),
        field: field,
        dt: .016);
    // x=456 crosses the actual right puck wall at344.88, not paddle limit324.
    expect(result.target.dx, closeTo(233.76, 1.5));
  });
  test(
      'actual movement matches reported velocity and remains acceleration bounded near edges',
      () {
    for (final difficulty in BotDifficulty.values) {
      final bot =
          HockeyBotController(HockeyBotProfile.forDifficulty(difficulty));
      for (final size in [const Size(320, 640), const Size(640, 320)]) {
        final random = math.Random(42);
        var state =
            HockeyBotState.initial(Offset(size.width * .5, size.height * .16));
        var previousActual = Offset.zero;
        for (var i = 0; i < 12000; i++) {
          final old = state;
          state = bot.step(
              state: state,
              puckPosition: Offset(random.nextDouble() * size.width,
                  random.nextDouble() * size.height * .65),
              puckVelocity: Offset(random.nextDouble() * 400 - 200,
                  random.nextDouble() * 400 - 200),
              field: size,
              dt: .034);
          final actual = (state.position - old.position) / .034;
          expect((actual - state.velocity).distance, lessThan(1e-6),
              reason: '$difficulty $size frame$i');
          expect((actual - previousActual).distance,
              lessThanOrEqualTo(bot.profile.maxAcceleration * .034 + 1e-6),
              reason: '$difficulty $size frame$i');
          previousActual = actual;
        }
      }
    }
  });
}
