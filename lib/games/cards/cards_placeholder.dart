import 'dart:math';

import 'package:flutter/material.dart';

import '../../design/app_theme.dart';

class CardsPlaceholderScreen extends StatefulWidget {
  const CardsPlaceholderScreen({super.key});

  @override
  State<CardsPlaceholderScreen> createState() => _CardsPlaceholderScreenState();
}

class _MemoryCard {
  const _MemoryCard({required this.id, required this.symbol});

  final int id;
  final String symbol;
}

class _CardsPlaceholderScreenState extends State<CardsPlaceholderScreen> {
  final Random _random = Random();
  late List<_MemoryCard> cards;
  final Set<int> opened = <int>{};
  final Set<int> matched = <int>{};
  int? firstIndex;
  bool locked = false;
  int moves = 0;
  int wins = 0;

  @override
  void initState() {
    super.initState();
    _newRound(resetScore: true);
  }

  void _newRound({bool resetScore = false}) {
    const symbols = ['A', 'K', 'Q', 'J', '10', '9'];
    final deck = <_MemoryCard>[];
    var id = 0;
    for (final symbol in symbols) {
      deck.add(_MemoryCard(id: id++, symbol: symbol));
      deck.add(_MemoryCard(id: id++, symbol: symbol));
    }
    deck.shuffle(_random);

    setState(() {
      cards = deck;
      opened.clear();
      matched.clear();
      firstIndex = null;
      locked = false;
      moves = 0;
      if (resetScore) wins = 0;
    });
  }

  Future<void> _tapCard(int index) async {
    if (locked || opened.contains(index) || matched.contains(index)) return;

    setState(() {
      opened.add(index);
    });

    if (firstIndex == null) {
      firstIndex = index;
      return;
    }

    moves++;
    final previous = firstIndex!;
    firstIndex = null;

    if (cards[previous].symbol == cards[index].symbol) {
      setState(() {
        matched.add(previous);
        matched.add(index);
        if (matched.length == cards.length) wins++;
      });
      return;
    }

    locked = true;
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      opened.remove(previous);
      opened.remove(index);
      locked = false;
    });
  }

  bool _isVisible(int index) => opened.contains(index) || matched.contains(index);
  bool get _finished => matched.length == cards.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الشدة / ذاكرة البطاقات'),
        actions: [
          IconButton(
            tooltip: 'تصفير',
            onPressed: () => _newRound(resetScore: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.style, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _finished ? 'ممتاز! أنهيت الجولة' : 'افتح بطاقتين متشابهتين',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('الحركات: $moves'),
                          Text('الأزواج: ${matched.length ~/ 2} / ${cards.length ~/ 2}'),
                          Text('الفوز: $wins'),
                        ],
                      ),
                      if (_finished) ...[
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _newRound(),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('جولة جديدة'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                itemCount: cards.length,
                itemBuilder: (context, index) {
                  final visible = _isVisible(index);
                  final done = matched.contains(index);
                  return InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => _tapCard(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: visible ? Colors.white : AppColors.primary,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: done ? AppColors.success : AppColors.primary.withOpacity(0.25), width: 2),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
                      ),
                      child: Center(
                        child: Text(
                          visible ? cards[index].symbol : '★',
                          style: TextStyle(
                            fontSize: visible ? 34 : 30,
                            fontWeight: FontWeight.bold,
                            color: visible ? AppColors.ink : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
