import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/core/app_settings.dart';
import 'package:gameslocal/core/network/local_network_core.dart';
import 'package:gameslocal/core/network/network_message.dart';
import 'package:gameslocal/games/football/world_class_penalty_game_v2.dart';
import 'package:gameslocal/games/football/elite_penalty_game_v2.dart' as elite;

class _Core extends LocalNetworkCore {
  _Core(this.mode, this.kind) : super(gameId: 'football_penalties');
  final LocalNetworkMode mode;
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
  void sendMove(Map<String, dynamic> payload, {required String senderId}) {
    sent.add(payload);
  }

  @override
  void disconnect() => incoming.add(NetworkMessage(
      type: NetworkMessageType.disconnect,
      gameId: gameId,
      senderId: 'peer',
      payload: const {}));
  void receivePayload(Map<String, dynamic> payload) =>
      incoming.add(NetworkMessage(
          type: NetworkMessageType.move,
          gameId: gameId,
          senderId: mode == LocalNetworkMode.host ? 'guest' : 'host',
          payload: payload));
  void receive() => incoming.add(NetworkMessage(
          type: NetworkMessageType.move,
          gameId: gameId,
          senderId: 'host',
          payload: {
            'action': 'eliteProPenaltyV2',
            'turn': 0,
            'tx': .25,
            'ty': .25,
            'kx': .25,
            'ky': .25,
            'power': .8,
            'curve': .1,
            'outcome': 'save'
          }));
  @override
  void dispose() {
    incoming.close();
    super.dispose();
  }
}

