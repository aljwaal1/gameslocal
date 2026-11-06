import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/audio_feedback.dart';
import '../../core/network/local_network_core.dart';
import '../../core/network/network_message.dart';
import 'road_scene_geometry.dart';
import 'road_scene_painter.dart';
import '../arcade/arcade_timing.dart';

class RetroRoadGameScreen extends StatefulWidget {
  const RetroRoadGameScreen({super.key, this.networkCore});
  final LocalNetworkCore? networkCore;
  @override
  State<RetroRoadGameScreen> createState() => _RetroRoadGameScreenState();
}

enum _Weather { day, sunset, night, fog, snow, rain }

extension on _Weather {
  String get label => switch (this) {
        _Weather.day => 'نهار',
        _Weather.sunset => 'غروب',
        _Weather.night => 'ليل',
        _Weather.fog => 'ضباب',
        _Weather.snow => 'ثلج',
        _Weather.rain => 'مطر'
      };
  double get steering =>
      switch (this) { _Weather.snow => 1.45, _Weather.rain => 1.22, _ => 1.0 };
}

class _Traffic {
  _Traffic(this.x, this.y, this.lane, this.factor);
  double x, y;
  final int lane;
  final double factor;
}

class _RetroRoadGameScreenState extends State<RetroRoadGameScreen> {
  final Random rnd = Random();
  Timer? timer;
  double playerX = .5, remoteX = .5, speed = .0068;
  int score = 0, distance = 0, day = 1, passed = 0, best = 0, scoreTick = 0;
  bool running = false,
      gameOver = false,
      localCrashed = false,
      remoteCrashed = false;
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
  _Weather weather = _Weather.day, lastWeather = _Weather.day;
  final List<_Traffic> cars = [];

  @override
  void initState() {
    super.initState();
    if (isNetworkGame)
      networkSub = widget.networkCore!.messages.listen(_onNetworkMessage);
  }

  @override
  void dispose() {
    networkSub?.cancel();
    timer?.cancel();
    simulationClock.stop();
    super.dispose();
  }

  void start() {
    if (isNetworkGame && !isHost) {
      widget.networkCore?.sendMove(
          <String, dynamic>{'action': 'road_start_request'},
          senderId: localPlayerId);
      return;
    }
    timer?.cancel();
    simulationClock
      ..reset()
      ..start();
    lastSimulationMicros = 0;
    tickCarry = 0;
    setState(() {
      playerX = .5;
      remoteX = .5;
      speed = .0068;
      score = 0;
      distance = 0;
      day = 1;
      passed = 0;
      scoreTick = 0;
      running = true;
      gameOver = false;
      localCrashed = false;
      remoteCrashed = false;
      resultText = '';
      weather = _Weather.day;
      lastWeather = _Weather.day;
      cars.clear();
    });
    timer = Timer.periodic(const Duration(milliseconds: 30), (_) => tick());
    if (isNetworkGame && isHost) _sendState('road_start');
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
    while (scoreTick >= 10) {
      score++;
      scoreTick -= 10;
    }
    speed = min(.020, .0068 + day * .0008 + distance / 220000);
    updateWeather();
    if (weather != lastWeather) {
      event = 2;
      lastWeather = weather;
    }

    // Exact traffic generation from the tested carsgame Retro Road.
    final spawn = .018 + min(.014, day * .0022);
    if (rnd.nextDouble() < ArcadeTiming.scaledProbability(spawn, step)) {
      const lanes = [.28, .40, .52, .64, .76];
      final lane = rnd.nextInt(lanes.length);
      cars.add(_Traffic(
        lanes[lane] + (rnd.nextDouble() - .5) * .020,
        -.10,
        lane,
        .70 + rnd.nextDouble() * .42,
      ));
    }

    for (final car in cars) {
      car.y += speed * car.factor * step;
    }
    final before = cars.length;
    cars.removeWhere((c) => c.y > 1.15);
    final removed = before - cars.length;
    if (removed > 0) {
      passed += removed;
      score += removed * 100;
      event = 1;
    }

    if (passed >= 40) {
      day++;
      passed = 0;
      cars.clear();
      score += 750;
      event = 3;
    }

    if (isNetworkGame) {
      if (!localCrashed && hasCrashAt(playerX)) {
        localCrashed = true;
        event = 4;
      }
      if (!remoteCrashed && hasCrashAt(remoteX)) {
        remoteCrashed = true;
        event = 4;
      }
      if (localCrashed || remoteCrashed) {
        running = false;
        gameOver = true;
        timer?.cancel();
        simulationClock.stop();
        resultText = localCrashed && remoteCrashed
            ? 'تعادل — اصطدمتما معًا'
            : (localCrashed ? 'فاز اللاعب الآخر' : 'فزت بالسباق');
      }
    } else if (hasCrashAt(playerX)) {
      running = false;
      gameOver = true;
      best = max(best, score);
      timer?.cancel();
      simulationClock.stop();
      event = 4;
    }

    if (event == 4) {
      _showEffect('💥 حادث!');
      GameFeedback.lose(GameAudioTheme.road);
    } else if (event == 3) {
      _showEffect('🏁 يوم جديد!');
      GameFeedback.win(GameAudioTheme.road);
    } else if (event == 2) {
      _showEffect('🌦 ' + weather.label);
      GameFeedback.tap(GameAudioTheme.road);
    } else if (event == 1 && passed % 5 == 0) {
      GameFeedback.capture(GameAudioTheme.road);
    }
    if (isNetworkGame && isHost && ++syncTick % 2 == 0)
      _sendState('road_state');
    if (mounted) setState(() {});
  }

