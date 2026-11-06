import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/retro_road/road_scene_geometry.dart';
import 'package:gameslocal/games/retro_road/road_scene_painter.dart';

void main() {
  for (final size in [
    const Size(300, 480),
    const Size(370, 684),
    const Size(620, 172)
  ]) {
    testWidgets(
        'vector cars retain visible contact centers every weather $size',
        (tester) async {
      for (final weather in RoadSceneWeather.values) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        RoadScenePainter(
                playerX: .5,
                opponentX: .72,
                traffic: const [
                  RoadTrafficVisual(.28, .82, 1),
                  RoadTrafficVisual(.64, .46, 3)
                ],
                weather: weather,
                travel: 300)
            .paint(canvas, size);
        final picture = recorder.endRecording();
        await tester.runAsync(() async {
          final image =
              await picture.toImage(size.width.toInt(), size.height.toInt());
          final bytes =
              (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          final g = RoadSceneGeometry(size);
          List<int> pixel(double x) {
            final p = g.project(x, RoadSceneGeometry.playerY);
            final index =
                (p.dy.floor() * size.width.toInt() + p.dx.floor()) * 4;
            return List.generate(4, (i) => bytes.getUint8(index + i));
          }

          final local = pixel(.5), remote = pixel(.72), traffic = pixel(.28);
          expect(local[2] - local[0], greaterThan(90),
              reason: 'cyan local car visible at collision center in $weather');
          expect(local[1] - local[0], greaterThan(70));
          expect(remote[0] - remote[2], greaterThan(90),
              reason: 'orange peer remains distinct in $weather');
          expect(traffic[0], greaterThan(180),
              reason: 'yellow traffic remains readable in $weather');
          expect(traffic[1], greaterThan(150));
          expect(local[3], 255);
          image.dispose();
        });
        picture.dispose();
      }
    });
  }
}
