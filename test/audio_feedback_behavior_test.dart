import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gameplay does not receive a global pointer click sound', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, isNot(contains('onPointerDown: (_) => GameFeedback.uiTap()')));
  });

  test('football routes haptics through GameFeedback only', () {
    final football = File(
      'lib/games/football/world_class_penalty_game_v2.dart',
    ).readAsStringSync();
    expect(football, isNot(contains('HapticFeedback.')));
  });
}