  void updateWeather() {
    final p = passed / 40;
    weather = p < .16
        ? _Weather.day
        : p < .31
            ? _Weather.sunset
            : p < .47
                ? _Weather.night
                : p < .63
                    ? _Weather.fog
                    : p < .81
                        ? _Weather.snow
                        : _Weather.rain;
  }

  bool hasCrashAt(double x) {
    for (final c in cars) {
      if ((x - c.x).abs() < .050 && (.82 - c.y).abs() < .066) return true;
    }
    return false;
  }

  void move(double dir) {
    if (!running || localCrashed) return;
    setState(() =>
        playerX = (playerX + dir * .034 * weather.steering).clamp(.16, .84));
    _sendRoadControl();
  }

  void dragRoad(double dx, double width) {
    if (!running || localCrashed || width <= 0) return;
    setState(() => playerX = (dx / width).clamp(.16, .84).toDouble());
    _sendRoadControl();
  }

  void _sendRoadControl() {
    if (isNetworkGame && !isHost) {
      widget.networkCore?.sendMove(
          <String, dynamic>{'action': 'road_control', 'x': playerX},
          senderId: localPlayerId);
    }
  }

  void _sendState(String action) {
    widget.networkCore?.sendMove(<String, dynamic>{
      'action': action,
      'playerX': playerX,
      'remoteX': remoteX,
      'score': score,
      'distance': distance,
      'day': day,
      'passed': passed,
      'weather': weather.index,
      'running': running,
      'gameOver': gameOver,
      'localCrashed': localCrashed,
      'remoteCrashed': remoteCrashed,
      'resultText': resultText,
      'cars': cars
          .map((e) => <String, dynamic>{
                'x': e.x,
                'y': e.y,
                'lane': e.lane,
                'factor': e.factor
              })
          .toList(),
    }, senderId: localPlayerId);
  }

  void _onNetworkMessage(NetworkMessage m) {
    if (!mounted ||
        m.senderId == localPlayerId ||
        m.type != NetworkMessageType.move) return;
    final action = m.payload['action']?.toString();
    if (action == 'road_start_request' && isHost) {
      start();
      return;
    }
    if (action == 'road_control' && isHost) {
      final x = (m.payload['x'] as num?)?.toDouble();
      if (x != null) {
        remoteX = x.clamp(.16, .84);
        setState(() {});
      }
      return;
    }
    if ((action == 'road_state' || action == 'road_start') && !isHost) {
      final rawCars = m.payload['cars'] as List<dynamic>? ?? const [];
      final oldWeather = weather;
      final oldDay = day;
      final wasCrashed = localCrashed;
      final wasGameOver = gameOver;
      setState(() {
        playerX = ((m.payload['remoteX'] as num?)?.toDouble() ?? playerX)
            .clamp(.16, .84);
        remoteX = ((m.payload['playerX'] as num?)?.toDouble() ?? remoteX)
            .clamp(.16, .84);
        score = (m.payload['score'] as num?)?.toInt() ?? score;
        distance = (m.payload['distance'] as num?)?.toInt() ?? distance;
        day = (m.payload['day'] as num?)?.toInt() ?? day;
        passed = (m.payload['passed'] as num?)?.toInt() ?? passed;
        final wi = (m.payload['weather'] as num?)?.toInt() ?? 0;
        weather = _Weather.values[wi.clamp(0, _Weather.values.length - 1)];
        running = m.payload['running'] == true;
        gameOver = m.payload['gameOver'] == true;
        localCrashed = m.payload['remoteCrashed'] == true;
        remoteCrashed = m.payload['localCrashed'] == true;
        final hostText = (m.payload['resultText'] ?? '').toString();
        resultText = hostText == 'فزت بالسباق'
            ? 'فاز اللاعب الآخر'
            : hostText == 'فاز اللاعب الآخر'
                ? 'فزت بالسباق'
                : hostText;
        cars
          ..clear()
          ..addAll(rawCars.whereType<Map>().map((e) => _Traffic(
              (e['x'] as num).toDouble(),
              (e['y'] as num).toDouble(),
              (e['lane'] as num).toInt(),
              (e['factor'] as num).toDouble())));
      });
      if (!wasCrashed && localCrashed) {
        _showEffect('💥 حادث!');
        GameFeedback.lose(GameAudioTheme.road);
      } else if (!wasGameOver && gameOver) {
        _showEffect(resultText);
        if (resultText == 'فزت بالسباق') {
          GameFeedback.win(GameAudioTheme.road);
        } else if (resultText.startsWith('تعادل')) {
          GameFeedback.tap(GameAudioTheme.road);
        } else {
          GameFeedback.lose(GameAudioTheme.road);
        }
      } else if (day > oldDay) {
        _showEffect('🏁 يوم جديد!');
        GameFeedback.win(GameAudioTheme.road);
      } else if (weather != oldWeather) {
        _showEffect('🌦 ' + weather.label);
        GameFeedback.tap(GameAudioTheme.road);
      }
    }
  }

