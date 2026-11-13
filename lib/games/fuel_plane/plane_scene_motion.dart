import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'plane_scene_geometry.dart';

typedef PlaneBurstFrame = ({double x, double y, double progress, bool crash});

class PlaneSceneMotion extends ChangeNotifier {
  PlaneSceneMotion(TickerProvider vsync) {
    _ticker = vsync.createTicker(_advance);
  }

  static const _bankDuration = Duration(milliseconds: 275);
  static const _muzzleDuration = Duration(milliseconds: 100);
  static const _hitDuration = Duration(milliseconds: 260);
  static const _crashDuration = Duration(milliseconds: 380);

  late final Ticker _ticker;
  Duration _now = Duration.zero;
  Duration _started = Duration.zero;
  Duration _until = Duration.zero;
  ({double delta, Duration at})? _localTurn, _remoteTurn;
  Duration? _localShot, _remoteShot;
  final _bursts = <({double x, double y, Duration at, bool crash})>[];

  void _advance(Duration elapsed) {
    _now = _started + elapsed;
    _bursts.removeWhere((burst) => _age(burst.at, _duration(burst.crash)) >= 1);
    notifyListeners();
    if (_now >= _until) _ticker.stop();
  }

  void _animate(Duration duration) {
    final end = _now + duration;
    if (end > _until) _until = end;
    if (!_ticker.isActive) {
      _started = _now;
      _ticker.start();
    }
    notifyListeners();
  }

  double _age(Duration at, Duration duration) =>
      ((_now - at).inMicroseconds / duration.inMicroseconds).clamp(0, 1);

  static Duration _duration(bool crash) =>
      crash ? _crashDuration : _hitDuration;

  void turn(double delta, {bool remote = false}) {
    if (!delta.isFinite || delta == 0) return;
    final turn = (delta: delta, at: _now);
    if (remote) {
      _remoteTurn = turn;
    } else {
      _localTurn = turn;
    }
    _animate(_bankDuration);
  }

  double _bank(({double delta, Duration at})? turn) {
    if (turn == null) return 0;
    final remaining = 1 - _age(turn.at, _bankDuration);
    return PlaneSceneGeometry.bankForDelta(turn.delta) * remaining * remaining;
  }

  double get localBank => _bank(_localTurn);
  double get remoteBank => _bank(_remoteTurn);

  void fire({bool remote = false}) {
    if (remote) {
      _remoteShot = _now;
    } else {
      _localShot = _now;
    }
    _animate(_muzzleDuration);
  }

  double muzzleOpacity({required bool remote}) {
    final at = remote ? _remoteShot : _localShot;
    return at == null ? 0 : 1 - _age(at, _muzzleDuration);
  }

  void burst(double x, double y, {bool crash = false}) {
    _bursts.add((x: x, y: y, at: _now, crash: crash));
    _animate(_duration(crash));
  }

  Iterable<PlaneBurstFrame> get bursts => _bursts.map((burst) => (
        x: burst.x,
        y: burst.y,
        progress: _age(burst.at, _duration(burst.crash)),
        crash: burst.crash,
      ));

  void reset() {
    _ticker.stop();
    _now = _until = Duration.zero;
    _localTurn = _remoteTurn = null;
    _localShot = _remoteShot = null;
    _bursts.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
