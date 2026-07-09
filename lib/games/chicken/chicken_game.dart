import 'dart:math';

import 'package:flutter/material.dart';

class ChickenGameScreen extends StatefulWidget {
  const ChickenGameScreen({super.key});

  @override
  State<ChickenGameScreen> createState() => _ChickenGameScreenState();
}

class _ChickenGameScreenState extends State<ChickenGameScreen> {
  final Random _random = Random();
  int score = 0;
  int chickenIndex = 0;

  final List<Alignment> positions = const [
    Alignment(-0.85, -0.65),
    Alignment(0.0, -0.55),
    Alignment(0.75, -0.35),
    Alignment(-0.55, 0.05),
    Alignment(0.45, 0.2),
    Alignment(-0.1, 0.62),
  ];

  void _hitChicken() {
    setState(() {
      score += 10;
      chickenIndex = _random.nextInt(positions.length);
    });
  }

  void _resetGame() {
    setState(() {
      score = 0;
      chickenIndex = 0;
    });
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
                Expanded(
                  child: _InfoBox(label: 'النقاط', value: '$score'),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: _InfoBox(label: 'الهدف', value: 'اضغط على الدجاجة'),
                ),
              ],
            ),
          ),
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
                child: Stack(
                  children: [
                    const Positioned(
                      left: 18,
                      bottom: 20,
                      child: Text('🌾', style: TextStyle(fontSize: 46)),
                    ),
                    const Positioned(
                      right: 28,
                      bottom: 34,
                      child: Text('🌳', style: TextStyle(fontSize: 54)),
                    ),
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutBack,
                      alignment: positions[chickenIndex],
                      child: GestureDetector(
                        onTap: _hitChicken,
                        child: Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.92),
                            shape: BoxShape.circle,
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 5))],
                          ),
                          child: const Center(child: Text('🐔', style: TextStyle(fontSize: 58))),
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 10,
                      child: Center(
                        child: Text(
                          'نسخة أولى بسيطة',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
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
  const _InfoBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }
}
