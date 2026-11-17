import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/fuel_plane/plane_scene_painter.dart';
import 'package:gameslocal/games/fuel_plane/plane_stage_scenery.dart';

void main() {
  testWidgets('five stages draw distinct backgrounds and repaint on change',
      (tester) async {
    final backgrounds = <int>{};
    PlaneScenePainter? previous;
    for (var stage = 1; stage <= 5; stage++) {
      final painter = PlaneScenePainter(
        localX: .5,
        localAlive: false,
        distance: 120,
        obstacles: const [],
        projectiles: const [],
        scenery: PlaneStageScenery.forStage(stage),
      );
      if (previous != null) expect(painter.shouldRepaint(previous), isTrue);
      previous = painter;
      final recording = ui.PictureRecorder();
      painter.paint(ui.Canvas(recording), const ui.Size(180, 320));
      final picture = recording.endRecording();
      await tester.runAsync(() async {
        final image = await picture.toImage(180, 320);
        try {
          final bytes = (await image.toByteData())!;
          backgrounds.add(bytes.getUint32((160 * 180 + 90) * 4));
        } finally {
          image.dispose();
        }
      });
      picture.dispose();
    }
    expect(backgrounds, hasLength(5));
    expect(PlaneStageScenery.forStage(6), PlaneStageScenery.river);
  });
}
