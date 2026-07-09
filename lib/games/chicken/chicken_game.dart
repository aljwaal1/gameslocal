import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class ChickenGameScreen extends StatefulWidget {
  const ChickenGameScreen({super.key});

  @override
  State<ChickenGameScreen> createState() => _ChickenGameScreenState();
}

class _ChickenGameScreenState extends State<ChickenGameScreen> {
  static const int _roundSeconds = 30;

  final Random _random = Random();
  Timer? _timer;

  int score = 0;
  int bestScore = 0;
  int remainingSeconds = _roundSeconds;
  int chickenIndex = 0;
  bool isPlaying = false;
  bool isFinished = false;

  final List<Alignment> positions = const [
    Alignment(-0.85, -0.65),
    Alignment(0.0, -0.55),
    Alignment(0.75, -0.35),
    Alignment(-0.55, 0.05),
    Alignment(0.45, 0.2),
    Alignment(-0.1, 0.62),
    Alignment(0.85, 0.67),
    Alignment(-0.75, 0.42),
  ];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startGame() {
    _timer?.cancel();
    setState(() {
      score = 0;
      remainingSeconds = _roundSeconds;
      chickenIndex = _random.nextInt(positions.length);
      isPlaying = true;
      isFinished = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        remainingSeconds--;
        if (remainingSeconds <= 0) {
          timer.cancel();
          isPlaying = false;
          isFinished = true;
          bestScore = max(bestScore, score);
        }
      });
    });
  }

  void _hitChicken() {
    if (!isPlaying) {
      _startGame();
      return;
    }

    setState(() {
      score += remainingSeconds <= 10 ? 15 : 10;
      chickenIndex = _nextChickenIndex();
    });
  }

  int _nextChickenIndex() {
    if (positions.length == 1) return 0;

    int next = _random.nextInt(positions.length);
    while (next == chickenIndex) {
      next = _random.nextInt(positions.length);
    }
    return next;
  }

  void _resetGame() {
    _timer?.cancel();
    setState(() {
      score = 0;
      remainingSeconds = _roundSeconds;
      chickenIndex = 0;
      isPlaying = false;
      isFinished = false;
    });
  }

  String get _message {
    if (isFinished) return 'انتهى الوقت! حاول تحطيم الرقم الأفضل';
    if (isPlaying) return remainingSeconds <= 10 ? 'الوقت قليل! النقاط مضاعفة' : 'اضغط بسرعة على الدجاجة';
    return 'اضغط على الدجاجة لبدء الجولة';
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
            padding: const EdgeInsets.all(12),
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
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFFD166)),
              ),
              child: Text(
                _message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6D4C00)),
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
                  child: Stack(
                    children: [
                      const Positioned(left: 18, bottom: 20, child: Text('🌾', style: TextStyle(fontSize: 46))),
                      const Positioned(right: 28, bottom: 34, child: Text('🌳', style: TextStyle(fontSize: 54))),
                      const Positioned(left: 36, top: 28, child: Text('☁️', style: TextStyle(fontSize: 38))),
                      const Positioned(right: 40, top: 54, child: Text('☀️', style: TextStyle(fontSize: 42))),
                      AnimatedAlign(
                        duration: Duration(milliseconds: isPlaying ? 210 : 320),
                        curve: Curves.easeOutBack,
                        alignment: positions[chickenIndex],
                        child: GestureDetector(
                          onTap: _hitChicken,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: isPlaying ? 86 : 104,
                            height: isPlaying ? 86 : 104,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.94),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFFFD166), width: 3),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 5))],
                            ),
                            child: Center(child: Text(isFinished ? '🏁' : '🐔', style: const TextStyle(fontSize: 58))),
                          ),
                        ),
                      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Column(
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: valueColor),
          ),
        ],
      ),
    );
  }
}
