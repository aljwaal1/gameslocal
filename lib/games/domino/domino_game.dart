import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/audio_feedback.dart';
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

  List<DominoTile> get sortedPlayerHand {
    final list = List<DominoTile>.from(player);
    list.sort((a, b) {
      final ap = canPlay(a) ? 0 : 1;
      final bp = canPlay(b) ? 0 : 1;
      if (ap != bp) return ap.compareTo(bp);
      return b.total.compareTo(a.total);
    });
    return list;
  }

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
      GameFeedback.error();
      setState(() => message = 'هذه القطعة لا تناسب الطرفين: $leftEnd أو $rightEnd');
      return;
    }
    GameFeedback.move();
    placeTile(tile, player);
    if (player.isEmpty) {
      GameFeedback.win();
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
      GameFeedback.error();
      setState(() => message = 'لا توجد قطع للسحب. مرر إذا لا تملك حركة');
      return;
    }
    GameFeedback.tap();
    player.add(stock.removeLast());
    message = player.any(canPlay) ? 'سحبت قطعة. القطع المناسبة أصبحت في أول يدك' : 'سحبت قطعة، ولا توجد حركة مناسبة بعد';
    setState(() {});
  }

  void passTurn() {
    if (!playerTurn || roundFinished) return;
    if (player.any(canPlay)) {
      GameFeedback.error();
      setState(() => message = 'لديك قطعة مناسبة بإطار ذهبي، لا يمكنك التمرير');
      return;
    }
    GameFeedback.tap();
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
    GameFeedback.move();
    if (bot.isEmpty) {
      finishRound(playerWon: false, reason: 'الكمبيوتر أنهى كل قطعه');
      return;
    }
    if (isBlocked) {
      finishBlockedRound();
      return;
    }
    playerTurn = true;
    message = 'دورك: اختر قطعة بإطار ذهبي';
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
      GameFeedback.win();
    } else if (botPips < playerPips) {
      final points = playerPips - botPips;
      botScore += points;
      message = 'اللعبة مغلقة. الكمبيوتر قطعُه أقل وربح $points نقطة';
      GameFeedback.error();
    } else {
      message = 'اللعبة مغلقة وتعادل بالنقاط';
      GameFeedback.tap();
    }
    setState(() {});
  }

  void nextRound() {
    GameFeedback.tap();
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
    final visibleBoard = board.length > 14 ? board.sublist(max(0, board.length - 14)) : board;
    final playableCount = player.where(canPlay).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الدومينو'),
        actions: [IconButton(onPressed: () => startRound(resetScore: true), icon: const Icon(Icons.refresh))],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          child: Column(
            children: [
              _InfoPanel(
                message: message,
                playerScore: playerScore,
                botScore: botScore,
                roundNumber: roundNumber,
                playerCount: player.length,
                botCount: bot.length,
                stockCount: stock.length,
                playableCount: playableCount,
              ),
              const SizedBox(height: 8),
              _EndsBar(leftEnd: leftEnd, rightEnd: rightEnd),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [Color(0xFF063B35), Color(0xFF0E6F63)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: board.isEmpty
                      ? const Center(child: Text('ابدأ بأي قطعة من يدك', style: TextStyle(color: Colors.white, fontSize: 18)))
                      : Column(
                          children: [
                            const Text('مسار الدومينو من اليسار إلى اليمين', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 6),
                            Expanded(
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                runAlignment: WrapAlignment.center,
                                spacing: 5,
                                runSpacing: 5,
                                children: [
                                  for (int i = 0; i < visibleBoard.length; i++) DominoTileView(tile: visibleBoard[i], compact: true, order: board.length - visibleBoard.length + i + 1),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
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
              const SizedBox(height: 6),
              SizedBox(
                height: 150,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  runAlignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tile in sortedPlayerHand)
                      Opacity(
                        opacity: playerTurn && !roundFinished && canPlay(tile) ? 1 : 0.38,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: playerTurn && !roundFinished && canPlay(tile) ? () => playPlayerTile(tile) : null,
                          child: DominoTileView(tile: tile, compact: true, playable: playerTurn && !roundFinished && canPlay(tile)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EndsBar extends StatelessWidget {
  const _EndsBar({required this.leftEnd, required this.rightEnd});
  final int? leftEnd;
  final int? rightEnd;

  @override
  Widget build(BuildContext context) {
    if (leftEnd == null || rightEnd == null) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        Expanded(child: _EndBox(label: 'طرف اليسار', value: leftEnd!)),
        const SizedBox(width: 8),
        const Icon(Icons.compare_arrows, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(child: _EndBox(label: 'طرف اليمين', value: rightEnd!)),
      ],
    );
  }
}

class _EndBox extends StatelessWidget {
  const _EndBox({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.22), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.accent)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(width: 8),
          CircleAvatar(radius: 14, backgroundColor: AppColors.accent, child: Text('$value', style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.message,
    required this.playerScore,
    required this.botScore,
    required this.roundNumber,
    required this.playerCount,
    required this.botCount,
    required this.stockCount,
    required this.playableCount,
  });

  final String message;
  final int playerScore;
  final int botScore;
  final int roundNumber;
  final int playerCount;
  final int botCount;
  final int stockCount;
  final int playableCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.dashboard_customize, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _MiniStat(label: 'نقاطك', value: '$playerScore'),
                _MiniStat(label: 'خصمك', value: '$botScore'),
                _MiniStat(label: 'جولة', value: '$roundNumber'),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _MiniStat(label: 'قطعك', value: '$playerCount'),
                _MiniStat(label: 'مناسبة', value: '$playableCount'),
                _MiniStat(label: 'السحب', value: '$stockCount'),
              ],
            ),
          ],
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
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class DominoTileView extends StatelessWidget {
  const DominoTileView({super.key, required this.tile, this.compact = false, this.playable = false, this.order});

  final DominoTile tile;
  final bool compact;
  final bool playable;
  final int? order;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 42.0 : 54.0;
    final height = compact ? 66.0 : 92.0;
    final fontSize = compact ? 18.0 : 24.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: playable ? AppColors.accent : AppColors.primary.withOpacity(0.18), width: playable ? 3 : 1),
            boxShadow: [BoxShadow(color: playable ? AppColors.accent.withOpacity(0.45) : Colors.black26, blurRadius: playable ? 10 : 6, offset: const Offset(0, 3))],
          ),
          child: Column(
            children: [
              Expanded(child: Center(child: Text('${tile.left}', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: AppColors.ink)))),
              Container(height: 1.2, color: AppColors.muted.withOpacity(0.5)),
              Expanded(child: Center(child: Text('${tile.right}', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: AppColors.ink)))),
            ],
          ),
        ),
        if (order != null)
          Positioned(
            top: -5,
            right: -5,
            child: CircleAvatar(
              radius: 9,
              backgroundColor: AppColors.accent,
              child: Text('$order', style: const TextStyle(fontSize: 9, color: AppColors.ink, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }
}
