import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/core/app_settings.dart';
import 'package:gameslocal/games/air_hockey/air_hockey_game.dart';
import 'package:gameslocal/games/air_hockey/hockey_physics.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder get fieldPaint => find.byWidgetPredicate((widget) =>
    widget is CustomPaint &&
    widget.painter.runtimeType.toString() == '_HockeyPainter');

void expectPaddlesInside(WidgetTester tester) {
  final size = tester.getSize(fieldPaint);
  final dynamic painter = tester.widget<CustomPaint>(fieldPaint).painter;
  final radius = size.width * .065;
  for (final Offset center in [
    painter.top as Offset,
    painter.bottom as Offset
  ]) {
    expect(center.dx * size.width - radius, greaterThanOrEqualTo(-1e-6));
    expect(
        center.dx * size.width + radius, lessThanOrEqualTo(size.width + 1e-6));
    expect(center.dy * size.height - radius, greaterThanOrEqualTo(-1e-6));
    expect(center.dy * size.height + radius,
        lessThanOrEqualTo(size.height + 1e-6));
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(
        {'sound_enabled': false, 'vibration_enabled': false});
    await AppSettingsController.instance.load();
  });
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(640, 320)
  ]) {
    testWidgets(
        'actual hockey field contains complete paddles at $size and scale1.3',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
              data: MediaQueryData(
                  size: size, textScaler: TextScaler.linear(1.3)),
              child: const AirHockeyGameScreen())));
      await tester.pump();
      expectPaddlesInside(tester);
      expect(tester.takeException(), isNull);
      final dynamic state = tester.state(find.byType(AirHockeyGameScreen));
      expect(state.fieldSize, tester.getSize(fieldPaint));
      if (size.width > size.height) {
        expect(tester.getSize(fieldPaint).height, greaterThanOrEqualTo(200));
        expect(tester.getSize(fieldPaint).width, greaterThanOrEqualTo(200));
      }
      await tester.tap(find.text('مع صديق'));
      await tester.pump();
      for (final fraction in [
        const Offset(.001, .001),
        const Offset(.999, .44),
        const Offset(.001, .999),
        const Offset(.999, .999)
      ]) {
        final rect = tester.getRect(fieldPaint);
        final gesture = await tester.startGesture(Offset(
            rect.left + rect.width * fraction.dx,
            rect.top + rect.height * fraction.dy));
        await gesture.up();
        await tester.pump();
        expectPaddlesInside(tester);
      }
      state.puck = Offset(
          state.bottom.dx as double,
          (state.bottom.dy as double) -
              (state.fieldSize.width as double) *
                  .081 /
                  (state.fieldSize.height as double));
      state.velocity = const Offset(0, .2);
      state.bottomContact = false;
      state.lastMicros = 1;
      await tester.pump(const Duration(milliseconds: 20));
      expect((state.velocity as Offset).dy, lessThan(0));
      expect(
          HockeyGeometry.velocityToPixels(
                  state.velocity as Offset, state.fieldSize as Size)
              .distance,
          lessThanOrEqualTo(900 + 1e-6));
      expectPaddlesInside(tester);
      // Include the completed-match layout, where replay used to consume field height.
      state.bottomScore = 4;
      state.puck = const Offset(.5, -.1);
      state.velocity = Offset.zero;
      state.lastMicros = 1;
      await tester.pump(const Duration(milliseconds: 20));
      expect(state.playing, isFalse);
      expectPaddlesInside(tester);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox());
    });
  }
}
