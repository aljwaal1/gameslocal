import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/fuel_plane/fuel_plane_game.dart';

void main() {
  testWidgets('landscape lobby and flight view share usable space at 1.3 text',
      (tester) async {
    const size = Size(640, 320);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
            size: size, textScaler: TextScaler.linear(1.3)),
        child: const FuelPlaneGameScreen(),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('ابدأ').hitTestable(), findsOneWidget);
    await tester.tap(find.text('ابدأ'));
    await tester.pump();
    final slider = tester.getRect(find.byType(Slider));
    final field = tester.getRect(find.byKey(const ValueKey('plane-scene')));
    expect(field.height, greaterThan(140));
    expect(slider.left, greaterThanOrEqualTo(field.right));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
