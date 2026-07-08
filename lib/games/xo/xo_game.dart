import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/app_theme.dart';

enum XoCell { empty, x, o }

class XoGameScreen extends StatefulWidget {
  const XoGameScreen({super.key});

  @override
  State<XoGameScreen> createState() => _XoGameScreenState();
}

class _XoGameScreenState extends State<XoGameScreen> {
  List<XoCell> cells = List.filled(9, XoCell.empty);
  bool xTurn = true;
  bool playVsBot = true;
  bool botThinking = false;
  String message = 'أنت X - دورك';
  List<int> winLine = [];

  void reset() {
    setState(() {
      cells = List.filled(9, XoCell.empty);
      xTurn = true;
      botThinking = false;
      winLine = [];
      message = playVsBot ? 'أنت X - دورك' : 'دور X';
    });
  }

  void tapCell(int index) {
    if (cells[index] != XoCell.empty || winLine.isNotEmpty || botThinking) return;
    if (playVsBot && !xTurn) return;

    cells[index] = xTurn ? XoCell.x : XoCell.o;
    afterMove();
  }

  void afterMove() {
    final winner = findWinner();
    if (winner != null) {
      setState(() => message = winner == XoCell.x ? 'فاز X' : 'فاز O');
      return;
    }

    if (!cells.contains(XoCell.empty)) {
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
    if (!mounted) return;
    final move = chooseBotMove();
    if (move >= 0) {
      cells[move] = XoCell.o;
    }
    botThinking = false;
    afterMove();
  }

  int chooseBotMove() {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('إكس أو'),
        actions: [IconButton(onPressed: reset, icon: const Icon(Icons.refresh))],
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
        ],
      ),
    );
  }
}
