import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/app_settings.dart';

/// All motion limits are logical pixels per second (or per second squared).
class HockeyBotProfile {
  const HockeyBotProfile({
    required this.reactionInterval,
    required this.maxSpeed,
    required this.maxAcceleration,
    required this.predictionSeconds,
    required this.accuracy,
    required this.attackSpeedLimit,
    required this.attackReachSeconds,
  });

  factory HockeyBotProfile.forDifficulty(BotDifficulty difficulty) =>
      switch (difficulty) {
        BotDifficulty.easy => const HockeyBotProfile(
            reactionInterval: .24,
            maxSpeed: 220,
            maxAcceleration: 700,
            predictionSeconds: .12,
            accuracy: .55,
            attackSpeedLimit: 230,
            attackReachSeconds: .34),
        BotDifficulty.normal => const HockeyBotProfile(
            reactionInterval: .16,
            maxSpeed: 300,
            maxAcceleration: 1000,
            predictionSeconds: .25,
            accuracy: .78,
            attackSpeedLimit: 320,
            attackReachSeconds: .38),
        BotDifficulty.hard => const HockeyBotProfile(
            reactionInterval: .09,
            maxSpeed: 380,
            maxAcceleration: 1400,
            predictionSeconds: .42,
            accuracy: .96,
            attackSpeedLimit: 410,
            attackReachSeconds: .42),
      };

  final double reactionInterval;
  final double maxSpeed;
  final double maxAcceleration;
  final double predictionSeconds;
  final double accuracy;
  final double attackSpeedLimit;
  final double attackReachSeconds;
}

class HockeyBotState {
  const HockeyBotState({
    required this.position,
    required this.velocity,
    required this.target,
    this.timeUntilDecision = 0,
    this.decisionCount = 0,
    this.attacking = false,
  });

  factory HockeyBotState.initial(Offset position) => HockeyBotState(
        position: position,
        velocity: Offset.zero,
        target: position,
      );

  final Offset position;
  final Offset velocity;
  final Offset target;
  final double timeUntilDecision;
  final int decisionCount;
  final bool attacking;

  HockeyBotState copyWith({
    Offset? position,
    Offset? velocity,
    Offset? target,
    double? timeUntilDecision,
    int? decisionCount,
    bool? attacking,
  }) =>
      HockeyBotState(
        position: position ?? this.position,
        velocity: velocity ?? this.velocity,
        target: target ?? this.target,
        timeUntilDecision: timeUntilDecision ?? this.timeUntilDecision,
        decisionCount: decisionCount ?? this.decisionCount,
        attacking: attacking ?? this.attacking,
      );
}

/// Deterministic steering with sampled decisions rather than frame-perfect aim.
class HockeyBotController {
  const HockeyBotController(this.profile);

  final HockeyBotProfile profile;

  HockeyBotState step({
    required HockeyBotState state,
    required Offset puckPosition,
    required Offset puckVelocity,
    required Size field,
    required double dt,
  }) {
    if (!dt.isFinite ||
        dt <= 0 ||
        !field.width.isFinite ||
        !field.height.isFinite ||
        field.width <= 0 ||
        field.height <= 0 ||
        !_finite(puckPosition) ||
        !_finite(puckVelocity)) {
      return state;
    }
    final elapsed = math.min(dt, .034);
    final bounds = Rect.fromLTRB(field.width * .10, field.height * .08,
        field.width * .90, field.height * .43);
    final defense = Offset(field.width * .5, field.height * .16);
    var target = state.target;
    var attacking = state.attacking;
    var decisions = state.decisionCount;
    var remaining = state.timeUntilDecision - elapsed;
    if (remaining <= 1e-10) {
      remaining = profile.reactionInterval;
      decisions++;
      final speed = puckVelocity.distance;
      final nearby = speed < 15 ||
          (puckPosition - state.position).distance <=
              profile.maxSpeed * profile.attackReachSeconds;
      attacking = puckPosition.dy >= bounds.top &&
          puckPosition.dy <= bounds.bottom &&
          nearby &&
          speed <= profile.attackSpeedLimit;
      if (puckPosition.dy > field.height * .64) {
        target = defense;
      } else {
        final travel = puckVelocity.dy < -1
            ? ((defense.dy - puckPosition.dy) / puckVelocity.dy)
                .clamp(0.0, profile.predictionSeconds)
                .toDouble()
            : profile.predictionSeconds * .35;
        final predicted = puckPosition.dx + puckVelocity.dx * travel;
        final error =
            math.sin(puckPosition.dx * .013 + puckPosition.dy * .009) *
                (1 - profile.accuracy) *
                36;
        final x =
            _reflected(predicted, field.width * .042, field.width * .958) +
                error;
        // Stay behind the puck so an attack sends it towards the lower goal.
        target = Offset(x, attacking ? puckPosition.dy - 12 : defense.dy);
      }
      target = Offset(target.dx.clamp(bounds.left, bounds.right),
          target.dy.clamp(bounds.top, bounds.bottom));
    }

    final delta = target - state.position;
    // A proportional arrival speed brakes before reaching the target. The
    // acceleration bound still applies when the next decision reverses course.
    final desired = _limit(delta * 3.5, profile.maxSpeed);
    final change =
        _limit(desired - state.velocity, profile.maxAcceleration * elapsed);
    final velocity = _limit(state.velocity + change, profile.maxSpeed);
    final next = state.position + velocity * elapsed;
    return HockeyBotState(
      position: Offset(next.dx.clamp(bounds.left, bounds.right),
          next.dy.clamp(bounds.top, bounds.bottom)),
      velocity: velocity,
      target: target,
      timeUntilDecision: remaining,
      decisionCount: decisions,
      attacking: attacking,
    );
  }

  static bool _finite(Offset value) => value.dx.isFinite && value.dy.isFinite;
  static Offset _limit(Offset value, double maximum) =>
      value.distance > maximum ? value / value.distance * maximum : value;

  static double _reflected(double x, double left, double right) {
    final span = right - left;
    final phase = (x - left) % (span * 2);
    return left + (phase <= span ? phase : span * 2 - phase);
  }
}
