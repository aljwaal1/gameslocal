import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/arcade/arcade_timing.dart';

void main() {
  test('thirty and sixty hertz advance equal simulation time', () {
    final at30 = List<double>.filled(30, 1 / 30)
        .fold<double>(0, (sum, dt) => sum + ArcadeTiming.tickScale(dt));
    final at60 = List<double>.filled(60, 1 / 60)
        .fold<double>(0, (sum, dt) => sum + ArcadeTiming.tickScale(dt));
    expect(at30, closeTo(at60, .001));
  });

  test('spawn chance scales with elapsed time', () {
    final oneLongFrame = ArcadeTiming.scaledProbability(.02, 2);
    final twoFrames = 1 - (1 - .02) * (1 - .02);
    expect(oneLongFrame, closeTo(twoFrames, .000001));
  });
}
