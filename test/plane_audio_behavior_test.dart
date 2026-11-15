import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/core/app_settings.dart';
import 'package:gameslocal/core/network/local_network_core.dart';
import 'package:gameslocal/games/fuel_plane/fuel_plane_game.dart';
import 'plane_screen_behavior_test.dart' show PlaneTestCore, unmount;

void main() {
  testWidgets(
      'flight audio events, network deduplication, preferences and cancellation',
      (tester) async {
    // The process-wide GameFeedback player pool must stay in one fake clock.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    final loops = <String>{};
    final samples = <Uint8List>[];
    Completer<void>? gate;
    String? blockedMethod;
    for (final name in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events'
    ]) {
      messenger.setMockMethodCallHandler(
          MethodChannel(name), (_) async => null);
    }
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'), (call) async {
      final args = call.arguments as Map;
      final id = args['playerId'] as String;
      if (call.method == 'create') {
        messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$id'),
            (_) async => null);
      }
      calls.add(call);
      if (call.method == 'setReleaseMode' &&
          args['releaseMode'] == 'ReleaseMode.loop') loops.add(id);
      if (call.method == blockedMethod) await gate?.future;
      if (call.method == 'setSourceBytes') {
        samples.add(Uint8List.fromList((args['bytes'] as List).cast<int>()));
        messenger.handlePlatformMessage(
            'xyz.luan/audioplayers/events/$id',
            const StandardMethodCodec().encodeSuccessEnvelope(
                {'event': 'audio.onPrepared', 'value': true}),
            (_) {});
      }
      return null;
    });
    AppSettingsController.instance.soundEnabled = true;
    AppSettingsController.instance.vibrationEnabled = false;
    List<MethodCall> resumes({bool loop = false}) => calls
        .where((c) =>
            c.method == 'resume' &&
            loops.contains((c.arguments as Map)['playerId']) == loop)
        .toList();
    Future<void> mount([PlaneTestCore? core]) => tester
        .pumpWidget(MaterialApp(home: FuelPlaneGameScreen(networkCore: core)));
    dynamic state() => tester.state(find.byType(FuelPlaneGameScreen));
    await mount();
    await tester.tap(find.text('ابدأ'));
    await tester.pump();
    state().timer.cancel();
    expect(resumes(loop: true).length, 1,
        reason: 'one engine loop begins with flight');
    final engine = (resumes(loop: true).single.arguments as Map)['playerId'];
    for (var i = 0; i < 3; i++) {
      state().fireCooldown = 0;
      state().tick();
      await tester.pump();
    }
    expect(resumes().length, 3,
        reason: 'every actual shot sounds, independent of distance');
    expect(resumes(loop: true).length, 1);
    calls.clear();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(
        calls.any((c) =>
            c.method == 'stop' && (c.arguments as Map)['playerId'] == engine),
        isTrue);
    final distance = state().distance;
    state().tick();
    expect(state().distance, distance);
    calls.clear();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    state().timer.cancel();
    expect(resumes(loop: true).length, 1);
    calls.clear();
    AppSettingsController.instance.setSoundEnabled(false);
    await tester.pump();
    expect(calls.any((c) => c.method == 'stop'), isTrue);
    calls.clear();
    state().fireCooldown = 0;
    state().tick();
    await tester.pump();
    expect(resumes(), isEmpty);
    AppSettingsController.instance.setSoundEnabled(true);
    await tester.pump();
    expect(resumes(loop: true).length, 1);
    calls.clear();
    await unmount(tester);
    expect(calls.any((c) => c.method == 'stop'), isTrue);

    final core = PlaneTestCore();
    addTearDown(core.dispose);
    await mount(core);
    core.snapshot({
      'mode': 1,
      'objects': [
        {'x': .5, 'y': .82, 'type': 0, 'size': .052},
        {'x': .5, 'y': .49, 'type': 1, 'size': .066},
      ],
      'bullets': [
        {'x': .5, 'y': .54, 'remote': true}
      ]
    });
    await tester.pump();
    calls.clear();
    samples.clear();
    core.mode = LocalNetworkMode.host;
    state().simulationClock.start();
    state().tick();
    await tester.pump();
    expect(state().score, 294);
    expect(state().fuel, closeTo(42.955, .001));
    expect(resumes().length, 3,
        reason: 'simultaneous shot, explosion, refill all sound');
    expect(samples.map((s) => s.length).toSet().length, 3);
    for (final bytes in samples) {
      final data = ByteData.sublistView(bytes);
      var peak = 0, energy = 0.0;
      for (var i = 44; i < bytes.length; i += 2) {
        final sample = data.getInt16(i, Endian.little);
        if (sample.abs() > peak) peak = sample.abs();
        energy += sample * sample;
      }
      expect(peak, lessThan(32767), reason: 'no clipped PCM samples');
      expect(energy / ((bytes.length - 44) / 2), greaterThan(100000));
    }
    await unmount(tester);
    core.mode = LocalNetworkMode.client;
    await mount(core);
    core.snapshot({'remoteFuel': 40, 'remoteScore': 0});
    await tester.pump();
    calls.clear();
    final shot = {
      'bullets': [
        {'x': .5, 'y': .7, 'remote': true}
      ],
      'remoteFuel': 62,
      'remoteScore': 120
    };
    core.snapshot(shot);
    await tester.pump();
    expect(resumes().length, 2);
    calls.clear();
    core.snapshot(shot);
    await tester.pump();
    expect(resumes(), isEmpty);
    core.snapshot({'remoteFuel': 99.99, 'remoteScore': 0});
    await tester.pump();
    calls.clear();
    samples.clear();
    core.snapshot({'remoteFuel': 100, 'remoteScore': 120});
    await tester.pump();
    expect(resumes().length, 1, reason: 'full tank pickup sounds once');
    expect(samples.single.length, 33560,
        reason: 'refuel chime, not an explosion when capped at 100');
    calls.clear();
    core.snapshot({'remoteFuel': 100, 'remoteScore': 120});
    await tester.pump();
    expect(resumes(), isEmpty);
    await unmount(tester);

    calls.clear();
    await mount();
    gate = Completer<void>();
    blockedMethod = 'setSourceBytes';
    await tester.tap(find.text('ابدأ'));
    await tester.pump();
    state().timer.cancel();
    state().tick();
    await tester.pump();
    AppSettingsController.instance.setSoundEnabled(false);
    await tester.pump();
    gate.complete();
    await tester.pump();
    expect(resumes(), isEmpty,
        reason: 'muting while a shot is preparing cancels it');
    expect(resumes(loop: true), isEmpty);
    blockedMethod = null;
    gate = null;
    await unmount(tester);
    AppSettingsController.instance.setSoundEnabled(true);

    for (final method in [
      'stop',
      'setVolume',
      'setReleaseMode',
      'setSourceBytes',
      'resume'
    ]) {
      calls.clear();
      await mount();
      gate = Completer<void>();
      blockedMethod = method;
      await tester.tap(find.text('ابدأ'));
      await tester.pump();
      state().timer.cancel();
      state().tick();
      await tester.pump();
      expect(calls.any((c) => c.method == method), isTrue,
          reason: 'reached pending $method');
      final resumesBefore = calls.where((c) => c.method == 'resume').length;
      await tester.pumpWidget(const SizedBox());
      gate.complete();
      await tester.pump();
      expect(calls.where((c) => c.method == 'resume').length, resumesBefore,
          reason: 'no late audio after leaving during $method');
      expect(calls.last.method, isNot('resume'));
      blockedMethod = null;
      gate = null;
      await tester.pump(const Duration(seconds: 1));
    }
  });
}
