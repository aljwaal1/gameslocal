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
  bool roundFinished = false;
  int playerScore = 0;
  int botScore = 0;
  int roundNumber = 1;
  String message = 'دورك: اختر قطعة مناسبة';

  @override
  void initState() {
    super.initState();
    startRound(resetScore: true);
  }

  void startRound({bool resetScore = false}) {
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
    roundFinished = false;
    if (resetScore) {
      playerScore = 0;
      botScore = 0;
      roundNumber = 1;
    }
    message = 'الجولة $roundNumber: دورك، اختر قطعة مناسبة';
    setState(() {});
  }

  int? get leftEnd => board.isEmpty ? null : board.first.left;
  int? get rightEnd => board.isEmpty ? null : board.last.right;

  int pipsOf(List<DominoTile> hand) => hand.fold(0, (sum, tile) => sum + tile.total);

  bool canPlay(DominoTile tile) {
    if (board.isEmpty) return true;
    return tile.matches(leftEnd!) || tile.matches(rightEnd!);
  }

  bool get isBlocked {
    if (board.isEmpty || stock.isNotEmpty) return false;
    return !player.any(canPlay) && !bot.any(canPlay);
  }

  void playPlayerTile(DominoTile tile) {
    if (!playerTurn || roundFinished) return;
    if (!canPlay(tile)) {
      setState(() => message = 'هذه القطعة لا تناسب طرفي الدومينو');
      return;
    }
    placeTile(tile, player);
    if (player.isEmpty) {
      finishRound(playerWon: true, reason: 'أنهيت كل قطعك');
      return;
    }
    if (isBlocked) {
      finishBlockedRound();
      return;
    }
    playerTurn = false;
    message = 'الكمبيوتر يفكر...';
    setState(() {});
    Future<void>.delayed(const Duration(milliseconds: 550), botMove);
  }

  void drawTile() {
    if (!playerTurn || roundFinished) return;
    if (stock.isEmpty) {
      setState(() => message = 'لا توجد قطع للسحب. مرر إذا لا تملك حركة');
      return;
    }
    player.add(stock.removeLast());
    message = player.any(canPlay) ? 'سحبت قطعة. يمكنك اللعب الآن' : 'سحبت قطعة، ولا توجد حركة مناسبة بعد';
    setState(() {});
  }

  void passTurn() {
    if (!playerTurn || roundFinished) return;
    if (player.any(canPlay)) {
      setState(() => message = 'لديك قطعة مناسبة، لا يمكنك التمرير الآن');
      return;
    }
    if (isBlocked) {
      finishBlockedRound();
      return;
    }
    playerTurn = false;
    message = 'مررت الدور. الكمبيوتر يلعب...';
    setState(() {});
    Future<void>.delayed(const Duration(milliseconds: 450), botMove);
  }

  void botMove() {
    if (roundFinished) return;
    final playable = bot.where(canPlay).toList();
    if (playable.isEmpty) {
      if (stock.isNotEmpty) {
        bot.add(stock.removeLast());
        message = 'الكمبيوتر سحب قطعة. دورك';
      } else if (isBlocked) {
        finishBlockedRound();
        return;
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
      finishRound(playerWon: false, reason: 'الكمبيوتر أنهى كل قطعه');
      return;
    }
    if (isBlocked) {
      finishBlockedRound();
      return;
    }
    playerTurn = true;
    message = 'دورك: اختر قطعة مناسبة';
    setState(() {});
  }

  void finishRound({required bool playerWon, required String reason}) {
    final points = playerWon ? pipsOf(bot) : pipsOf(player);
    if (playerWon) {
      playerScore += points;
      message = '$reason. فزت بالجولة وربحت $points نقطة';
    } else {
      botScore += points;
      message = '$reason. الكمبيوتر ربح $points نقطة';
    }
    roundFinished = true;
    setState(() {});
  }

  void finishBlockedRound() {
    final playerPips = pipsOf(player);
    final botPips = pipsOf(bot);
    roundFinished = true;
    if (playerPips < botPips) {
      final points = botPips - playerPips;
      playerScore += points;
      message = 'اللعبة مغلقة. قطعك أقل، فزت بـ $points نقطة';
    } else if (botPips < playerPips) {
      final points = playerPips - botPips;
      botScore += points;
      message = 'اللعبة مغلقة. الكمبيوتر قطعُه أقل وربح $points نقطة';
    } else {
      message = 'اللعبة مغلقة وتعادل بالنقاط';
    }
    setState(() {});
  }

  void nextRound() {
    roundNumber++;
    startRound();
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
        actions: [IconButton(onPressed: () => startRound(resetScore: true), icon: const Icon(Icons.refresh))],
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
                        Text('نقاطك: $playerScore'),
                        Text('الكمبيوتر: $botScore'),
                        Text('الجولة: $roundNumber'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('قطعك: ${player.length}'),
                        Text('قطع الكمبيوتر: ${bot.length}'),
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
                    onPressed: roundFinished ? null : drawTile,
                    icon: const Icon(Icons.add),
                    label: const Text('اسحب'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: roundFinished ? nextRound : passTurn,
                    icon: Icon(roundFinished ? Icons.play_arrow : Icons.skip_next),
                    label: Text(roundFinished ? 'جولة جديدة' : 'تمرير'),
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
                final enabled = playerTurn && !roundFinished && canPlay(tile);
                return Opacity(
                  opacity: enabled ? 1 : 0.45,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: enabled ? () => playPlayerTile(tile) : null,
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
