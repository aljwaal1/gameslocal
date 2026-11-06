import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/core/app_settings.dart';
import 'package:gameslocal/games/retro_road/retro_road_game.dart';
import 'road_screen_behavior_test.dart' show RoadTestCore, roadField;

void main() {
  testWidgets(
      'integrated road raster stays readable all weather and required viewports',
      (tester) async {
    AppSettingsController.instance.soundEnabled = false;
    AppSettingsController.instance.vibrationEnabled = false;
    if (const bool.fromEnvironment('ROAD_CAPTURE')) {
      await tester.runAsync(() async {
        for (final font in {
          'RoadReviewFont': '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
          'MaterialIcons':
              '../runtime/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
        }.entries) {
          final data = File(font.value).readAsBytesSync();
          await (FontLoader(font.key)
                ..addFont(Future.value(ByteData.sublistView(data))))
              .load();
        }
      });
    }
    final core = RoadTestCore();
    addTearDown(core.dispose);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const weatherNames = ['day', 'sunset', 'night', 'fog', 'snow', 'rain'];
    const key = ValueKey('road-review-capture');
    for (final size in [
      const Size(320, 640),
      const Size(390, 844),
      const Size(640, 320)
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(fontFamily: 'RoadReviewFont', useMaterial3: true),
          home: RepaintBoundary(
              key: key,
              child: MediaQuery(
                  data: MediaQueryData(
                      size: size, textScaler: TextScaler.linear(1.3)),
                  child: RetroRoadGameScreen(networkCore: core)))));
      for (var weather = 0; weather < 6; weather++) {
        core.receive(weather: weather);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
        expect(roadField(), findsOneWidget);
        await tester.runAsync(() async {
          final boundary =
              tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
          final image = await boundary.toImage(pixelRatio: 1);
          final rgba =
              (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          final area = tester.getRect(roadField());
          final player =
              area.topLeft + Offset(area.width * .5, area.height * .82);
          final index =
              (player.dy.floor() * size.width.toInt() + player.dx.floor()) * 4;
          expect(
              rgba.getUint8(index + 2) - rgba.getUint8(index), greaterThan(90),
              reason:
                  'local car rendered at actual collision center in ${weatherNames[weather]} at $size');
          if (const bool.fromEnvironment('ROAD_CAPTURE')) {
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
                '../verification/road/road-${size.width.toInt()}x${size.height.toInt()}-${weatherNames[weather]}.png');
            file.parent.createSync(recursive: true);
            file.writeAsBytesSync(bytes!.buffer.asUint8List());
          }
          image.dispose();
        });
      }
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