  void _showEffect(String text) {
    if (!mounted) return;
    setState(() {
      effectText = text;
      effectVisible = true;
    });
    Future<void>.delayed(const Duration(milliseconds: 460), () {
      if (mounted) setState(() => effectVisible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 400;
    final progress = (passed / 40).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F5),
      appBar: AppBar(
        toolbarHeight: compact ? 36 : 48,
        title: const Text('طريق التحمل',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFFF1F5F5),
        foregroundColor: const Color(0xFF243D4A),
      ),
      body: SafeArea(
          child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _stat('النقاط', score),
              _stat('اليوم', day),
              _stat('الأفضل', best),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: const Color(0xFFD8E3E5),
                          color: const Color(0xFF398D96)))),
              const SizedBox(width: 10),
              Text(weather.label,
                  style: const TextStyle(
                      color: Color(0xFF496470),
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
        Expanded(
            child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
          child: LayoutBuilder(builder: (context, roadBox) {
            final geometry =
                RoadSceneGeometry(Size(roadBox.maxWidth, roadBox.maxHeight));
            void touch(Offset point) => dragRoad(
                geometry.worldXForTouch(point.dx) * roadBox.maxWidth,
                roadBox.maxWidth);
            return Stack(children: [
              Positioned.fill(
                  child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanDown: (d) => touch(d.localPosition),
                onPanUpdate: (d) => touch(d.localPosition),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: .5, end: playerX),
                  duration: const Duration(milliseconds: 190),
                  builder: (context, settlingX, child) => CustomPaint(
                    key: const ValueKey('road-scene'),
                    size: Size.infinite,
                    painter: RoadScenePainter(
                      playerX: playerX,
                      opponentX: isNetworkGame ? remoteX : null,
                      traffic: cars
                          .map((c) => RoadTrafficVisual(c.x, c.y, c.lane))
                          .toList(),
                      weather: RoadSceneWeather.values[weather.index],
                      travel: distance + tickCarry,
                      steer: (playerX - settlingX) * 1.5,
                    ),
                  ),
                ),
              )),
              Positioned.fill(
                  child: IgnorePointer(
                      child: AnimatedOpacity(
                opacity: effectVisible ? 1 : 0,
                duration: const Duration(milliseconds: 120),
                child: Align(
                    alignment: const Alignment(0, -.55),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                          color: const Color(0xEA253E4C),
                          borderRadius: BorderRadius.circular(12)),
                      child: Text(effectText,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                    )),
              ))),
              if (!running)
                Positioned.fill(
                    child: Center(
                        child: SingleChildScrollView(
                            child: Container(
                  margin: const EdgeInsets.all(12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  constraints: const BoxConstraints(maxWidth: 340),
                  decoration: BoxDecoration(
                      color: const Color(0xF0F5F8F6),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(color: Color(0x260C2531), blurRadius: 20)
                      ]),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(gameOver ? 'انتهى السباق' : 'جاهز للطريق؟',
                        style: const TextStyle(
                            color: Color(0xFF243D4A),
                            fontSize: 21,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text(
                        gameOver
                            ? (isNetworkGame ? resultText : 'نقاطك: $score')
                            : (isNetworkGame
                                ? 'سباق مباشر: تجنب السيارات وابقَ آخر سيارة'
                                : 'تجاوز 40 سيارة لتنتقل إلى يوم جديد'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xFF4F6671), fontSize: 12)),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                        onPressed: start,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(gameOver ? 'إعادة اللعب' : 'ابدأ')),
                  ]),
                )))),
            ]);
          }),
        )),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Row(children: [
              Expanded(
                  child: FilledButton.icon(
                      onPressed: running ? () => move(1) : null,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('يمين'))),
              const SizedBox(width: 10),
              Expanded(
                  child: FilledButton.icon(
                      onPressed: running ? () => move(-1) : null,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('يسار'))),
            ])),
      ])),
    );
  }

  Widget _stat(String label, int value) => Expanded(
      child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('$label: $value',
              style: const TextStyle(
                  color: Color(0xFF243D4A),
                  fontSize: 12,
                  fontWeight: FontWeight.w700))));
}
