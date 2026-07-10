import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/audio_feedback.dart';

class ChickenGameScreen extends StatefulWidget {
  const ChickenGameScreen({super.key});

  @override
  State<ChickenGameScreen> createState() => _ChickenGameScreenState();
}

class _ChickenGameScreenState extends State<ChickenGameScreen> {
  static const int _roundSeconds = 30;
  static const String _bestScoreKey = 'chicken_best_score';

  final Random _random = Random();
  Timer? _timer;
  Timer? _effectTimer;

  int score = 0;
  int bestScore = 0;
  int remainingSeconds = _roundSeconds;
  int chickenIndex = 0;
  int hits = 0;
  int attempts = 0;
  int combo = 0;
  int bestCombo = 0;
  bool isPlaying = false;
  bool isFinished = false;
  bool showFeathers = false;
  _ChickenKind currentChicken = _ChickenKind.white;

  final List<Alignment> positions = const [
    Alignment(-0.85, -0.65),
    Alignment(0.0, -0.55),
    Alignment(0.75, -0.35),
    Alignment(-0.55, 0.05),
    Alignment(0.45, 0.2),
    Alignment(-0.1, 0.62),
    Alignment(0.85, 0.67),
    Alignment(-0.75, 0.42),
    Alignment(0.18, -0.08),
    Alignment(-0.88, -0.05),
  ];

  int get level => isPlaying ? ((_roundSeconds - remainingSeconds) ~/ 5) + 1 : 1;

  int get moveDurationMs => max(105, 310 - (level * 28));

  int get accuracy {
    if (attempts == 0) return 0;
    return ((hits / attempts) * 100).round();
  }

  int get comboMultiplier {
    if (combo >= 6) return 3;
    if (combo >= 3) return 2;
    return 1;
  }

