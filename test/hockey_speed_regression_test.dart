import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/core/app_settings.dart';
import 'package:gameslocal/games/air_hockey/air_hockey_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'the live field caps pixel speed even before any paddle contact',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'sound_enabled': false,
        'vibration_enabled': false,
      });
      await AppSettingsController.instance.load();
      await tester.pumpWidget(const MaterialApp(home: AirHockeyGameScreen()));
      final dynamic state = tester.state(find.byType(AirHockeyGameScreen));
      state.botMode = false;
      state.puck = const Offset(.5, .5);
      state.velocity = const Offset(10, 10);
      state.lastMicros = 1;
      await tester.pump(const Duration(milliseconds: 20));
      final Size field = state.fieldSize;
      final Offset velocity = state.velocity;
      expect(
        Offset(velocity.dx * field.width, velocity.dy * field.height).distance,
        lessThanOrEqualTo(900 + .000001),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
