import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/core/app_settings.dart';
import 'package:gameslocal/core/network/local_network_core.dart';
import 'package:gameslocal/core/network/network_message.dart';
import 'package:gameslocal/games/air_hockey/air_hockey_game.dart';
import 'package:gameslocal/games/air_hockey/hockey_bot_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Core extends LocalNetworkCore {
  _Core(this.mode, {this.kind = NetworkConnectionKind.local})
      : super(gameId: 'air_hockey');
  final LocalNetworkMode mode;
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
  String get localPlayerId => 'local';
  @override
  void sendMove(Map<String, dynamic> payload, {required String senderId}) {
    sent.add(payload);
  }

  void receive(Map<String, dynamic> payload) => incoming.add(
        NetworkMessage(
          type: NetworkMessageType.move,
          gameId: 'air_hockey',
          senderId: 'peer',
          payload: payload,
        ),
      );
  @override
  void dispose() {
    incoming.close();
    super.dispose();
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'sound_enabled': false,
      'vibration_enabled': false,
    });
    await AppSettingsController.instance.load();
  });
  Future<dynamic> mount(
    WidgetTester tester, {
    _Core? core,
    Size size = const Size(320, 640),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(1.3)),
          child: AirHockeyGameScreen(networkCore: core),
        ),
      ),
    );
    await tester.pump();
    return tester.state(find.byType(AirHockeyGameScreen));
  }

  testWidgets(
    'friend mode resets bot state and both paddles remain controllable',
    (tester) async {
      final dynamic state = await mount(tester);
      state.botState = HockeyBotState.initial(const Offset(180, 115))
          .copyWith(velocity: const Offset(40, 50), timeUntilDecision: .1);
      await tester.tap(find.text('مع صديق'));
      await tester.pump();
      expect(state.botMode, isFalse);
      expect(state.botState.velocity, Offset.zero);
      expect(state.botState.timeUntilDecision, 0);
      final field = find.byWidgetPredicate((widget) =>
          widget is CustomPaint &&
          widget.painter.runtimeType.toString() == '_HockeyPainter');
      final bounds = tester.getRect(field);
      final old = state.top as Offset;
      final gesture = await tester.startGesture(
        Offset(
          bounds.left + bounds.width * .3,
          bounds.top + bounds.height * .2,
        ),
      );
      await gesture.moveBy(const Offset(20, 0));
      await gesture.up();
      expect(state.top, isNot(old));
      final oldBottom = state.bottom as Offset;
      final lowerGesture = await tester.startGesture(Offset(
          bounds.left + bounds.width * .7, bounds.top + bounds.height * .8));
      await lowerGesture.up();
      expect(state.bottom, isNot(oldBottom));
      await tester.tap(find.text('ضد الروبوت'));
      // Inspect the reset before advancing the next live simulation frame.
      expect(state.botMode, isTrue);
      expect(state.botState.velocity, Offset.zero);
      expect(state.botState.timeUntilDecision, 0);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('fifth goal still ends the match and resets bot lifetime', (
    tester,
  ) async {
    final dynamic state = await mount(tester);
    state.bottomScore = 4;
    state.puck = const Offset(.5, -.1);
    state.velocity = Offset.zero;
    state.lastMicros = 1;
    state.botState = HockeyBotState.initial(const Offset(180, 115))
        .copyWith(velocity: const Offset(40, 50), timeUntilDecision: .1);
    await tester.pump(const Duration(milliseconds: 20));
    expect(state.bottomScore, 5);
    expect(state.playing, isFalse);
    expect(state.botState.velocity, Offset.zero);
    expect(state.botState.timeUntilDecision, 0);
    expect(find.text('مباراة جديدة'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('مباراة جديدة'));
    await tester.pump();
    expect(state.bottomScore, 0);
    expect(state.topScore, 0);
    expect(state.playing, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'LAN host publishes the fifth goal with unchanged state payload keys',
      (tester) async {
    final core = _Core(LocalNetworkMode.host);
    final dynamic state = await mount(tester, core: core);
    core.receive({'action': 'hockey_control', 'x': .2, 'y': .8});
    await tester.pump();
    expect(state.top.dx, closeTo(.2, 1e-8));
    expect(state.top.dy, closeTo(.2, 1e-8));
    state.bottomScore = 4;
    state.puck = const Offset(.5, -.1);
    state.velocity = Offset.zero;
    state.lastMicros = 1;
    await tester.pump(const Duration(milliseconds: 20));
    expect(state.bottomScore, 5);
    final goals = core.sent.where((payload) =>
        payload['bottomScore'] == 5 && payload['playing'] == false);
    expect(goals, isNotEmpty);
    expect(goals.last.keys.toSet(), {
      'action',
      'puckX',
      'puckY',
      'bottomX',
      'bottomY',
      'topX',
      'topY',
      'bottomScore',
      'topScore',
      'playing'
    });
    expect(goals.last['action'], 'hockey_state');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox());
    core.dispose();
  });
  for (final kind in NetworkConnectionKind.values) {
    testWidgets(
      '$kind client preserves mirrored score and authoritative state',
      (tester) async {
        final core = _Core(LocalNetworkMode.client, kind: kind);
        final dynamic state = await mount(tester, core: core);
        expect(state.botMode, isFalse);
        core.receive({
          'action': 'hockey_state',
          'puckX': .4,
          'puckY': .2,
          'bottomX': .5,
          'bottomY': .84,
          'topX': .3,
          'topY': .16,
          'bottomScore': 5,
          'topScore': 2,
          'playing': false,
        });
        await tester.pump();
        expect(state.bottomScore, 2);
        expect(state.topScore, 5);
        expect(state.playing, isFalse);
        expect(core.sent, isEmpty);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpWidget(const SizedBox());
        core.dispose();
      },
    );
  }
}