  @override
  void initState() {
    super.initState();
    _loadBestScore();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _effectTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      bestScore = prefs.getInt(_bestScoreKey) ?? 0;
    });
  }

  Future<void> _saveBestScore(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bestScoreKey, value);
  }

  void _startGame() {
    _timer?.cancel();
    _effectTimer?.cancel();
    setState(() {
      score = 0;
      remainingSeconds = _roundSeconds;
      chickenIndex = _random.nextInt(positions.length);
      currentChicken = _randomChicken();
      hits = 0;
      attempts = 0;
      combo = 0;
      bestCombo = 0;
      showFeathers = false;
      isPlaying = true;
      isFinished = false;
    });

    GameFeedback.tap();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        remainingSeconds--;
        if (remainingSeconds <= 0) {
          _finishGame(timer);
        }
      });
    });
  }

  void _finishGame(Timer timer) {
    timer.cancel();
    isPlaying = false;
    isFinished = true;
    if (score > bestScore) {
      bestScore = score;
      _saveBestScore(bestScore);
    }
    combo = 0;
    showFeathers = false;
    GameFeedback.win();
  }

  void _hitChicken() {
    if (!isPlaying) {
      _startGame();
      return;
    }

    final bool isWrongChicken = currentChicken.isPenalty;
    final int multiplier = comboMultiplier;
    final int urgentBonus = remainingSeconds <= 10 ? 5 : 0;
    final int earned = isWrongChicken ? currentChicken.points : (currentChicken.points + urgentBonus) * multiplier;

    _effectTimer?.cancel();
    setState(() {
      attempts++;
      if (isWrongChicken) {
        score = max(0, score + earned);
        combo = 0;
      } else {
        hits++;
        combo++;
        bestCombo = max(bestCombo, combo);
        score += earned;
      }
      showFeathers = true;
      chickenIndex = _nextChickenIndex();
      currentChicken = _randomChicken();
    });

    if (isWrongChicken) {
      GameFeedback.error();
    } else {
      GameFeedback.move();
    }

    _effectTimer = Timer(const Duration(milliseconds: 240), () {
      if (!mounted) return;
      setState(() => showFeathers = false);
    });
  }

  void _missTap() {
    if (!isPlaying) return;
    setState(() {
      attempts++;
      combo = 0;
    });
    GameFeedback.error();
  }

  int _nextChickenIndex() {
    if (positions.length == 1) return 0;

    int next = _random.nextInt(positions.length);
    while (next == chickenIndex) {
      next = _random.nextInt(positions.length);
    }
    return next;
  }

  _ChickenKind _randomChicken() {
    final int roll = _random.nextInt(100);
    if (level >= 3 && roll < 12) return _ChickenKind.red;
    if (roll >= 94) return _ChickenKind.gold;
    if (level >= 4 && roll >= 74) return _ChickenKind.black;
    if (level >= 2 && roll >= 48) return _ChickenKind.brown;
    return _ChickenKind.white;
  }

  void _resetGame() {
    _timer?.cancel();
    _effectTimer?.cancel();
    setState(() {
      score = 0;
      remainingSeconds = _roundSeconds;
      chickenIndex = 0;
      currentChicken = _ChickenKind.white;
      hits = 0;
      attempts = 0;
      combo = 0;
      bestCombo = 0;
      showFeathers = false;
      isPlaying = false;
      isFinished = false;
    });
  }

  String get _message {
    if (isFinished) return 'انتهى الوقت! النتيجة $score والدقة $accuracy%';
    if (!isPlaying) return 'اضغط على الدجاجة أو زر البدء لبدء الجولة';
    if (currentChicken.isPenalty) return 'انتبه! الدجاجة الحمراء تخصم نقاطًا — تجنبها';
    if (remainingSeconds <= 10) return 'الوقت قليل! كل إصابة تعطي نقاطًا إضافية';
    if (combo >= 6) return 'كومبو قوي ×3 — استمر بسرعة';
    if (combo >= 3) return 'كومبو ×2 — لا تضغط خارج الدجاجة';
    return 'المستوى $level — اضغط على الدجاجة الصحيحة';
  }

  Color get _timerColor {
    if (remainingSeconds <= 10) return const Color(0xFFE63946);
    if (remainingSeconds <= 20) return const Color(0xFFFF9F1C);
    return const Color(0xFF2A9D8F);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لعبة الدجاجة'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'إعادة',
            onPressed: _resetGame,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              children: [
                Expanded(child: _InfoBox(label: 'النقاط', value: '$score')),
                const SizedBox(width: 8),
                Expanded(child: _InfoBox(label: 'الوقت', value: '$remainingSeconds ث', valueColor: _timerColor)),
                const SizedBox(width: 8),
                Expanded(child: _InfoBox(label: 'الأفضل', value: '$bestScore')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Row(
              children: [
                Expanded(child: _InfoBox(label: 'المستوى', value: '$level')),
                const SizedBox(width: 8),
                Expanded(child: _InfoBox(label: 'كومبو', value: combo > 0 ? '×$comboMultiplier / $combo' : '0')),
                const SizedBox(width: 8),
                Expanded(child: _InfoBox(label: 'الدقة', value: '$accuracy%')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: currentChicken.softColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: currentChicken.color.withOpacity(0.55)),
              ),
              child: Text(
                _message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4D3B00)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF8ED1FC), Color(0xFFB7E4A7), Color(0xFF6AB04C)],
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _missTap,
                    child: Stack(
                      children: [
                        const Positioned(left: 18, bottom: 20, child: Text('🌾', style: TextStyle(fontSize: 46))),
                        const Positioned(right: 28, bottom: 34, child: Text('🌳', style: TextStyle(fontSize: 54))),
                        const Positioned(left: 38, top: 25, child: Text('☁️', style: TextStyle(fontSize: 38))),
                        const Positioned(right: 40, top: 54, child: Text('☀️', style: TextStyle(fontSize: 42))),
                        const Positioned(left: 70, bottom: 72, child: Text('🌻', style: TextStyle(fontSize: 34))),
                        const Positioned(right: 92, bottom: 92, child: Text('🪵', style: TextStyle(fontSize: 30))),
                        AnimatedAlign(
                          duration: Duration(milliseconds: moveDurationMs),
                          curve: Curves.easeOutBack,
                          alignment: positions[chickenIndex],
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _hitChicken,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (showFeathers)
                                  const SizedBox(
                                    width: 128,
                                    height: 128,
                                    child: Stack(
                                      children: [
                                        Positioned(left: 12, top: 8, child: Text('🪶', style: TextStyle(fontSize: 24))),
                                        Positioned(right: 8, top: 20, child: Text('🪶', style: TextStyle(fontSize: 22))),
                                        Positioned(left: 24, bottom: 4, child: Text('✨', style: TextStyle(fontSize: 24))),
                                      ],
                                    ),
                                  ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  width: isPlaying ? currentChicken.size : 104,
                                  height: isPlaying ? currentChicken.size : 104,
                                  decoration: BoxDecoration(
                                    color: isFinished ? Colors.white.withOpacity(0.94) : currentChicken.softColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: currentChicken.color, width: currentChicken == _ChickenKind.gold ? 5 : 3),
                                    boxShadow: [
                                      BoxShadow(color: currentChicken.color.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6)),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      isFinished ? '🏁' : currentChicken.emoji,
                                      style: TextStyle(fontSize: currentChicken == _ChickenKind.gold ? 54 : 58),
                                    ),
                                  ),
                                ),
                                if (isPlaying)
                                  Positioned(
                                    bottom: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.45),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${currentChicken.points > 0 ? '+' : ''}${currentChicken.points}',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (isFinished) _ResultPanel(score: score, bestScore: bestScore, hits: hits, accuracy: accuracy, bestCombo: bestCombo),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 12,
                          child: ElevatedButton.icon(
                            onPressed: _startGame,
                            icon: Icon(isPlaying ? Icons.restart_alt : Icons.play_arrow),
                            label: Text(isPlaying ? 'بدء جولة جديدة' : 'ابدأ اللعب'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChickenKind {
  const _ChickenKind({
    required this.name,
    required this.emoji,
    required this.points,
    required this.color,
    required this.softColor,
    required this.size,
    this.isPenalty = false,
  });

  final String name;
  final String emoji;
  final int points;
  final Color color;
  final Color softColor;
  final double size;
  final bool isPenalty;

  static const white = _ChickenKind(
    name: 'أبيض',
    emoji: '🐔',
    points: 10,
    color: Color(0xFFFFD166),
    softColor: Color(0xFFFFF7D6),
    size: 88,
  );

  static const brown = _ChickenKind(
    name: 'بني',
    emoji: '🐔',
    points: 20,
    color: Color(0xFFB5651D),
    softColor: Color(0xFFFFE0B2),
    size: 82,
  );

  static const black = _ChickenKind(
    name: 'أسود',
    emoji: '🐔',
    points: 35,
    color: Color(0xFF2D3436),
    softColor: Color(0xFFDDE1E4),
    size: 76,
  );

  static const gold = _ChickenKind(
    name: 'ذهبي',
    emoji: '🐥',
    points: 100,
    color: Color(0xFFFFB703),
    softColor: Color(0xFFFFF0A3),
    size: 72,
  );

  static const red = _ChickenKind(
    name: 'أحمر',
    emoji: '🐔',
    points: -30,
    color: Color(0xFFE63946),
    softColor: Color(0xFFFFD6D9),
    size: 80,
    isPenalty: true,
  );
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.score, required this.bestScore, required this.hits, required this.accuracy, required this.bestCombo});

  final int score;
  final int bestScore;
  final int hits;
  final int accuracy;
  final int bestCombo;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.30),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 8))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('نتيجة الجولة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniStat(label: 'النقاط', value: '$score'),
                    _MiniStat(label: 'الأفضل المحفوظ', value: '$bestScore'),
                    _MiniStat(label: 'الإصابات', value: '$hits'),
                    _MiniStat(label: 'الدقة', value: '$accuracy%'),
                    _MiniStat(label: 'أفضل كومبو', value: '$bestCombo'),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('سيبقى أفضل رقم محفوظًا بعد إغلاق التطبيق', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Column(
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: valueColor),
          ),
        ],
      ),
    );
  }
}
