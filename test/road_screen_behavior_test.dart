import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/core/app_settings.dart';
import 'package:gameslocal/core/network/local_network_core.dart';
import 'package:gameslocal/core/network/network_message.dart';
import 'package:gameslocal/games/retro_road/retro_road_game.dart';
import 'package:gameslocal/games/retro_road/road_scene_painter.dart';

class RoadTestCore extends LocalNetworkCore {
  RoadTestCore(
      {this.mode = LocalNetworkMode.client,
      this.kind = NetworkConnectionKind.local})
      : super(gameId: 'retro_road');
  LocalNetworkMode mode;
  final NetworkConnectionKind kind;
  final incoming = StreamController<NetworkMessage>.broadcast();
  final sent = <Map<String, dynamic>>[];
  @override
  LocalNetworkState get state => LocalNetworkState(
      mode: mode,
      status: LocalNetworkStatus.connected,
      players: const [],
      connectionKind: kind);
  @override
  Stream<NetworkMessage> get messages => incoming.stream;
  @override
  void sendMove(Map<String, dynamic> payload, {required String senderId}) =>
      sent.add(payload);
  void receive(
          {int weather = 0,
          double x = .5,
          double trafficY = .82,
          bool crashed = false,
          int passed = 12}) =>
      incoming.add(NetworkMessage(
          type: NetworkMessageType.move,
          gameId: gameId,
          senderId: 'host',
          payload: {
            'action': 'road_state',
            'playerX': .72,
            'remoteX': x,
            'score': 1250,
            'distance': 300,
            'day': 2,
            'passed': passed,
            'weather': weather,
            'running': !crashed,
            'gameOver': crashed,
            'localCrashed': false,
            'remoteCrashed': crashed,
            'resultText': crashed ? 'فزت بالسباق' : '',
            'cars': [
              {'x': .28, 'y': trafficY, 'lane': 1, 'factor': .8},
              {'x': .64, 'y': .46, 'lane': 3, 'factor': 1.0}
            ]
          }));
  @override
  void dispose() {
    incoming.close();
    super.dispose();
  }
}

Finder roadField() => find.byKey(const ValueKey('road-scene'));

void main() {
  setUp(() {
    AppSettingsController.instance.soundEnabled = false;
    AppSettingsController.instance.vibrationEnabled = false;
  });
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(640, 320)
  ]) {
    testWidgets(
        'live field and HUD remain usable all weather at $size scale 1.3',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final core = RoadTestCore();
      addTearDown(core.dispose);
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
              data: MediaQueryData(
                  size: size, textScaler: TextScaler.linear(1.3)),
              child: RetroRoadGameScreen(networkCore: core))));
      for (var weather = 0; weather < 6; weather++) {
        core.receive(weather: weather);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(roadField(), findsOneWidget);
        expect(tester.getSize(roadField()).height, greaterThan(140));
        expect(tester.takeException(), isNull);
        expect(find.textContaining('1250'), findsOneWidget);
        final area = tester.getRect(roadField());
        await tester
            .tapAt(area.topLeft + Offset(area.width * .3, area.height * .82));
        await tester.pump();
        expect(core.sent.last['action'], 'road_control');
        expect(core.sent.last['x'], closeTo(.3, .001));
      }
      final state = tester.state(find.byType(RetroRoadGameScreen));
      tester.view.physicalSize = const Size(640, 320);
      await tester.pump();
      expect(identical(tester.state(find.byType(RetroRoadGameScreen)), state),
          isTrue);
      expect(find.textContaining('1250'), findsOneWidget);
      expect(
          (tester.widget<CustomPaint>(roadField()).painter as RoadScenePainter)
              .playerX,
          closeTo(.3, .001));
      final rotatedArea = tester.getRect(roadField());
      await tester.tapAt(rotatedArea.topLeft +
          Offset(rotatedArea.width * .7, rotatedArea.height * .82));
      await tester.pump();
      expect(core.sent.last['x'], closeTo(.7, .001));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
  testWidgets('real collision thresholds and pass/day scoring remain unchanged',
      (tester) async {
    final core = RoadTestCore();
    addTearDown(core.dispose);
    await tester
        .pumpWidget(MaterialApp(home: RetroRoadGameScreen(networkCore: core)));
    core.receive();
    await tester.pump();
    final dynamic state = tester.state(find.byType(RetroRoadGameScreen));
    expect(state.hasCrashAt(.28), isTrue);
    expect(state.hasCrashAt(.28 + .049), isTrue);
    expect(state.hasCrashAt(.28 + .051), isFalse);
    core.receive(trafficY: .82 + .065);
    await tester.pump();
    expect(state.hasCrashAt(.28), isTrue);
    core.receive(trafficY: .82 + .067);
    await tester.pump();
    expect(state.hasCrashAt(.28), isFalse);
    core.receive(trafficY: 1.15, passed: 39);
    await tester.pump();
    core.mode = LocalNetworkMode.host;
    state.simulationClock.start();
    state.tick();
    await tester.pump();
    expect(state.score, 2100);
    expect(state.day, 3);
    expect(state.passed, 0);
    expect(state.cars, isEmpty);
    expect(state.running, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
  testWidgets('live host collision stops race at the unchanged contact plane',
      (tester) async {
    final core = RoadTestCore();
    addTearDown(core.dispose);
    await tester
        .pumpWidget(MaterialApp(home: RetroRoadGameScreen(networkCore: core)));
    core.receive(x: .28);
    await tester.pump();
    core.mode = LocalNetworkMode.host;
    final dynamic state = tester.state(find.byType(RetroRoadGameScreen));
    state.simulationClock.start();
    state.tick();
    await tester.pump();
    expect(state.localCrashed, isTrue);
    expect(state.remoteCrashed, isFalse);
    expect(state.running, isFalse);
    expect(state.gameOver, isTrue);
    expect(find.text('انتهى السباق'), findsOneWidget);
    expect(find.text('فاز اللاعب الآخر'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
  testWidgets('host broadcasts original complete start state', (tester) async {
    final core = RoadTestCore(mode: LocalNetworkMode.host);
    addTearDown(core.dispose);
    await tester
        .pumpWidget(MaterialApp(home: RetroRoadGameScreen(networkCore: core)));
    await tester.tap(find.text('ابدأ'));
    await tester.pump();
    expect(core.sent.first, {
      'action': 'road_start',
      'playerX': .5,
      'remoteX': .5,
      'score': 0,
      'distance': 0,
      'day': 1,
      'passed': 0,
      'weather': 0,
      'running': true,
      'gameOver': false,
      'localCrashed': false,
      'remoteCrashed': false,
      'resultText': '',
      'cars': []
    });
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
  testWidgets('client start request and crash mapping retain wire semantics',
      (tester) async {
    final core = RoadTestCore(kind: NetworkConnectionKind.internet);
    addTearDown(core.dispose);
    await tester
        .pumpWidget(MaterialApp(home: RetroRoadGameScreen(networkCore: core)));
    await tester.tap(find.text('ابدأ'));
    await tester.pump();
    expect(core.sent.single, {'action': 'road_start_request'});
    core.receive(crashed: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('انتهى السباق'), findsOneWidget);
    expect(find.text('فاز اللاعب الآخر'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
