import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/app_settings.dart';
import '../../design/app_theme.dart';

enum XoCell { empty, x, o }

class XoGameScreen extends StatefulWidget {
  const XoGameScreen({super.key});

  @override
  State<XoGameScreen> createState() => _XoGameScreenState();
}

class _XoGameScreenState extends State<XoGameScreen> {
  final AppSettingsController settings = AppSettingsController.instance;
  final Random random = Random();

  List<XoCell> cells = List.filled(9, XoCell.empty);
  bool xTurn = true;
  bool playVsBot = true;
  bool botThinking = false;
  String message = 'أنت X - دورك';
  List<int> winLine = [];
  int xWins = 0;
  int oWins = 0;
  int draws = 0;
  bool roundCounted = false;

  void reset() {
    setState(() {
      cells = List.filled(9, XoCell.empty);
      xTurn = true;
      botThinking = false;
      winLine = [];
      roundCounted = false;
      message = playVsBot ? 'أنت X - دورك' : 'دور X';
    });
  }

  void resetScore() {
    setState(() {
      xWins = 0;
      oWins = 0;
      draws = 0;
    });
    reset();
  }

  void tapCell(int index) {
    if (cells[index] != XoCell.empty || winLine.isNotEmpty || botThinking || roundCounted) return;
    if (playVsBot && !xTurn) return;

    cells[index] = xTurn ? XoCell.x : XoCell.o;
    afterMove();
  }

  void afterMove() {
    final winner = findWinner();
    if (winner != null) {
      if (!roundCounted) {
        if (winner == XoCell.x) {
          xWins++;
        } else {
          oWins++;
        }
        roundCounted = true;
      }
      setState(() => message = winner == XoCell.x ? 'فاز X' : 'فاز O');
      return;
    }

    if (!cells.contains(XoCell.empty)) {
      if (!roundCounted) {
        draws++;
        roundCounted = true;
      }
      setState(() => message = 'تعادل');
      return;
    }

    xTurn = !xTurn;
    message = playVsBot ? (xTurn ? 'أنت X - دورك' : 'الكمبيوتر يفكر...') : (xTurn ? 'دور X' : 'دور O');
    setState(() {});

    if (playVsBot && !xTurn) runBot();
  }

  Future<void> runBot() async {
    setState(() => botThinking = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted || roundCounted) return;
    final move = chooseBotMove();
    if (move >= 0) {
      cells[move] = XoCell.o;
    }
    botThinking = false;
    afterMove();
  }

  int chooseBotMove() {
    switch (settings.botDifficulty) {
      case BotDifficulty.easy:
        return chooseEasyBotMove();
      case BotDifficulty.normal:
        return chooseNormalBotMove();
      case BotDifficulty.hard:
        return chooseHardBotMove();
    }
  }

  int chooseEasyBotMove() {
    final empty = availableMoves();
    if (empty.isEmpty) return -1;
    return empty[random.nextInt(empty.length)];
  }

  int chooseNormalBotMove() {
    final win = findBestMoveFor(XoCell.o);
    if (win >= 0) return win;

    final block = findBestMoveFor(XoCell.x);
    if (block >= 0) return block;

    return chooseEasyBotMove();
  }

  int chooseHardBotMove() {
    final win = findBestMoveFor(XoCell.o);
    if (win >= 0) return win;

    final block = findBestMoveFor(XoCell.x);
    if (block >= 0) return block;

    if (cells[4] == XoCell.empty) return 4;

    for (final i in [0, 2, 6, 8]) {
      if (cells[i] == XoCell.empty) return i;
    }

    return cells.indexOf(XoCell.empty);
  }

  List<int> availableMoves() {
    final moves = <int>[];
    for (int i = 0; i < cells.length; i++) {
      if (cells[i] == XoCell.empty) moves.add(i);
    }
    return moves;
  }

  int findBestMoveFor(XoCell player) {
    for (int i = 0; i < 9; i++) {
      if (cells[i] != XoCell.empty) continue;
      final copy = List<XoCell>.from(cells);
      copy[i] = player;
      if (winnerOf(copy) == player) return i;
    }
    return -1;
  }

  XoCell? findWinner() {
    final lines = const [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6],
    ];

    for (final line in lines) {
      final a = cells[line[0]];
      if (a != XoCell.empty && a == cells[line[1]] && a == cells[line[2]]) {
        winLine = line;
        return a;
      }
    }
    return null;
  }

  XoCell? winnerOf(List<XoCell> board) {
    const lines = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6],
    ];
    for (final line in lines) {
      final a = board[line[0]];
      if (a != XoCell.empty && a == board[line[1]] && a == board[line[2]]) return a;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('إكس أو'),
            actions: [
              IconButton(onPressed: reset, tooltip: 'جولة جديدة', icon: const Icon(Icons.refresh)),
              IconButton(onPressed: resetScore, tooltip: 'تصفير النتائج', icon: const Icon(Icons.restart_alt)),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(playVsBot ? Icons.smart_toy : Icons.people, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(child: Text(message, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text('مستوى الكمبيوتر من الإعدادات: ${settings.botDifficultyText}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 14),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('لاعب ضد لاعب'), icon: Icon(Icons.people)),
                          ButtonSegment(value: true, label: Text('ضد الكمبيوتر'), icon: Icon(Icons.smart_toy)),
                        ],
                        selected: {playVsBot},
                        onSelectionChanged: (value) {
                          playVsBot = value.first;
                          reset();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _ScoreTile(label: 'X', value: xWins, color: AppColors.danger)),
                  const SizedBox(width: 8),
                  Expanded(child: _ScoreTile(label: 'تعادل', value: draws, color: AppColors.muted)),
                  const SizedBox(width: 8),
                  Expanded(child: _ScoreTile(label: 'O', value: oWins, color: AppColors.primaryDark)),
                ],
              ),
              const SizedBox(height: 22),
              AspectRatio(
                aspectRatio: 1,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10),
                  itemCount: 9,
                  itemBuilder: (context, index) {
                    final cell = cells[index];
                    final winning = winLine.contains(index);
                    return InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => tapCell(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: winning ? AppColors.accent : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                        ),
                        child: Center(
                          child: Text(
                            cell == XoCell.empty ? '' : (cell == XoCell.x ? 'X' : 'O'),
                            style: TextStyle(
                              fontSize: 54,
                              fontWeight: FontWeight.w900,
                              color: cell == XoCell.x ? AppColors.danger : AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: reset,
                icon: const Icon(Icons.play_arrow),
                label: const Text('جولة جديدة'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(
        children: [
          Text('$value', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}
