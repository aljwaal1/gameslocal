/// Shared normalized motion for both the Flame and network Canvas arenas.
enum PenaltyMotionPhase {
  approach,
  plant,
  contact,
  followThrough,
  flight,
  landing
}

class PenaltyMotionFrame {
  const PenaltyMotionFrame(
      {required this.phase,
      required this.approach,
      required this.plant,
      required this.contact,
      required this.followThrough,
      required this.ballFlight,
      required this.keeperPush,
      required this.keeperReach,
      required this.keeperLanding});
  final PenaltyMotionPhase phase;
  final double approach, plant, contact, followThrough, ballFlight;
  final double keeperPush, keeperReach, keeperLanding;
}

class PenaltyMotionTimeline {
  const PenaltyMotionTimeline();
  static const plantStart = .22;
  static const approachEnd = .28;
  static const keeperPushStart = .26;
  static const contactStart = .34;
  static const contactEnd = .38;
  static const ballLaunch = contactEnd;
  static const keeperPushEnd = .48;
  static const keeperReachStart = keeperPushEnd;
  static const followThroughEnd = .58;
  static const keeperReachEnd = .84;
  static const ballArrival = .86;
  static const keeperLandingStart = .86;

  PenaltyMotionFrame frame(double progress) {
    final t = progress.isFinite ? progress.clamp(0.0, 1.0).toDouble() : 0.0;
    double interval(double a, double b) =>
        ((t - a) / (b - a)).clamp(0.0, 1.0).toDouble();
    double easeOut(double value) => 1 - (1 - value) * (1 - value) * (1 - value);
    final flight = interval(ballLaunch, ballArrival);
    return PenaltyMotionFrame(
      phase: t < plantStart
          ? PenaltyMotionPhase.approach
          : t < contactStart
              ? PenaltyMotionPhase.plant
              : t < contactEnd
                  ? PenaltyMotionPhase.contact
                  : t < followThroughEnd
                      ? PenaltyMotionPhase.followThrough
                      : t < ballArrival
                          ? PenaltyMotionPhase.flight
                          : PenaltyMotionPhase.landing,
      approach: easeOut(interval(0, approachEnd)),
      plant: interval(plantStart, contactStart),
      contact: interval(contactStart, contactEnd),
      followThrough: interval(contactEnd, followThroughEnd),
      ballFlight: flight * flight,
      keeperPush: interval(keeperPushStart, keeperPushEnd),
      keeperReach: easeOut(interval(keeperReachStart, keeperReachEnd)),
      keeperLanding: interval(keeperLandingStart, 1),
    );
  }
}
