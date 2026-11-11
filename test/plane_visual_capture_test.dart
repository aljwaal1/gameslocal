import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/core/app_settings.dart';
import 'package:gameslocal/games/fuel_plane/fuel_plane_game.dart';

import 'plane_screen_behavior_test.dart' show PlaneTestCore, scene;

void main() {
  testWidgets('live screen renders aircraft and low fuel together',
      (tester) async {
    AppSettingsController.instance.soundEnabled = false;
    AppSettingsController.instance.vibrationEnabled = false;
    const capture = bool.fromEnvironment('PLANE_CAPTURE');
    if (capture) {
      await tester.runAsync(() async {
        for (final font in {
          'PlaneReviewFont': '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
          'MaterialIcons':
              '../runtime/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        }.entries) {
          final bytes = await File(font.value).readAsBytes();
          await (FontLoader(font.key)
                ..addFont(Future.value(ByteData.sublistView(bytes))))
              .load();
        }
      });
    }

    final core = PlaneTestCore();
    addTearDown(core.dispose);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const key = ValueKey('plane-review-capture');
    for (final size in [
      const Size(320, 640),
      const Size(390, 844),
      const Size(640, 320),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: capture ? 'PlaneReviewFont' : null),
        home: RepaintBoundary(
          key: key,
          child: MediaQuery(
            data:
                MediaQueryData(size: size, textScaler: TextScaler.linear(1.3)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: FuelPlaneGameScreen(networkCore: core),
            ),
          ),
        ),
      ));
      core.snapshot({
        'remoteX': .36,
        'distance': 120,
        'objects': [
          {'x': .44, 'y': .40, 'type': 0, 'size': .052},
          {'x': .63, 'y': .24, 'type': 2, 'size': .066},
          {'x': .75, 'y': .56, 'type': 1, 'size': .066},
        ],
        'bullets': [
          {'x': .36, 'y': .57, 'remote': true},
          {'x': .72, 'y': .62, 'remote': false},
        ],
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(find.text('وقود منخفض').hitTestable(), findsOneWidget);
      expect(find.byType(Slider).hitTestable(), findsOneWidget);

      await tester.runAsync(() async {
        final boundary =
            tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
        final image = await boundary.toImage(pixelRatio: 1);
        final pixels =
            (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        final field = tester.getRect(scene);
        final center =
            field.topLeft + Offset(field.width * .36, field.height * .82);
        final width = size.width.toInt();
        final index = (center.dy.round() * width + center.dx.round()) * 4;
        expect(pixels.getUint8(index + 2) - pixels.getUint8(index),
            greaterThan(50));
        if (capture) {
          final bytes =
              (await image.toByteData(format: ui.ImageByteFormat.png))!;
          final name = 'plane-${width}x${size.height.toInt()}.png';
          final file = File('../verification/plane/$name');
          file.parent.createSync(recursive: true);
          file.writeAsBytesSync(bytes.buffer.asUint8List());
        }
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