void main() {
  final haptics = <String>[];
  setUp(() {
    AppSettingsController.instance.soundEnabled = false;
    AppSettingsController.instance.vibrationEnabled = true;
    haptics.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add(call.arguments as String);
      }
      return null;
    });
  });
  tearDown(() {
    AppSettingsController.instance.soundEnabled = true;
  });
  Finder field() => find.byWidgetPredicate((w) =>
      w is CustomPaint &&
      w.painter.runtimeType.toString() == '_ElitePenaltyPainter');
  Future<Size> mount(WidgetTester tester, _Core core,
      {Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data:
                MediaQueryData(size: size, textScaler: TextScaler.linear(1.3)),
            child: ProPenaltyShootoutGameScreen(networkCore: core))));
    await tester.pump();
    return tester.getSize(field());
  }

  Map<String, dynamic> shot(int turn,
          {Map<String, dynamic> values = const {}}) =>
      {
        'action': 'eliteProPenaltyV2',
        'turn': turn,
        'tx': .25,
        'ty': .25,
        'kx': .25,
        'ky': .25,
        'power': .8,
        'curve': .1,
        'outcome': 'save',
        ...values
      };
  int resultCount() =>
      find.byIcon(Icons.check_circle_rounded).evaluate().length +
      find.byIcon(Icons.cancel_rounded).evaluate().length;
  Future<void> shoot(WidgetTester tester) async {
    final area = tester.getRect(field());
    final gesture = await tester
        .startGesture(area.topLeft + Offset(area.width * .5, area.height * .8));
    await gesture.moveBy(const Offset(0, -24));
    await gesture
        .moveTo(area.topLeft + Offset(area.width * .3, area.height * .25));
    await gesture.up();
    await tester.pump();
  }

  testWidgets('host rejects an unsolicited remote shot for its own turn',
      (tester) async {
    final core = _Core(LocalNetworkMode.host, NetworkConnectionKind.local);
    addTearDown(core.dispose);
    await mount(tester, core);
    core.receivePayload(shot(0));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(resultCount(), 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'wrong-role future turn cannot block the one legitimate peer reply',
      (tester) async {
    final core = _Core(LocalNetworkMode.host, NetworkConnectionKind.local);
    addTearDown(core.dispose);
    await mount(tester, core);
    await shoot(tester);
    await tester.pump(const Duration(milliseconds: 1430));
    core.receivePayload(shot(2));
    core.receivePayload(shot(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 230));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(resultCount(), 2);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'disconnect is terminal across lifecycle resume and new incoming moves',
      (tester) async {
    final core = _Core(LocalNetworkMode.client, NetworkConnectionKind.internet);
    addTearDown(core.dispose);
    await mount(tester, core);
    core.receive();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    core.disconnect();
    await tester.pump();
    final dynamic state = tester.state(find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_ElitePenaltyGame'));
    state.didChangeAppLifecycleState(AppLifecycleState.paused);
    state.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 2));
    expect(resultCount(), 0);
    expect(find.text('انقطع اتصال اللاعب الآخر'), findsOneWidget);
    core.receivePayload(shot(0));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(resultCount(), 0);
    expect(haptics, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('disconnect discards an already queued next shot',
      (tester) async {
    final core = _Core(LocalNetworkMode.host, NetworkConnectionKind.internet);
    addTearDown(core.dispose);
    await mount(tester, core);
    await shoot(tester);
    core.receivePayload(shot(1));
    await tester.pump();
    core.disconnect();
    await tester.pump();
    final dynamic state = tester.state(find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_ElitePenaltyGame'));
    state.didChangeAppLifecycleState(AppLifecycleState.paused);
    state.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 4));
    expect(resultCount(), 0);
    expect(find.text('انقطع اتصال اللاعب الآخر'), findsOneWidget);
    expect(core.sent.length, 1);
    await tester.pumpWidget(const SizedBox());
  });
  for (final releaseBeforeResume in [false, true]) {
    testWidgets(
        'network pause discards old pointer; release before resume=$releaseBeforeResume',
        (tester) async {
      final core = _Core(LocalNetworkMode.host, NetworkConnectionKind.local);
      addTearDown(core.dispose);
      final size = await mount(tester, core);
      final origin = tester.getTopLeft(field());
      final gesture = await tester
          .startGesture(origin + Offset(size.width * .5, size.height * .8));
      await gesture.moveBy(const Offset(0, -24));
      final dynamic state = tester.state(find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_ElitePenaltyGame'));
      state.didChangeAppLifecycleState(AppLifecycleState.paused);
      if (releaseBeforeResume) {
        await gesture.up();
        await tester.pump();
      }
      expect(core.sent, isEmpty);
      state.didChangeAppLifecycleState(AppLifecycleState.resumed);
      if (!releaseBeforeResume) {
        await gesture.up();
        await tester.pump();
      }
      expect(core.sent, isEmpty);
      await shoot(tester);
      expect(core.sent.length, 1);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final invalid in <Map<String, dynamic>>[
    {'tx': '0.2'},
    {'turn': .5},
    {'turn': '0'},
    {'kx': 100},
    {'ky': -10},
    {'power': -1},
    {'curve': 2},
    {'tx': double.nan},
    {'ty': double.infinity},
    {'kx': null},
    {'ky': true},
    {'power': []},
    {'curve': {}},
    {'outcome': 42},
    {'outcome': 'unknown'},
    {'turn': -1},
    {'turn': double.infinity},
    {'tx': -.117},
    {'tx': 1.117},
    {'ty': -.089},
    {'ty': 1.069},
  ]) {
    testWidgets(
        'malformed network shot is ignored without cast or paint exceptions $invalid',
        (tester) async {
      final core = _Core(LocalNetworkMode.client, NetworkConnectionKind.local);
      addTearDown(core.dispose);
      await mount(tester, core);
      core.receivePayload(shot(0, values: invalid));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      expect(resultCount(), 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final values in <Map<String, dynamic>>[
    {
      'tx': -.1165,
      'ty': -.0885,
      'kx': .06,
      'ky': .08,
      'power': 1.0,
      'curve': -1.0
    },
    {
      'tx': 1.1165,
      'ty': 1.0685,
      'kx': .94,
      'ky': .88,
      'power': 1.0,
      'curve': 1.0
    },
    {'tx': .1, 'ty': .1, 'kx': .1, 'ky': .12, 'power': .42, 'curve': 0.0},
  ]) {
    testWidgets('valid producer boundary remains accepted $values',
        (tester) async {
      final core =
          _Core(LocalNetworkMode.client, NetworkConnectionKind.internet);
      addTearDown(core.dispose);
      await mount(tester, core);
      core.receivePayload(shot(0, values: values));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      expect(resultCount(), 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('premature peer turn cannot preempt the local opener',
      (tester) async {
    final core = _Core(LocalNetworkMode.host, NetworkConnectionKind.local);
    addTearDown(core.dispose);
    await mount(tester, core);
    core.receivePayload(shot(1));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(resultCount(), 0);
    await shoot(tester);
    expect(core.sent.single['turn'], 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('invalid queued packet cannot block the valid next peer turn',
      (tester) async {
    final core = _Core(LocalNetworkMode.host, NetworkConnectionKind.internet);
    addTearDown(core.dispose);
    await mount(tester, core);
    await shoot(tester);
    core.receivePayload(shot(1, values: {'kx': 100}));
    core.receivePayload(shot(1));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(resultCount(), 2);
    core.receivePayload(shot(1));
    core.receivePayload(shot(3));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(resultCount(), 2);
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('finished match rejects all further remote turns',
      (tester) async {
    final core = _Core(LocalNetworkMode.host, NetworkConnectionKind.local);
    addTearDown(core.dispose);
    await mount(tester, core);
    bool finished() => find.textContaining('🏆').evaluate().isNotEmpty;
    Future<void> completeShot() async {
      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pump(const Duration(milliseconds: 1000));
    }

    // Opposite results make the aggregate odd after five pairs, so a winner
    // exists for every possible sequence produced by the actual local Random.
    for (var round = 0; round < 5 && !finished(); round++) {
      await shoot(tester);
      final sent = core.sent.last;
      await completeShot();
      if (finished()) break;
      core.receivePayload(shot((sent['turn'] as int) + 1,
          values: {'outcome': sent['outcome'] == 'goal' ? 'save' : 'goal'}));
      await tester.pump();
      await tester.pump();
      await completeShot();
    }
    expect(finished(), isTrue);
    final count = resultCount();
    final next = (core.sent.last['turn'] as int) + 1;
    core.receivePayload(shot(next));
    core.receivePayload(shot(next + 2));
    await tester.pump();
    await tester.pump();
    await completeShot();
    expect(resultCount(), count);
    expect(finished(), isTrue);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'elite keeper discards old suspended drag and accepts a fresh dive',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: elite.ChampionsPenaltyGameScreen()));
    await tester.pump();
    await shoot(tester);
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(resultCount(), 1);
    expect(find.text('أنت الحارس — اسحب نحو جهة القفز'), findsOneWidget);
    final area = tester.getRect(field());
    final old = await tester.startGesture(area.center);
    await old.moveBy(const Offset(30, -40));
    final dynamic state = tester.state(find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_ElitePenaltyGame'));
    state.didChangeAppLifecycleState(AppLifecycleState.paused);
    state.didChangeAppLifecycleState(AppLifecycleState.resumed);
    haptics.clear();
    await old.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(resultCount(), 1);
    expect(haptics, isEmpty);
    final fresh = await tester.startGesture(area.center);
    await fresh.moveBy(const Offset(-45, -60));
    await fresh.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1700));
    expect(resultCount(), 2);
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('paired short drag preserves the preceding edge aim on the wire',
      (tester) async {
    final host = _Core(LocalNetworkMode.host, NetworkConnectionKind.local);
    final guest = _Core(LocalNetworkMode.client, NetworkConnectionKind.local);
    addTearDown(host.dispose);
    addTearDown(guest.dispose);
    tester.view.physicalSize = const Size(780, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Row(children: [
      Expanded(child: ProPenaltyShootoutGameScreen(networkCore: host)),
      Expanded(child: ProPenaltyShootoutGameScreen(networkCore: guest))
    ])));
    await tester.pump();
    Future<void> shootAt(int index, {bool short = false}) async {
      final area = tester.getRect(field().at(index));
      if (short) {
        // Exercise the real arena callbacks when Flutter delivers pan-start/end
        // without an intermediate pan-update; retain the displayed edge aim.
        final detector = tester.widget<GestureDetector>(find
            .ancestor(
                of: field().at(index), matching: find.byType(GestureDetector))
            .first);
        detector.onPanStart!(DragStartDetails(
            localPosition: Offset(area.width * .5, area.height * .8)));
        detector.onPanEnd!(DragEndDetails());
        await tester.pump();
        return;
      }
      final gesture = await tester.startGesture(
          area.topLeft + Offset(area.width * .5, area.height * .8));
      await gesture.moveBy(const Offset(0, -24));
      await gesture
          .moveTo(area.topLeft + Offset(area.width * .3, area.height * .25));
      await gesture.up();
      await tester.pump();
    }

    Future<void> complete() async {
      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pump(const Duration(milliseconds: 1000));
    }

    await shootAt(0);
    guest.receivePayload(
        {...host.sent.single, 'tx': 1.0415, 'power': .8, 'curve': 1.0});
    await tester.pump();
    await tester.pump();
    await complete();
    expect(resultCount(), 2);
    await shootAt(1, short: true);
    expect(guest.sent.length, 1);
    expect(guest.sent.single['tx'], greaterThanOrEqualTo(1.0535));
    host.receivePayload(guest.sent.single);
    await tester.pump();
    await tester.pump();
    await complete();
    expect(resultCount(), 4);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'actual network painter keeps ball fixed through contact then launches it',
      (tester) async {
    final core = _Core(LocalNetworkMode.client, NetworkConnectionKind.local);
    addTearDown(core.dispose);
    final size = await mount(tester, core);
    core.receive();
    await tester.pump();
    await tester.pump();
    Future<List<int>> crop() async {
      final painter = (tester.widget(field()) as CustomPaint).painter!;
      return (await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.translate(-size.width * .5 + 4, -size.height * .80 + 4);
        painter.paint(canvas, size);
        final picture = recorder.endRecording();
        final image = await picture.toImage(8, 8);
        final bytes = await image.toByteData();
        image.dispose();
        picture.dispose();
        return bytes!.buffer.asUint8List().toList();
      }))!;
    }

    await tester.pump(const Duration(milliseconds: 330));
    final before = await crop();
    await tester.pump(const Duration(milliseconds: 264));
    expect(await crop(), before);
    await tester.pump(const Duration(milliseconds: 396));
    expect(await crop(), isNot(before));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('removing a received animation prevents late score and feedback',
      (tester) async {
    final core = _Core(LocalNetworkMode.client, NetworkConnectionKind.internet);
    addTearDown(core.dispose);
    await mount(tester, core);
    core.receive();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 570));
    expect(haptics.length, 1);
    await tester.pumpWidget(const SizedBox());
    haptics.clear();
    await tester.pump(const Duration(seconds: 4));
    expect(haptics, isEmpty);
    expect(tester.takeException(), isNull);
  });
  for (final pairedKind in NetworkConnectionKind.values) {
    for (final peerShootsDuringPause in [false, true]) {
      testWidgets(
          'paired peers preserve turn across pause, incoming-before-resume=$peerShootsDuringPause / $pairedKind',
          (tester) async {
        final host = _Core(LocalNetworkMode.host, pairedKind);
        final guest = _Core(LocalNetworkMode.client, pairedKind);
        addTearDown(host.dispose);
        addTearDown(guest.dispose);
        tester.view.physicalSize = const Size(780, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
            home: Row(children: [
          Expanded(child: ProPenaltyShootoutGameScreen(networkCore: host)),
          Expanded(child: ProPenaltyShootoutGameScreen(networkCore: guest)),
        ])));
        await tester.pump();
        Future<void> shoot(int index) async {
          final area = field().at(index);
          final size = tester.getSize(area);
          final origin = tester.getTopLeft(area);
          final gesture = await tester
              .startGesture(origin + Offset(size.width * .5, size.height * .8));
          await gesture.moveBy(const Offset(0, -24));
          await gesture
              .moveTo(origin + Offset(size.width * .3, size.height * .25));
          await gesture.up();
          await tester.pump();
        }

        await shoot(0);
        expect(host.sent.single['turn'], 0);
        guest.receivePayload(host.sent.single);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final dynamic hostState = tester.state(find
            .byWidgetPredicate(
                (w) => w.runtimeType.toString() == '_ElitePenaltyGame')
            .at(0));
        hostState.didChangeAppLifecycleState(AppLifecycleState.paused);
        await tester.pump(const Duration(milliseconds: 1500));
        int results() =>
            find.byIcon(Icons.check_circle_rounded).evaluate().length +
            find.byIcon(Icons.cancel_rounded).evaluate().length;
        expect(results(), 1, reason: 'paused host has no late score');
        if (peerShootsDuringPause) {
          await tester.pump(const Duration(milliseconds: 1000));
          await shoot(1);
          expect(guest.sent.single['turn'], 1);
          host.receivePayload(guest.sent.single);
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 1500));
        }
        haptics.clear();
        hostState.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1500));
        expect(results(), peerShootsDuringPause ? 3 : 2,
            reason: 'resumed host completes its already-sent shot');
        expect(haptics, isEmpty,
            reason: 'cancelled shot lifetime stays silent on resume');
        await tester.pump(const Duration(milliseconds: 1000));
        if (!peerShootsDuringPause) {
          await shoot(1);
          expect(guest.sent.single['turn'], 1);
          host.receivePayload(guest.sent.single);
          await tester.pump();
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 1500));
        expect(results(), 4,
            reason: 'both peers accept exactly one result on the next turn');
        expect(host.sent.length, 1, reason: 'paused turn never resends');
        final scores = tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data ?? '')
            .where((s) => RegExp(r'^\d  -  \d$').hasMatch(s))
            .toSet();
        expect(scores.length, 1, reason: 'both peers display the same score');
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  for (final kind in NetworkConnectionKind.values) {
    testWidgets('$kind local shot is sent at start with no early impact',
        (tester) async {
      final core = _Core(LocalNetworkMode.host, kind);
      addTearDown(core.dispose);
      final size = await mount(tester, core);
      final origin = tester.getTopLeft(field());
      final gesture = await tester
          .startGesture(origin + Offset(size.width * .5, size.height * .8));
      await gesture.moveBy(const Offset(0, -24));
      await gesture.moveTo(origin + Offset(size.width * .3, size.height * .25));
      await gesture.up();
      await tester.pump();
      expect(core.sent.length, 1,
          reason: 'peer receives resolved shot before animation');
      expect(core.sent.single.keys.toSet(), {
        'action',
        'turn',
        'tx',
        'ty',
        'kx',
        'ky',
        'power',
        'curve',
        'outcome'
      });
      expect(core.sent.single['turn'], 0);
      expect(haptics.where((e) => e.endsWith('lightImpact')), isEmpty);
      await tester.pump(const Duration(milliseconds: 560));
      expect(haptics.where((e) => e.endsWith('lightImpact')).length, 0);
      await tester.pump(const Duration(milliseconds: 10));
      expect(haptics.where((e) => e.endsWith('lightImpact')).length, 1);
      expect(find.text('0  -  0'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 850));
      expect(
          find.byIcon(Icons.check_circle_rounded).evaluate().length +
              find.byIcon(Icons.cancel_rounded).evaluate().length,
          1);
      await tester.pump(const Duration(milliseconds: 230));
      expect(haptics.where((e) => e.endsWith('lightImpact')).length, 1);
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets(
        '$kind received shot scores at arrival and reset cancels late work',
        (tester) async {
      final core = _Core(LocalNetworkMode.client, kind);
      addTearDown(core.dispose);
      await mount(tester, core);
      core.receive();
      await tester.pump();
      await tester.pump();
      expect(haptics, isEmpty);
      await tester.pump(const Duration(milliseconds: 570));
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      await tester.pump(const Duration(milliseconds: 840));
      expect(find.text('تصـــدٍ رائع! 🧤'), findsNothing);
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('تصـــدٍ رائع! 🧤'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
      await tester.tap(find.byTooltip('مباراة جديدة'));
      await tester.pump();
      haptics.clear();
      await tester.pump(const Duration(seconds: 3));
      expect(find.byIcon(Icons.cancel_rounded), findsNothing);
      expect(find.text('اسحب من الكرة إلى زاوية المرمى'), findsOneWidget);
      expect(haptics, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
