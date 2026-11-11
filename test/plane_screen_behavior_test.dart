import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/core/app_settings.dart';
import 'package:gameslocal/core/network/local_network_core.dart';
import 'package:gameslocal/core/network/network_message.dart';
import 'package:gameslocal/games/fuel_plane/fuel_plane_game.dart';
import 'package:gameslocal/games/fuel_plane/plane_scene_painter.dart';

class PlaneTestCore extends LocalNetworkCore {
  PlaneTestCore({
    this.mode = LocalNetworkMode.client,
    this.kind = NetworkConnectionKind.local,
  }) : super(gameId: 'fuel_plane');

  LocalNetworkMode mode;
  final NetworkConnectionKind kind;
  final incoming = StreamController<NetworkMessage>.broadcast();
  final sent = <Map<String, dynamic>>[];

  @override
  LocalNetworkState get state => LocalNetworkState(
        mode: mode,
        status: LocalNetworkStatus.connected,
        players: const [],
        connectionKind: kind,
      );

  @override
  Stream<NetworkMessage> get messages => incoming.stream;

  @override
  void sendMove(Map<String, dynamic> payload, {required String senderId}) =>
      sent.add(payload);

  void receive(Map<String, dynamic> payload) => incoming.add(NetworkMessage(
        type: NetworkMessageType.move,
        gameId: gameId,
        senderId: 'peer',
        payload: payload,
      ));

  void snapshot([Map<String, dynamic> overrides = const {}]) => receive({
        'action': 'plane_state',
        'mode': 0,
        'planeX': .72,
        'remoteX': .5,
        'fuel': 94,
        'remoteFuel': 21,
        'score': 81,
        'remoteScore': 99,
        'distance': 1500,
        'level': 2,
        'running': true,
        'gameOver': false,
        'alive': true,
        'remoteAlive': true,
        'resultText': '',
        'objects': [],
        'bullets': [],
        ...overrides,
      });

  @override
  void dispose() {
    incoming.close();
    super.dispose();
  }
}

Finder get scene => find.byKey(const ValueKey('plane-scene'));
Finder get lowFuel => find.text('وقود منخفض');

