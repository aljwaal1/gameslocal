import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/core/app_settings.dart';
import 'package:gameslocal/games/football/penalty_actor_painter.dart';
import 'package:gameslocal/games/football/world_class_penalty_game_v2.dart';

void main() {
  setUp(() {
    AppSettingsController.instance.soundEnabled = false;
    AppSettingsController.instance.vibrationEnabled = false;
  });
  testWidgets(
      'live rotation preserves the same game element and match progress both ways',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester
        .pumpWidget(const MaterialApp(home: ProPenaltyShootoutGameScreen()));
    await tester.pump();
    final field = find.byType(GameWidget<CinematicPenaltyGame>);
    for (var i = 0;
        i < 100 &&
            !(tester.widget(field) as GameWidget<CinematicPenaltyGame>)
                .game!
                .isAttached;
        i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(
        (tester.widget(field) as GameWidget<CinematicPenaltyGame>)
            .game!
            .isAttached,
        isTrue);
    final element = tester.state(field);
    final game =
        (tester.widget(field) as GameWidget<CinematicPenaltyGame>).game!;
    game.shoot(aim: const Offset(.4, .4), power: .8, curve: 0);
    game.update(game.shotDuration * .4);
    tester.view.physicalSize = const Size(640, 320);
    await tester.pump();
    expect(identical(tester.state(field), element), isTrue);
    game.update(game.shotDuration * .5);
    expect(game.playerShots, 1);
    game.update(1.3);
    expect(game.canDive, isTrue);
    game.chooseDive(const Offset(.3, .4));
    game.update(game.shotDuration * .9);
    game.update(1.3);
    expect(game.robotShots, 1);
    expect(game.canShoot, isTrue);
    tester.view.physicalSize = const Size(320, 640);
    await tester.pump();
    expect(identical(tester.state(field), element), isTrue);
    expect(game.canShoot, isTrue);
    final area = tester.getRect(field);
    final gesture = await tester.startGesture(area.center);
    await gesture.moveBy(const Offset(25, -60));
    await gesture.up();
    await tester.pump();
    expect(game.phase, PenaltyPhase.flying);
    game.update(game.shotDuration * .9);
    expect(game.playerShots, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final releaseBeforeResume in [false, true]) {
    testWidgets(
        'lifecycle pause discards old local pointer; release before resume=$releaseBeforeResume',
        (tester) async {
      await tester
          .pumpWidget(const MaterialApp(home: ProPenaltyShootoutGameScreen()));
      await tester.pump();
      final field = find.byType(GameWidget<CinematicPenaltyGame>);
      for (var i = 0;
          i < 100 &&
              !(tester.widget(field) as GameWidget<CinematicPenaltyGame>)
                  .game!
                  .isAttached;
          i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump();
      }
      expect(
          (tester.widget(field) as GameWidget<CinematicPenaltyGame>)
              .game!
              .isAttached,
          isTrue);
      final game =
          (tester.widget(field) as GameWidget<CinematicPenaltyGame>).game!;
      final area = tester.getRect(field);
      final gesture = await tester.startGesture(area.center);
      await gesture.moveBy(const Offset(25, -60));
      final actualBefore = game.actualAim;
      final outcomeBefore = game.outcome;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(game.paused, isTrue);
      expect(game.canShoot, isFalse);
      if (releaseBeforeResume) {
        await gesture.up();
        await tester.pump();
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(game.paused, isFalse);
      if (!releaseBeforeResume) {
        await gesture.up();
        await tester.pump();
      }
      expect(game.phase, PenaltyPhase.aiming);
      expect(game.playerShots, 0);
      expect(game.actualAim, actualBefore);
      expect(game.outcome, outcomeBefore);
      final fresh = await tester.startGesture(area.center);
      await fresh.moveBy(const Offset(-35, -65));
      await fresh.up();
      await tester.pump();
      expect(game.phase, PenaltyPhase.flying);
      game.update(game.shotDuration * .9);
      expect(game.playerShots, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
      'restart and removing the actual game widget cancel an active shot safely',
      (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: ProPenaltyShootoutGameScreen()));
    await tester.pump();
    CinematicPenaltyGame current() =>
        (tester.widget(find.byType(GameWidget<CinematicPenaltyGame>))
                as GameWidget<CinematicPenaltyGame>)
            .game!;
    final old = current();
    old.shoot(aim: const Offset(.4, .4), power: .8, curve: 0);
    old.update(old.shotDuration * .35);
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump();
    final fresh = current();
    expect(identical(old, fresh), isFalse);
    old.update(2);
    expect(old.playerShots, 0);
    fresh.shoot(aim: const Offset(.6, .3), power: .7, curve: 0);
    await tester.pumpWidget(const SizedBox());
    fresh.update(2);
    expect(fresh.playerShots, 0);
    expect(tester.takeException(), isNull);
  });
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(640, 320),
    const Size(844, 390)
  ]) {
    testWidgets(
        'actors stay visible above instruction card $size at text scale 1.3',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
              data: MediaQueryData(
                  size: size, textScaler: TextScaler.linear(1.3)),
              child: const ProPenaltyShootoutGameScreen())));
      await tester.pump();
      final field = find.byType(GameWidget<CinematicPenaltyGame>);
      final game =
          (tester.widget(field) as GameWidget<CinematicPenaltyGame>).game!;
      final fieldRect = tester.getRect(field);
      if (size.width > size.height) {
        expect(fieldRect.height, greaterThanOrEqualTo(size.height * .6),
            reason:
                'landscape must keep enough vertical space to read full actors');
      }
      final hint = tester.getRect(find
          .byWidgetPredicate((w) => w.runtimeType.toString() == '_HintCard'));
      final goal = Rect.fromLTRB(fieldRect.width * .15, fieldRect.height * .14,
          fieldRect.width * .85, fieldRect.height * .43);
      for (final time in [0.0, .28, .34, .38, .58, .86, 1.0]) {
        game.phase = PenaltyPhase.flying;
        game.flight = time;
        final layout = PenaltyActorLayout(
            size: fieldRect.size,
            goal: goal,
            keeperTarget: const Offset(.9, .8),
            frame: game.motion);
        expect(
            layout.playerRect.shift(fieldRect.topLeft).overlaps(hint), isFalse,
            reason: 'instruction HUD must not hide the full player body');
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
