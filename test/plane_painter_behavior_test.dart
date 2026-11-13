import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/fuel_plane/plane_scene_geometry.dart';
import 'package:gameslocal/games/fuel_plane/plane_scene_painter.dart';

void main() {
  for (final size in [
    const Size(296, 446),
    const Size(366, 650),
    const Size(446, 248),
  ]) {
    testWidgets('aerial canvas and distinct aircraft render at $size',
        (tester) async {
      final geometry = PlaneSceneGeometry(size);
      final recorder = ui.PictureRecorder();
      final painter = PlaneScenePainter(
        localX: .3,
        remoteX: .7,
        distance: 120,
        obstacles: const [
          PlaneObstacle(.4, .42, .052, PlaneObstacleKind.fuel),
          PlaneObstacle(.62, .28, .066, PlaneObstacleKind.enemy),
          PlaneObstacle(.78, .56, .066, PlaneObstacleKind.rock),
        ],
        projectiles: const [
          PlaneProjectile(.3, .56),
          PlaneProjectile(.7, .62, remote: true),
        ],
      );
      painter.paint(Canvas(recorder), size);
      final picture = recorder.endRecording();
      await tester.runAsync(() async {
        final width = size.width.toInt();
        final height = size.height.toInt();
        final image = await picture.toImage(width, height);
        final pixels =
            (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        List<int> color(int x, int y) {
          final index = (y * width + x) * 4;
          return List.generate(4, (i) => pixels.getUint8(index + i));
        }

        bool hasColor(
            Offset point, int radius, bool Function(List<int>) match) {
          final x = point.dx.round(), y = point.dy.round();
          for (var dy = -radius; dy <= radius; dy++) {
            for (var dx = -radius; dx <= radius; dx++) {
              if (match(color(x + dx, y + dy))) return true;
            }
          }
          return false;
        }

        expect(
          hasColor(geometry.project(.3, .82), 9,
              (p) => p[1] > 160 && p[2] > 180 && p[2] - p[0] > 80),
          isTrue,
          reason: 'local cyan aircraft finish',
        );
        expect(
          hasColor(geometry.project(.7, .82), 9,
              (p) => p[0] > 220 && p[1] > 125 && p[0] - p[2] > 90),
          isTrue,
          reason: 'remote amber aircraft finish',
        );
        expect(
          hasColor(geometry.project(.4, .42), 9,
              (p) => p[1] > 180 && p[1] - p[0] > 85 && p[1] - p[2] > 45),
          isTrue,
          reason: 'green fuel pickup',
        );
        expect(
          hasColor(geometry.project(.62, .28), 9,
              (p) => p[0] > 180 && p[0] - p[1] > 85),
          isTrue,
          reason: 'crimson enemy plane',
        );
        expect(
          hasColor(geometry.project(.78, .56), 8,
              (p) => p[0] > 120 && (p[0] - p[1]).abs() < 30),
          isTrue,
          reason: 'stone-colored rock',
        );

        var water = 0;
        var land = 0;
        for (var y = 5; y < height; y += 7) {
          for (var x = 5; x < width; x += 7) {
            final p = color(x, y);
            expect(p[3], 255);
            if (p[2] > p[0] + 35 && p[1] > p[0] + 35) water++;
            if (p[1] > p[2] + 23 && p[1] > p[0] + 12) land++;
          }
        }
        expect(water, greaterThan(width * height * .008));
        expect(land, greaterThan(width * height * .0006));
        image.dispose();
      });
      picture.dispose();
    });
  }
}
