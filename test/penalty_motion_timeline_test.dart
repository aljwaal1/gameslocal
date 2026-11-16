import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/football/penalty_motion_timeline.dart';

void main() {
  test('contact and arrival bound the flight while the actors keep moving', () {
    const timeline = PenaltyMotionTimeline();
    expect(timeline.frame(.22).plant, 0);
    expect(timeline.frame(.28).approach, 1);
    expect(timeline.frame(.339).contact, 0);
    expect(timeline.frame(.36).contact, closeTo(.5, .0001));
    expect(timeline.frame(.38).contact, 1);
    for (final time in [0.0, .26, .34, .379999, .38]) {
      expect(timeline.frame(time).ballFlight, 0);
    }
    expect(timeline.frame(.39).ballFlight, greaterThan(0));
    expect(timeline.frame(.86).ballFlight, 1);
    expect(timeline.frame(.48).keeperPush, 1);
    expect(timeline.frame(.48).keeperReach, 0);
    expect(timeline.frame(.84).keeperReach, 1);
    expect(timeline.frame(.86).keeperLanding, 0);
    expect(timeline.frame(1).keeperLanding, 1);
    expect(timeline.frame(.39).followThrough,
        lessThan(timeline.frame(.58).followThrough));
    final earlyDistance =
        timeline.frame(.08).approach - timeline.frame(.04).approach;
    final lateDistance =
        timeline.frame(.26).approach - timeline.frame(.22).approach;
    expect(earlyDistance, greaterThan(lateDistance));
    expect(timeline.frame(-1).ballFlight, 0);
    expect(timeline.frame(2).keeperLanding, 1);
    expect(timeline.frame(double.nan).approach.isFinite, isTrue);
  });
}