PlaneScenePainter painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(scene).painter! as PlaneScenePainter;

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() {
    AppSettingsController.instance.soundEnabled = false;
    AppSettingsController.instance.vibrationEnabled = false;
  });

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(640, 320),
  ]) {
    testWidgets('lobby, live low-fuel HUD and controls fit $size at 1.3',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final core = PlaneTestCore();
      addTearDown(core.dispose);
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(1.3)),
        child: FuelPlaneGameScreen(networkCore: core),
      )));
      expect(find.text('ابدأ').hitTestable(), findsOneWidget);
      expect(find.text('تعاون').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      core.snapshot();
      await tester.pump();
      expect(tester.getSize(scene).height, greaterThan(140));
      expect(lowFuel.hitTestable(), findsOneWidget);
      expect(find.text('21%'), findsOneWidget);
      expect(find.textContaining('99'), findsOneWidget);
      expect(painter(tester).localX, .5);
      expect(painter(tester).remoteX, .72);

      final area = tester.getRect(scene);
      await tester
          .tapAt(area.topLeft + Offset(area.width * .26, area.height * .82));
      await tester.pump();
      expect(core.sent.last['action'], 'plane_control');
      expect(core.sent.last['x'], closeTo(.26, .001));
      expect(painter(tester).localX, closeTo(.26, .001));
      expect(painter(tester).motion!.localBank, lessThan(0));
      await tester.pump(const Duration(milliseconds: 450));
      expect(painter(tester).motion!.localBank, 0);

      final slider = find.byType(Slider);
      expect(slider.hitTestable(), findsOneWidget);
      tester.widget<Slider>(slider).onChanged!(.62);
      await tester.pump();
      expect(core.sent.last, {'action': 'plane_control', 'x': .62});

      core.snapshot({'remoteFuel': 71});
      await tester.pump();
      expect(lowFuel, findsNothing);
      expect(find.text('71%'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }

  for (final kind in NetworkConnectionKind.values) {
    testWidgets(
        'guest start and player mapping keep original ${kind.name} protocol',
        (tester) async {
      final core = PlaneTestCore(kind: kind);
      addTearDown(core.dispose);
      await tester.pumpWidget(
          MaterialApp(home: FuelPlaneGameScreen(networkCore: core)));
      await tester.tap(find.text('تعاون'));
      await tester.pump();
      expect(core.sent.single, {'action': 'plane_mode', 'mode': 1});
      await tester.tap(find.text('ابدأ'));
      await tester.pump();
      expect(core.sent.last, {'action': 'plane_start_request'});
      core.snapshot({
        'bullets': [
          {'x': .5, 'y': .65, 'remote': true},
          {'x': .72, 'y': .7, 'remote': false},
        ]
      });
      await tester.pump();
      final shot = painter(tester).projectiles;
      expect(shot.map((b) => b.remote), [false, true]);
      final dynamic state = tester.state(find.byType(FuelPlaneGameScreen));
      state.tick();
      expect(state.distance, 1500,
          reason: 'guest cannot advance the simulation');
      core.snapshot({
        'remoteAlive': false,
        'gameOver': true,
        'running': false,
        'resultText': 'فزت بالمواجهة',
      });
      await tester.pump();
      expect(painter(tester).localAlive, isFalse);
      expect(painter(tester).remoteAlive, isTrue);
      expect(painter(tester).motion!.bursts, isNotEmpty);
      expect(find.text('فاز اللاعب الآخر'), findsWidgets);
      await tester.pump(const Duration(milliseconds: 500));
      expect(painter(tester).motion!.bursts, isEmpty);
      await unmount(tester);
    });
  }

  testWidgets('host start packet, scaled steps, shots, fuel and scoring',
      (tester) async {
    final core = PlaneTestCore(mode: LocalNetworkMode.host);
    addTearDown(core.dispose);
    await tester
        .pumpWidget(MaterialApp(home: FuelPlaneGameScreen(networkCore: core)));
    core.receive({'action': 'plane_start_request'});
    await tester.pump();
    expect(core.sent.single, {
      'action': 'plane_start',
      'mode': 0,
      'planeX': .5,
      'remoteX': .5,
      'fuel': 100,
      'remoteFuel': 100,
      'score': 0,
      'remoteScore': 0,
      'distance': 0,
      'level': 1,
      'running': true,
      'gameOver': false,
      'alive': true,
      'remoteAlive': true,
      'resultText': '',
      'objects': [],
      'bullets': [],
    });
    final dynamic state = tester.state(find.byType(FuelPlaneGameScreen));
    state.tick();
    expect(state.distance, 1);
    expect(state.fuel, closeTo(99.955, .00001));
    await tester.pump();
    expect(painter(tester).projectiles.map((b) => b.y),
        everyElement(closeTo(.705, .00001)));
    expect(
        painter(tester).motion!.muzzleOpacity(remote: false), greaterThan(0));
    expect(painter(tester).motion!.muzzleOpacity(remote: true), greaterThan(0));
    await unmount(tester);
  });

  testWidgets('host sends the final versus result on an odd simulation tick',
      (tester) async {
    final core = PlaneTestCore();
    addTearDown(core.dispose);
    await tester
        .pumpWidget(MaterialApp(home: FuelPlaneGameScreen(networkCore: core)));
    core.snapshot({
      'mode': 0,
      'objects': [
        {'x': .72, 'y': .82, 'type': 2, 'size': .066},
      ],
    });
    await tester.pump();
    core.mode = LocalNetworkMode.host;
    final dynamic state = tester.state(find.byType(FuelPlaneGameScreen));
    state.simulationClock.start();
    state.tick();
    await tester.pump();
    expect(state.syncTick, 1);
    expect(core.sent.single['action'], 'plane_state');
    expect(core.sent.single['running'], isFalse);
    expect(core.sent.single['gameOver'], isTrue);
    expect(core.sent.single['resultText'], 'فزت بالمواجهة');
    expect(find.text('انتهت الجولة'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
      'live collision preserves fuel gain, hit score, level, and co-op authority',
      (tester) async {
    final core = PlaneTestCore();
    addTearDown(core.dispose);
    await tester
        .pumpWidget(MaterialApp(home: FuelPlaneGameScreen(networkCore: core)));
    core.snapshot({
      'mode': 1,
      'distance': 1499,
      'objects': [
        {'x': .5, 'y': .82, 'type': 0, 'size': .052},
        {'x': .5, 'y': .49, 'type': 1, 'size': .066},
        {'x': .72, 'y': .82, 'type': 2, 'size': .066},
      ],
      'bullets': [
        {'x': .5, 'y': .54, 'remote': true},
      ],
    });
    await tester.pump();
    core.mode = LocalNetworkMode.host;
    final dynamic state = tester.state(find.byType(FuelPlaneGameScreen));
    state.simulationClock.start();
    state.tick();
    await tester.pump();
    expect(state.distance, 1500);
    expect(state.level, 2);
    expect(state.speed, closeTo(.0083, .00001));
    expect(state.score, 99 + 75 + 120);
    expect(state.fuel, closeTo(21 - .045 + 22, .00001));
    expect(state.alive, isTrue);
    expect(state.remoteAlive, isFalse);
    expect(state.running, isTrue);
    expect(painter(tester).motion!.bursts.length, 2);
    await unmount(tester);
  });
}
