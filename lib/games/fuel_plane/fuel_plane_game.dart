import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/audio_feedback.dart';
import '../../core/network/local_network_core.dart';
import '../../core/network/network_message.dart';
import '../arcade/arcade_timing.dart';
import 'plane_scene_geometry.dart';
import 'plane_scene_motion.dart';
import 'plane_scene_painter.dart';

class FuelPlaneGameScreen extends StatefulWidget {
  const FuelPlaneGameScreen({super.key, this.networkCore});
  final LocalNetworkCore? networkCore;
  @override
  State<FuelPlaneGameScreen> createState() => _FuelPlaneGameScreenState();
}

class _Obj {
  _Obj(
      {required this.x,
      required this.y,
      required this.type,
      required this.size});
  double x, y;
  final PlaneObstacleKind type;
  final double size;
}

class _Bullet {
  _Bullet(this.x, this.y, {this.remote = false});
  double x, y;
  final bool remote;
}

class _FuelPlaneGameScreenState extends State<FuelPlaneGameScreen>
    with SingleTickerProviderStateMixin {
  final Random rnd = Random();
  Timer? timer;
  Timer? _effectTimer;
  late final PlaneSceneMotion _motion;
  double planeX = .5, remoteX = .5, fuel = 100, remoteFuel = 100, speed = .0065;
  int score = 0,
      remoteScore = 0,
      distance = 0,
      level = 1,
      best = 0,
      fireCooldown = 0,
      remoteFireCooldown = 0,
      scoreTick = 0;
  bool running = false, gameOver = false, alive = true, remoteAlive = true;
  int networkMode = 0; // 0 مواجهة، 1 تعاون
  String resultText = '';
  String effectText = '';
  bool effectVisible = false;
  StreamSubscription<NetworkMessage>? networkSub;
  int syncTick = 0;
  final Stopwatch simulationClock = Stopwatch();
  int lastSimulationMicros = 0;
  double tickCarry = 0;

  bool get isNetworkGame => widget.networkCore != null;
  bool get isHost => widget.networkCore?.state.mode == LocalNetworkMode.host;
  String get localPlayerId => widget.networkCore?.localPlayerId ?? 'local';
  final List<_Obj> objects = [];
  final List<_Bullet> bullets = [];

  @override
  void initState() {
    super.initState();
    _motion = PlaneSceneMotion(this);
    if (isNetworkGame)
      networkSub = widget.networkCore!.messages.listen(_onNetworkMessage);
  }

  @override
  void dispose() {
    networkSub?.cancel();
    timer?.cancel();
    simulationClock.stop();
    _effectTimer?.cancel();
    _motion.dispose();
    super.dispose();
  }

  void start() {
    if (isNetworkGame && !isHost) {
      widget.networkCore?.sendMove(
          <String, dynamic>{'action': 'plane_start_request'},
          senderId: localPlayerId);
      return;
    }
    timer?.cancel();
    _effectTimer?.cancel();
    _motion.reset();
    simulationClock
      ..reset()
      ..start();
    lastSimulationMicros = 0;
    tickCarry = 0;
    setState(() {
      planeX = .5;
      remoteX = .5;
      fuel = 100;
      remoteFuel = 100;
      speed = .0065;
      score = 0;
      remoteScore = 0;
      distance = 0;
      level = 1;
      fireCooldown = 0;
      remoteFireCooldown = 0;
      scoreTick = 0;
      running = true;
      gameOver = false;
      alive = true;
      remoteAlive = true;
      resultText = '';
      effectVisible = false;
      objects.clear();
      bullets.clear();
    });
    timer = Timer.periodic(const Duration(milliseconds: 30), (_) => tick());
    if (isNetworkGame && isHost) _sendState('plane_start');
  }

  void tick() {
    if (!running) return;
    if (isNetworkGame && !isHost) return;
    final now = simulationClock.elapsedMicroseconds;
    final elapsed = lastSimulationMicros == 0
        ? 0.03
        : (now - lastSimulationMicros) / 1000000;
    lastSimulationMicros = now;
    final step = ArcadeTiming.tickScale(elapsed);
    tickCarry += step;
    final wholeTicks = tickCarry.floor();
    tickCarry -= wholeTicks;
    var event = 0;
    distance += wholeTicks;
    scoreTick += wholeTicks;
    while (scoreTick >= 12) {
      if (alive) score++;
      if (isNetworkGame && remoteAlive) remoteScore++;
      scoreTick -= 12;
    }
    if (alive) fuel -= .045 * step;
    if (isNetworkGame && remoteAlive) remoteFuel -= .045 * step;
    level = 1 + distance ~/ 1500;
    speed = min(.018, .0065 + level * .0009);

    if (alive) {
      if (fireCooldown <= 0) {
        bullets.add(_Bullet(planeX, .745));
        _motion.fire();
        fireCooldown = max(7, 14 - min(5, level ~/ 2));
        event = 1;
      } else {
        fireCooldown -= wholeTicks;
      }
    }
    if (isNetworkGame && remoteAlive) {
      if (remoteFireCooldown <= 0) {
        bullets.add(_Bullet(remoteX, .745, remote: true));
        _motion.fire(remote: true);
        remoteFireCooldown = max(7, 14 - min(5, level ~/ 2));
      } else {
        remoteFireCooldown -= wholeTicks;
      }
    }

    // Exact spawn logic from the tested carsgame Fuel Plane.
    final spawn = .018 + min(.018, level * .002);
    if (rnd.nextDouble() < ArcadeTiming.scaledProbability(spawn, step)) {
      final roll = rnd.nextDouble();
      final type = roll < .25
          ? PlaneObstacleKind.fuel
          : (roll < .78 ? PlaneObstacleKind.rock : PlaneObstacleKind.enemy);
      objects.add(_Obj(
        x: .12 + rnd.nextDouble() * .76,
        y: -.08,
        type: type,
        size: type == PlaneObstacleKind.fuel ? .052 : .066,
      ));
    }

    for (final o in objects) {
      o.y += speed * step;
    }
    for (final b in bullets) {
      b.y -= .040 * step;
    }
    objects.removeWhere((o) => o.y > 1.12);
    bullets.removeWhere((b) => b.y < -.08);

    final hitObjects = <_Obj>[], hitBullets = <_Bullet>[];
    for (final b in bullets) {
      for (final o in objects) {
        if (o.type != PlaneObstacleKind.fuel &&
            !hitObjects.contains(o) &&
            (b.x - o.x).abs() < o.size &&
            (b.y - o.y).abs() < o.size) {
          hitObjects.add(o);
          hitBullets.add(b);
          _motion.burst(o.x, o.y);
          if (b.remote) {
            remoteScore += 75;
          } else {
            score += 75;
          }
          event = 2;
          break;
        }
      }
    }
    objects.removeWhere(hitObjects.contains);
    bullets.removeWhere(hitBullets.contains);

    final wasAlive = alive, wasRemoteAlive = remoteAlive;
    for (final o in List<_Obj>.of(objects)) {
      if (alive &&
          (planeX - o.x).abs() < o.size * .92 &&
          (.82 - o.y).abs() < o.size * .92) {
        if (o.type == PlaneObstacleKind.fuel) {
          fuel = min(100, fuel + 22);
          score += 120;
          objects.remove(o);
          event = 3;
        } else {
          fuel = 0;
          alive = false;
          event = 4;
        }
      } else if (isNetworkGame &&
          remoteAlive &&
          (remoteX - o.x).abs() < o.size * .92 &&
          (.82 - o.y).abs() < o.size * .92) {
        if (o.type == PlaneObstacleKind.fuel) {
          remoteFuel = min(100, remoteFuel + 22);
          remoteScore += 120;
          objects.remove(o);
          event = 3;
        } else {
          remoteFuel = 0;
          remoteAlive = false;
          event = 4;
        }
      }
    }

    if (alive && fuel <= 0) {
      fuel = 0;
      alive = false;
      event = 4;
    }
    if (isNetworkGame && remoteAlive && remoteFuel <= 0) {
      remoteFuel = 0;
      remoteAlive = false;
      event = 4;
    }

    _showCrashes(wasAlive: wasAlive, wasRemoteAlive: wasRemoteAlive);

    final shouldEnd = isNetworkGame
        ? (networkMode == 0
            ? (!alive || !remoteAlive)
            : (!alive && !remoteAlive))
        : !alive;
    if (shouldEnd) {
      running = false;
      gameOver = true;
      timer?.cancel();
      simulationClock.stop();
      best = max(best, score);
      if (isNetworkGame) {
        resultText = networkMode == 1
            ? 'انتهت المهمة التعاونية • مجموع النقاط ' +
                (score + remoteScore).toString()
            : (!alive && !remoteAlive
                ? 'تعادل'
                : (!alive ? 'فاز اللاعب الآخر' : 'فزت بالمواجهة'));
      }
      _showEffect('انتهت الجولة');
      if (isNetworkGame && networkMode == 0 && alive && !remoteAlive) {
        GameFeedback.win(GameAudioTheme.plane);
      } else {
        GameFeedback.lose(GameAudioTheme.plane);
      }
    } else if (event == 2) {
      _showEffect('إصابة!');
      GameFeedback.capture(GameAudioTheme.plane);
    } else if (event == 3) {
      _showEffect('وقود إضافي');
      GameFeedback.tap(GameAudioTheme.plane);
    } else if (event == 1 && distance % 90 == 0) {
      GameFeedback.move(GameAudioTheme.plane);
    }

    if (isNetworkGame && isHost && (++syncTick % 2 == 0 || shouldEnd)) {
      _sendState('plane_state');
    }
    if (mounted) setState(() {});
  }

  void setPlane(double dx, double width) {
    if (!running || width <= 0 || !alive) return;
    _moveLocalPlane(PlaneSceneGeometry(Size(width, 1)).worldXForTouch(dx));
  }

  void _moveLocalPlane(double x) {
    _motion.turn(x - planeX);
    setState(() => planeX = x);
    if (isNetworkGame && !isHost) {
      widget.networkCore?.sendMove(
          <String, dynamic>{'action': 'plane_control', 'x': planeX},
          senderId: localPlayerId);
    }
  }

  void _sendState(String action) {
    widget.networkCore?.sendMove(<String, dynamic>{
      'action': action,
      'mode': networkMode,
      'planeX': planeX,
      'remoteX': remoteX,
      'fuel': fuel,
      'remoteFuel': remoteFuel,
      'score': score,
      'remoteScore': remoteScore,
      'distance': distance,
      'level': level,
      'running': running,
      'gameOver': gameOver,
      'alive': alive,
      'remoteAlive': remoteAlive,
      'resultText': resultText,
      'objects': objects
          .map((o) => <String, dynamic>{
                'x': o.x,
                'y': o.y,
                'type': o.type.index,
                'size': o.size
              })
          .toList(),
      'bullets': bullets
          .map((b) => <String, dynamic>{'x': b.x, 'y': b.y, 'remote': b.remote})
          .toList(),
    }, senderId: localPlayerId);
  }

  void _onNetworkMessage(NetworkMessage m) {
    if (!mounted ||
        m.senderId == localPlayerId ||
        m.type != NetworkMessageType.move) return;
    final action = m.payload['action']?.toString();
    if (action == 'plane_start_request' && isHost) {
      start();
      return;
    }
    if (action == 'plane_control' && isHost) {
      final x = (m.payload['x'] as num?)?.toDouble();
      if (x != null) {
        final next = x.clamp(.08, .92).toDouble();
        _motion.turn(next - remoteX, remote: true);
        setState(() => remoteX = next);
      }
      return;
    }
    if (action == 'plane_mode' && isHost && !running) {
      networkMode = ((m.payload['mode'] as num?)?.toInt() ?? 0).clamp(0, 1);
      _sendState('plane_state');
      return;
    }
    if ((action == 'plane_state' || action == 'plane_start') && !isHost) {
      final rawObjects = m.payload['objects'] as List<dynamic>? ?? const [];
      final rawBullets = m.payload['bullets'] as List<dynamic>? ?? const [];
      final oldScore = score;
      final oldFuel = fuel;
      final oldRemoteScore = remoteScore;
      final oldPlaneX = planeX, oldRemoteX = remoteX;
      final wasAlive = alive, wasRemoteAlive = remoteAlive;
      final previousBullets = List<_Bullet>.of(bullets);
      final previousObjects = List<_Obj>.of(objects);
      final roundStarted =
          action == 'plane_start' || (!running && m.payload['running'] == true);
      if (roundStarted) {
        _effectTimer?.cancel();
        _motion.reset();
      }
      final wasGameOver = gameOver;
      setState(() {
        networkMode =
            ((m.payload['mode'] as num?)?.toInt() ?? networkMode).clamp(0, 1);
        planeX = ((m.payload['remoteX'] as num?)?.toDouble() ?? planeX)
            .clamp(.08, .92);
        remoteX = ((m.payload['planeX'] as num?)?.toDouble() ?? remoteX)
            .clamp(.08, .92);
        fuel = (m.payload['remoteFuel'] as num?)?.toDouble() ?? fuel;
        remoteFuel = (m.payload['fuel'] as num?)?.toDouble() ?? remoteFuel;
        score = (m.payload['remoteScore'] as num?)?.toInt() ?? score;
        remoteScore = (m.payload['score'] as num?)?.toInt() ?? remoteScore;
        distance = (m.payload['distance'] as num?)?.toInt() ?? distance;
        level = (m.payload['level'] as num?)?.toInt() ?? level;
        running = m.payload['running'] == true;
        if (roundStarted) effectVisible = false;
        gameOver = m.payload['gameOver'] == true;
        alive = m.payload['remoteAlive'] != false;
        remoteAlive = m.payload['alive'] != false;
        final hostText = (m.payload['resultText'] ?? '').toString();
        resultText = hostText == 'فزت بالمواجهة'
            ? 'فاز اللاعب الآخر'
            : hostText == 'فاز اللاعب الآخر'
                ? 'فزت بالمواجهة'
                : hostText;
        objects
          ..clear()
          ..addAll(rawObjects.whereType<Map>().map((e) => _Obj(
              x: (e['x'] as num).toDouble(),
              y: (e['y'] as num).toDouble(),
              type: PlaneObstacleKind.values[(e['type'] as num)
                  .toInt()
                  .clamp(0, PlaneObstacleKind.values.length - 1)],
              size: (e['size'] as num).toDouble())));
        bullets
          ..clear()
          ..addAll(rawBullets.whereType<Map>().map((e) => _Bullet(
              (e['x'] as num).toDouble(), (e['y'] as num).toDouble(),
              remote: e['remote'] != true)));
      });
      if (!roundStarted) {
        _motion.turn(planeX - oldPlaneX);
        _motion.turn(remoteX - oldRemoteX, remote: true);
      }
      _showSnapshotShots(previousBullets);
      if (!roundStarted &&
          (score - oldScore >= 75 || remoteScore - oldRemoteScore >= 75)) {
        _showSnapshotHits(previousObjects, previousBullets);
      }
      _showCrashes(wasAlive: wasAlive, wasRemoteAlive: wasRemoteAlive);
      if (wasAlive && !alive) {
        _showEffect('طائرتك تحطمت');
        GameFeedback.lose(GameAudioTheme.plane);
      } else if (!wasGameOver && gameOver) {
        _showEffect(resultText.isEmpty ? 'انتهت الجولة' : resultText);
        if (resultText == 'فزت بالمواجهة') {
          GameFeedback.win(GameAudioTheme.plane);
        } else {
          GameFeedback.lose(GameAudioTheme.plane);
        }
      } else if (fuel > oldFuel + 5) {
        _showEffect('وقود إضافي');
        GameFeedback.tap(GameAudioTheme.plane);
      } else if (score >= oldScore + 75) {
        _showEffect('إصابة!');
        GameFeedback.capture(GameAudioTheme.plane);
      }
    }
  }

  void setNetworkMode(int mode) {
    if (running) return;
    setState(() => networkMode = mode.clamp(0, 1));
    if (isNetworkGame) {
      widget.networkCore?.sendMove(
          <String, dynamic>{'action': 'plane_mode', 'mode': networkMode},
          senderId: localPlayerId);
    }
  }

  void _showEffect(String text) {
    if (!mounted) return;
    setState(() {
      effectText = text;
      effectVisible = true;
    });
    _effectTimer?.cancel();
    _effectTimer = Timer(const Duration(milliseconds: 420), () {
      if (mounted) setState(() => effectVisible = false);
    });
  }

  void _showCrashes({required bool wasAlive, required bool wasRemoteAlive}) {
    if (wasAlive && !alive) {
      _motion.burst(planeX, PlaneSceneGeometry.playerY, crash: true);
    }
    if (wasRemoteAlive && !remoteAlive) {
      _motion.burst(remoteX, PlaneSceneGeometry.playerY, crash: true);
    }
  }

  void _showSnapshotShots(List<_Bullet> previous) {
    for (final bullet in bullets) {
      if (bullet.y < .50) continue;
      final seen = previous.any((old) =>
          old.remote == bullet.remote &&
          old.x == bullet.x &&
          old.y >= bullet.y &&
          old.y - bullet.y <= .25);
      if (!seen) _motion.fire(remote: bullet.remote);
    }
  }

  void _showSnapshotHits(List<_Obj> previous, List<_Bullet> previousBullets) {
    // A hit is visualized from the existing snapshots. Scoring and collision
    // remain authoritative on the host.
    for (final obstacle in previous) {
      if (obstacle.type == PlaneObstacleKind.fuel) continue;
      final remained = objects.any((current) =>
          current.x == obstacle.x &&
          current.type == obstacle.type &&
          current.y >= obstacle.y);
      if (remained) continue;
      final crossed = previousBullets.any((bullet) =>
          (bullet.x - obstacle.x).abs() < obstacle.size &&
          bullet.y >= obstacle.y - obstacle.size &&
          bullet.y <= obstacle.y + obstacle.size + .26);
      if (crossed) _motion.burst(obstacle.x, obstacle.y);
    }
  }

  bool get _lowFuel => fuel < 25;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xff0a202c),
        appBar: AppBar(
          title: const Text('طائرة الوقود'),
          backgroundColor: const Color(0xff0a202c),
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
            child: LayoutBuilder(builder: (context, constraints) {
              final field = _buildField();
              final hud = _buildHud();
              final control = _buildControl();
              final wide = constraints.maxWidth >= 470 &&
                  constraints.maxWidth > constraints.maxHeight * 1.5;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: field),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 194,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: SingleChildScrollView(child: hud)),
                          const SizedBox(height: 8),
                          control,
                        ],
                      ),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  hud,
                  const SizedBox(height: 8),
                  Expanded(child: field),
                  const SizedBox(height: 8),
                  control,
                ],
              );
            }),
          ),
        ),
      );

  Widget _buildHud() {
    final color = _lowFuel
        ? const Color(0xffffad96)
        : fuel <= 50
            ? const Color(0xffffc879)
            : const Color(0xff9af5bd);
    final percentage = '${fuel.clamp(0, 100).round()}%';
    const dataStyle = TextStyle(color: Color(0xffecf8ff), fontSize: 13);
    return DecoratedBox(
      decoration: _panel(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 3,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text('نقاطك: $score',
                    style: dataStyle.copyWith(fontWeight: FontWeight.w800)),
                if (isNetworkGame)
                  Text('الآخر: $remoteScore',
                      style:
                          dataStyle.copyWith(color: const Color(0xffffc366))),
                Text('المرحلة: $level', style: dataStyle),
                if (!isNetworkGame)
                  Text('الأفضل: $best',
                      style:
                          dataStyle.copyWith(color: const Color(0xffb4dce8))),
              ],
            ),
            const SizedBox(height: 7),
            Semantics(
              label: _lowFuel ? 'وقود منخفض' : 'الوقود',
              value: percentage,
              excludeSemantics: true,
              child: Row(
                children: [
                  Icon(
                    _lowFuel
                        ? Icons.warning_amber_rounded
                        : Icons.local_gas_station_rounded,
                    color: color,
                    size: 16,
                  ),
                  if (_lowFuel)
                    Flexible(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(start: 4),
                        child: Text(
                          'وقود منخفض',
                          style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: fuel.clamp(0, 100) / 100,
                        minHeight: 6,
                        color: color,
                        backgroundColor: const Color(0xff365561),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    percentage,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            if (isNetworkGame && !running)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('مواجهة')),
                    ButtonSegment(value: 1, label: Text('تعاون')),
                  ],
                  selected: {networkMode},
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    foregroundColor: const Color(0xffecf8ff),
                    selectedForegroundColor: const Color(0xff0a202c),
                    selectedBackgroundColor: const Color(0xffa3e7f1),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    visualDensity: VisualDensity.compact,
                  ),
                  onSelectionChanged: (value) => setNetworkMode(value.first),
                ),
              ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _panel() => BoxDecoration(
        color: const Color(0xff123442),
        border: Border.all(color: const Color(0xff2b4f5e)),
        borderRadius: BorderRadius.circular(14),
      );

  Widget _buildControl() => DecoratedBox(
        decoration: _panel(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 5, 8, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'التحكم بالطائرة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xffd2e8ef),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 5,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 10),
                  activeTrackColor: const Color(0xff81e8f5),
                  inactiveTrackColor: const Color(0xff466270),
                  thumbColor: const Color(0xffd8faff),
                ),
                child: Slider(
                  value: planeX.clamp(.08, .92),
                  min: .08,
                  max: .92,
                  onChanged: running ? _moveLocalPlane : null,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildField() => ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (details) => setPlane(details.localPosition.dx, width),
            onPanUpdate: (details) => setPlane(details.localPosition.dx, width),
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    key: const ValueKey('plane-scene'),
                    painter: PlaneScenePainter(
                      localX: planeX,
                      remoteX: isNetworkGame ? remoteX : null,
                      localAlive: alive,
                      remoteAlive: remoteAlive,
                      obstacles: [
                        for (final object in objects)
                          PlaneObstacle(
                              object.x, object.y, object.size, object.type),
                      ],
                      projectiles: [
                        for (final bullet in bullets)
                          PlaneProjectile(bullet.x, bullet.y,
                              remote: bullet.remote),
                      ],
                      distance: distance,
                      motion: _motion,
                    ),
                  ),
                ),
                IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: running && alive && _lowFuel ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: const Color(0xfffc927f), width: 2),
                      ),
                    ),
                  ),
                ),
                if (running)
                  Align(
                    alignment: Alignment.topCenter,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: effectVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 120),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: DecoratedBox(
                            decoration: _panel(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              child: Text(
                                effectText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (!running) _buildRoundCard(),
              ],
            ),
          );
        }),
      );

  Widget _buildRoundCard() => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 290),
            child: DecoratedBox(
              decoration: _panel().copyWith(color: const Color(0xf0102c39)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      gameOver ? 'انتهت الجولة' : 'جاهز للطيران؟',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      gameOver
                          ? (isNetworkGame ? resultText : 'نقاطك: $score')
                          : (isNetworkGame
                              ? (networkMode == 0
                                  ? 'مواجهة: آخر طائرة تبقى تفوز'
                                  : 'تعاون: اجمعا النقاط وابقيا معًا')
                              : 'حرّك الطائرة بإصبعك. الإطلاق تلقائي.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xffd2e8ef), fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    FilledButton.icon(
                      onPressed: start,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xffa3e7f1),
                        foregroundColor: const Color(0xff0a202c),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(gameOver ? 'إعادة اللعب' : 'ابدأ'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
