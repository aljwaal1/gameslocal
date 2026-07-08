import 'dart:math';

import 'package:flutter/material.dart';

import '../../design/app_theme.dart';

class DominoTile {
  const DominoTile(this.left, this.right);

  final int left;
  final int right;

  int get total => left + right;
  bool matches(int value) => left == value || right == value;
  DominoTile flipped() => DominoTile(right, left);

  @override
  String toString() => '$left|$right';
}

class DominoGameScreen extends StatefulWidget {
  const DominoGameScreen({super.key});

  @override
  State<DominoGameScreen> createState() => _DominoGameScreenState();
}

class _DominoGameScreenState extends State<DominoGameScreen> {
  final Random random = Random();
  List<DominoTile> stock = [];
  List<DominoTile> player = [];
  List<DominoTile> bot = [];
  List<DominoTile> board = [];
  bool playerTurn = true;
  String message = 'دورك: اختر قطعة مناسبة';

  @override
  void initState() {
    super.initState();
    newGame();
  }

  void newGame() {
    final tiles = <DominoTile>[];
    for (int a = 0; a <= 6; a++) {
      for (int b = a; b <= 6; b++) {
        tiles.add(DominoTile(a, b));
      }
    }
    tiles.shuffle(random);
    player = tiles.take(7).toList();
    bot = tiles.skip(7).take(7).toList();
    stock = tiles.skip(14).toList();
    board = [];
    playerTurn = true;
    message = 'دورك: اختر قطعة مناسبة';
    setState(() {});
  }

  int? get leftEnd => board.isEmpty ? null : board.first.left;
  int? get rightEnd => board.isEmpty ? null : board.last.right;

  bool canPlay(DominoTile tile) {
    if (board.isEmpty) return true;
    return tile.matches(leftEnd!) || tile.matches(rightEnd!);
  }

  void playPlayerTile(DominoTile tile) {
    if (!playerTurn) return;
    if (!canPlay(tile)) {
      setState(() => message = 'هذه القطعة لا تناسب طرفي الدومينو');
      return;
    }
    placeTile(tile, player);
    if (player.isEmpty) {
      setState(() => message = 'فزت في الدومينو!');
      return;
    }
    playerTurn = false;
    message = 'الكمبيوتر يفكر...';
    setState(() {});
    Future<void>.delayed(const Duration(milliseconds: 550), botMove);
  }

  void drawTile() {
    if (!playerTurn || stock.isEmpty) return;
    player.add(stock.removeLast());
    message = 'سحبت قطعة جديدة';
    setState(() {});
  }

  void passTurn() {
    if (!playerTurn) return;
    if (player.any(canPlay)) {
      setState(() => message = 'لديك قطعة مناسبة، لا يمكنك التمرير الآن');
      return;
    }
    playerTurn = false;
    message = 'مررت الدور. الكمبيوتر يلعب...';
    setState(() {});
    Future<void>.delayed(const Duration(milliseconds: 450), botMove);
  }

  void botMove() {
    final playable = bot.where(canPlay).toList();
    if (playable.isEmpty) {
      if (stock.isNotEmpty) {
        bot.add(stock.removeLast());
        message = 'الكمبيوتر سحب قطعة. دورك';
      } else {
        message = 'الكمبيوتر مرر الدور. دورك';
      }
      playerTurn = true;
      setState(() {});
      return;
    }

    playable.sort((a, b) => b.total.compareTo(a.total));
    final chosen = playable.first;
    placeTile(chosen, bot);
    if (bot.isEmpty) {
      setState(() => message = 'فاز الكمبيوتر في الدومينو');
      return;
    }
    playerTurn = true;
    message = 'دورك: اختر قطعة مناسبة';
    setState(() {});
  }

  void placeTile(DominoTile tile, List<DominoTile> hand) {
    hand.remove(tile);
    if (board.isEmpty) {
      board.add(tile);
      return;
    }

    if (tile.right == leftEnd) {
      board.insert(0, tile);
    } else if (tile.left == leftEnd) {
      board.insert(0, tile.flipped());
    } else if (tile.left == rightEnd) {
      board.add(tile);
    } else if (tile.right == rightEnd) {
      board.add(tile.flipped());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدومينو'),
        actions: [IconButton(onPressed: newGame, icon: const Icon(Icons.refresh))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.dashboard_customize, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(child: Text(message, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('قطعك: ${player.length}'),
                        Text('الكمبيوتر: ${bot.length}'),
                        Text('السحب: ${stock.length}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(24),
              ),
              child: board.isEmpty
                  ? const Center(child: Text('ابدأ بوضع أي قطعة', style: TextStyle(color: Colors.white, fontSize: 18)))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: board.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => Center(child: DominoTileView(tile: board[i])),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: drawTile,
                    icon: const Icon(Icons.add),
                    label: const Text('اسحب'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: passTurn,
                    icon: const Icon(Icons.skip_next),
                    label: const Text('تمرير'),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 122,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              scrollDirection: Axis.horizontal,
              itemCount: player.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final tile = player[i];
                final enabled = playerTurn && canPlay(tile);
                return Opacity(
                  opacity: enabled ? 1 : 0.45,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => playPlayerTile(tile),
                    child: DominoTileView(tile: tile),
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

class DominoTileView extends StatelessWidget {
  const DominoTileView({super.key, required this.tile});

  final DominoTile tile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 92,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          Expanded(child: Center(child: Text('${tile.left}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)))),
          Container(height: 1.5, color: AppColors.muted.withOpacity(0.5)),
          Expanded(child: Center(child: Text('${tile.right}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }
}
