import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/app_settings.dart';
import '../../core/audio_feedback.dart';
import '../../design/app_theme.dart';
import '../../core/network/local_network_core.dart';
import '../../core/network/network_message.dart';

class DominoTile {
  const DominoTile(this.left, this.right);

  final int left;
  final int right;

  int get total => left + right;
  bool get isDouble => left == right;
  bool matches(int value) => left == value || right == value;
  DominoTile flipped() => DominoTile(right, left);

  @override
  String toString() => '$left|$right';
}

class DominoGameScreen extends StatefulWidget {
  const DominoGameScreen({super.key, this.networkCore});

  final LocalNetworkCore? networkCore;

  @override
  State<DominoGameScreen> createState() => _DominoGameScreenState();
}

class _DominoGameScreenState extends State<DominoGameScreen> {
  final AppSettingsController settings = AppSettingsController.instance;
  final Random random = Random();
  StreamSubscription<NetworkMessage>? networkSubscription;
  int roundSeed = 0;

  List<DominoTile> stock = [];
  List<DominoTile> player = [];
  List<DominoTile> bot = [];
  List<DominoTile> board = [];
  DominoTile? lastPlayedTile;
  bool playerTurn = true;
  bool roundFinished = false;
  int playerScore = 0;
  int botScore = 0;
  int roundNumber = 1;
  String message = 'دورك: اختر قطعة مناسبة';

  bool get isNetworkGame => widget.networkCore != null;
  bool get isHost => widget.networkCore?.state.mode == LocalNetworkMode.host;
  bool get isLocalTurn => isNetworkGame ? (isHost ? playerTurn : !playerTurn) : playerTurn;
  List<DominoTile> get localHand => isNetworkGame && !isHost ? bot : player;
  String get localPlayerId {
    final players = widget.networkCore?.state.players ?? const <LocalPlayer>[];
    final own = players.where((p) => p.isHost == isHost);
    return own.isNotEmpty ? own.first.id : (isHost ? 'host' : 'client');
  }

  @override
  void initState() {
    super.initState();
    networkSubscription = widget.networkCore?.messages.listen(_handleNetworkMessage);
    startRound(resetScore: true);
    if (isNetworkGame && isHost) Future<void>.delayed(const Duration(milliseconds: 250), _sendRoundStart);
  }

  @override
  void dispose() {
    networkSubscription?.cancel();
    super.dispose();
  }

  void startRound({bool resetScore = false, int? seed}) {
    final tiles = <DominoTile>[];
    for (int a = 0; a <= 6; a++) {
      for (int b = a; b <= 6; b++) {
        tiles.add(DominoTile(a, b));
      }
    }
    roundSeed = seed ?? random.nextInt(1 << 31);
    tiles.shuffle(Random(roundSeed));
    player = tiles.take(7).toList();
    bot = tiles.skip(7).take(7).toList();
    stock = tiles.skip(14).toList();
    board = [];
    lastPlayedTile = null;
    playerTurn = true;
    roundFinished = false;
    if (resetScore) {
      playerScore = 0;
      botScore = 0;
      roundNumber = 1;
    }
    message = isNetworkGame
        ? (isLocalTurn ? 'الجولة $roundNumber: دورك' : 'الجولة $roundNumber: بانتظار اللاعب الآخر')
        : 'الجولة $roundNumber: دورك، اختر قطعة مناسبة';
    setState(() {});
  }

  void _sendRoundStart() {
    if (!isNetworkGame || !isHost) return;
    widget.networkCore!.sendMove(<String, dynamic>{'game': 'domino', 'action': 'start', 'seed': roundSeed, 'round': roundNumber}, senderId: localPlayerId);
  }

  void _sendDominoAction(String action, {DominoTile? tile}) {
    if (!isNetworkGame) return;
    widget.networkCore!.sendMove(<String, dynamic>{
      'game': 'domino', 'action': action,
      if (tile != null) 'left': tile.left,
      if (tile != null) 'right': tile.right,
    }, senderId: localPlayerId);
  }

  void _handleNetworkMessage(NetworkMessage networkMessage) {
    if (!mounted || networkMessage.type != NetworkMessageType.move || networkMessage.senderId == localPlayerId || networkMessage.payload['game'] != 'domino') return;
    final payload = networkMessage.payload;
    final action = payload['action']?.toString();
    if (action == 'start') {
      startRound(resetScore: true, seed: (payload['seed'] as num?)?.toInt());
      return;
    }
    if (roundFinished) return;
    if (action == 'play') {
      final tile = DominoTile((payload['left'] as num).toInt(), (payload['right'] as num).toInt());
      final remoteHand = isHost ? bot : player;
      final index = remoteHand.indexWhere((t) => t.left == tile.left && t.right == tile.right);
      if (index < 0 || !canPlay(remoteHand[index])) return;
      placeTile(remoteHand[index], remoteHand);
      if (remoteHand.isEmpty) {
        finishRound(playerWon: !isHost, reason: 'اللاعب الآخر أنهى كل قطعه');
        return;
      }
      playerTurn = !playerTurn;
    } else if (action == 'draw' && stock.isNotEmpty) {
      (isHost ? bot : player).add(stock.removeLast());
    } else if (action == 'pass') {
      playerTurn = !playerTurn;
    }
    message = isLocalTurn ? 'دورك: اختر قطعة مناسبة' : 'بانتظار اللاعب الآخر';
    setState(() {});
  }

  int? get leftEnd => board.isEmpty ? null : board.first.left;
  int? get rightEnd => board.isEmpty ? null : board.last.right;

  List<DominoTile> get sortedPlayerHand {
    final list = List<DominoTile>.from(localHand);
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
    if (!isLocalTurn || roundFinished) return;
    if (!canPlay(tile)) {
      GameFeedback.error();
      setState(() => message = 'هذه القطعة لا تناسب الطرفين: $leftEnd أو $rightEnd');
      return;
    }
    GameFeedback.move();
    placeTile(tile, localHand);
    _sendDominoAction('play', tile: tile);
    if (localHand.isEmpty) {
      finishRound(playerWon: isHost || !isNetworkGame, reason: 'أنهيت كل قطعك');
      return;
    }
    if (isBlocked) {
      finishBlockedRound();
      return;
    }
    playerTurn = !playerTurn;
    message = isNetworkGame ? 'بانتظار اللاعب الآخر' : 'الكمبيوتر يفكر...';
    setState(() {});
    if (!isNetworkGame) Future<void>.delayed(const Duration(milliseconds: 550), botMove);
  }

  void drawTile() {
    if (!isLocalTurn || roundFinished) return;
    if (stock.isEmpty) {
      GameFeedback.error();
      setState(() => message = 'لا توجد قطع للسحب. مرر إذا لا تملك حركة');
      return;
    }
    GameFeedback.tap();
    localHand.add(stock.removeLast());
    _sendDominoAction('draw');
    message = localHand.any(canPlay) ? 'سحبت قطعة. القطع المناسبة أصبحت في أول يدك' : 'سحبت قطعة، ولا توجد حركة مناسبة بعد';
    setState(() {});
  }

  void passTurn() {
    if (!isLocalTurn || roundFinished) return;
    if (localHand.any(canPlay)) {
      GameFeedback.error();
      setState(() => message = 'لديك قطعة مناسبة بإطار ذهبي، لا يمكنك التمرير');
      return;
    }
    GameFeedback.tap();
    if (isBlocked) {
      finishBlockedRound();
      return;
    }
    playerTurn = !playerTurn;
    _sendDominoAction('pass');
    message = isNetworkGame ? 'مررت الدور. بانتظار اللاعب الآخر' : 'مررت الدور. الكمبيوتر يلعب...';
    setState(() {});
    if (!isNetworkGame) Future<void>.delayed(const Duration(milliseconds: 450), botMove);
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

    final chosen = chooseBotTile(playable);
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

  DominoTile chooseBotTile(List<DominoTile> playable) {
    switch (settings.botDifficulty) {
      case BotDifficulty.easy:
        return playable[random.nextInt(playable.length)];
      case BotDifficulty.normal:
        playable.sort((a, b) => b.total.compareTo(a.total));
        return playable.first;
      case BotDifficulty.hard:
        playable.sort((a, b) => scoreHardMove(b).compareTo(scoreHardMove(a)));
        return playable.first;
    }
  }

  int scoreHardMove(DominoTile tile) {
    if (board.isEmpty) return tile.total + (tile.isDouble ? 5 : 0);
    final scores = <int>[];
    if (tile.matches(leftEnd!)) {
      final newLeft = tile.right == leftEnd ? tile.left : tile.right;
      scores.add(scoreEndsAfterMove(tile, newLeft, rightEnd!));
    }
    if (tile.matches(rightEnd!)) {
      final newRight = tile.left == rightEnd ? tile.right : tile.left;
      scores.add(scoreEndsAfterMove(tile, leftEnd!, newRight));
    }
    return scores.isEmpty ? tile.total : scores.reduce(max);
  }

  int scoreEndsAfterMove(DominoTile tile, int newLeft, int newRight) {
    final botFutureOptions = bot.where((candidate) => candidate != tile && (candidate.matches(newLeft) || candidate.matches(newRight))).length;
    final playerLikelyOptions = player.where((candidate) => candidate.matches(newLeft) || candidate.matches(newRight)).length;
    return tile.total + (tile.isDouble ? 4 : 0) + (botFutureOptions * 3) - (playerLikelyOptions * 2);
  }

  void finishRound({required bool playerWon, required String reason}) {
    final points = playerWon ? pipsOf(bot) : pipsOf(player);
    if (playerWon) {
      playerScore += points;
      message = '$reason. فزت بالجولة وربحت $points نقطة';
      GameFeedback.win();
    } else {
      botScore += points;
      message = isNetworkGame ? '$reason. اللاعب الآخر ربح $points نقطة' : '$reason. الكمبيوتر ربح $points نقطة';
      GameFeedback.error();
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
      message = isNetworkGame ? 'اللعبة مغلقة. اللاعب الآخر قطعه أقل وربح $points نقطة' : 'اللعبة مغلقة. الكمبيوتر قطعُه أقل وربح $points نقطة';
      GameFeedback.error();
    } else {
      message = 'اللعبة مغلقة وتعادل بالنقاط';
      GameFeedback.tap();
    }
    setState(() {});
  }

  void nextRound() {
    if (isNetworkGame && !isHost) {
      setState(() => message = 'انتظر المضيف لبدء الجولة الجديدة');
      return;
    }
    GameFeedback.tap();
    roundNumber++;
    startRound();
    if (isNetworkGame) _sendRoundStart();
  }

  void placeTile(DominoTile tile, List<DominoTile> hand) {
    hand.remove(tile);
    if (board.isEmpty) {
      board.add(tile);
      lastPlayedTile = tile;
      return;
    }

    DominoTile placed = tile;
    if (tile.right == leftEnd) {
      placed = tile;
      board.insert(0, placed);
    } else if (tile.left == leftEnd) {
      placed = tile.flipped();
      board.insert(0, placed);
    } else if (tile.left == rightEnd) {
      placed = tile;
      board.add(placed);
    } else if (tile.right == rightEnd) {
      placed = tile.flipped();
      board.add(placed);
    }
    lastPlayedTile = placed;
  }

  List<Color> tableGradientColors() {
    switch (settings.tableColorIndex) {
      case 1:
        return const [Color(0xFF4A341D), Color(0xFF8B5E34)];
      case 2:
        return const [Color(0xFF102A55), Color(0xFF1E5AA8)];
      case 3:
        return const [Color(0xFF111827), Color(0xFF374151)];
      default:
        return const [Color(0xFF063B35), Color(0xFF0E6F63)];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final visibleBoard = board.length > 16 ? board.sublist(max(0, board.length - 16)) : board;
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
                    playerCount: localHand.length,
                    botCount: (isNetworkGame && !isHost ? player : bot).length,
                    stockCount: stock.length,
                    playableCount: playableCount,
                    botDifficultyText: settings.botDifficultyText,
                  ),
                  const SizedBox(height: 8),
                  _EndsBar(leftEnd: leftEnd, rightEnd: rightEnd),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: tableGradientColors()),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white.withOpacity(0.10)),
                      ),
                      child: board.isEmpty
                          ? const Center(child: Text('ابدأ بأي قطعة من يدك', style: TextStyle(color: Colors.white, fontSize: 18)))
                          : Column(
                              children: [
                                const Text('مسار الدومينو', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    runAlignment: WrapAlignment.center,
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      for (int i = 0; i < visibleBoard.length; i++)
                                        DominoTileView(
                                          tile: visibleBoard[i],
                                          compact: true,
                                          order: board.length - visibleBoard.length + i + 1,
                                          lastPlayed: visibleBoard[i].toString() == lastPlayedTile?.toString(),
                                        ),
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
                      Expanded(child: OutlinedButton.icon(onPressed: roundFinished ? null : drawTile, icon: const Icon(Icons.add), label: const Text('اسحب'))),
                      const SizedBox(width: 8),
                      Expanded(child: OutlinedButton.icon(onPressed: roundFinished ? nextRound : passTurn, icon: Icon(roundFinished ? Icons.play_arrow : Icons.skip_next), label: Text(roundFinished ? 'جولة جديدة' : 'تمرير'))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _PlayerHand(
                    tiles: sortedPlayerHand,
                    playerTurn: isLocalTurn,
                    roundFinished: roundFinished,
                    canPlay: canPlay,
                    onPlay: playPlayerTile,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlayerHand extends StatelessWidget {
  const _PlayerHand({required this.tiles, required this.playerTurn, required this.roundFinished, required this.canPlay, required this.onPlay});

  final List<DominoTile> tiles;
  final bool playerTurn;
  final bool roundFinished;
  final bool Function(DominoTile tile) canPlay;
  final void Function(DominoTile tile) onPlay;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = tiles.length > 8 || constraints.maxWidth < 360;
        return SizedBox(
          height: compact ? 138 : 152,
          child: Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: compact ? 4 : 6,
            runSpacing: compact ? 4 : 6,
            children: [
              for (final tile in tiles)
                Opacity(
                  opacity: playerTurn && !roundFinished && canPlay(tile) ? 1 : 0.38,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: playerTurn && !roundFinished && canPlay(tile) ? () => onPlay(tile) : null,
                    child: DominoTileView(tile: tile, compact: compact, playable: playerTurn && !roundFinished && canPlay(tile)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EndsBar extends StatelessWidget {
  const _EndsBar({required this.leftEnd, required this.rightEnd});
  final int? leftEnd;
  final int? rightEnd;

  @override
  Widget build(BuildContext context) {
    if (leftEnd == null || rightEnd == null) return const SizedBox.shrink();
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
  const _InfoPanel({required this.message, required this.playerScore, required this.botScore, required this.roundNumber, required this.playerCount, required this.botCount, required this.stockCount, required this.playableCount, required this.botDifficultyText});

  final String message;
  final int playerScore;
  final int botScore;
  final int roundNumber;
  final int playerCount;
  final int botCount;
  final int stockCount;
  final int playableCount;
  final String botDifficultyText;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(children: [const Icon(Icons.dashboard_customize, color: AppColors.primary), const SizedBox(width: 8), Expanded(child: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)))]),
            const SizedBox(height: 6),
            Align(alignment: Alignment.centerRight, child: Text('مستوى الكمبيوتر من الإعدادات: $botDifficultyText', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.bold, fontSize: 12))),
            const SizedBox(height: 8),
            Row(children: [_MiniStat(label: 'نقاطك', value: '$playerScore'), _MiniStat(label: 'خصمك', value: '$botScore'), _MiniStat(label: 'جولة', value: '$roundNumber')]),
            const SizedBox(height: 6),
            Row(children: [_MiniStat(label: 'قطعك', value: '$playerCount'), _MiniStat(label: 'مناسبة', value: '$playableCount'), _MiniStat(label: 'السحب', value: '$stockCount')]),
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
        child: Column(children: [Text(value, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryDark)), Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted))]),
      ),
    );
  }
}

class DominoTileView extends StatelessWidget {
  const DominoTileView({super.key, required this.tile, this.compact = false, this.playable = false, this.order, this.lastPlayed = false});

  final DominoTile tile;
  final bool compact;
  final bool playable;
  final int? order;
  final bool lastPlayed;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 40.0 : 54.0;
    final height = compact ? 62.0 : 92.0;
    final pipSize = compact ? 4.0 : 5.2;

    final borderColor = lastPlayed ? const Color(0xFF7B2CBF) : playable ? AppColors.accent : AppColors.primary.withOpacity(0.18);
    final borderWidth = lastPlayed ? 3.2 : playable ? 3.0 : 1.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Color(0xFFF2F2F2)]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: [BoxShadow(color: (lastPlayed ? const Color(0xFF7B2CBF) : playable ? AppColors.accent : Colors.black).withOpacity(0.32), blurRadius: lastPlayed || playable ? 11 : 6, offset: const Offset(0, 3))],
          ),
          child: Column(
            children: [
              Expanded(child: _PipFace(value: tile.left, pipSize: pipSize)),
              Container(height: 1.3, margin: const EdgeInsets.symmetric(horizontal: 5), color: AppColors.muted.withOpacity(0.55)),
              Expanded(child: _PipFace(value: tile.right, pipSize: pipSize)),
            ],
          ),
        ),
        if (order != null)
          Positioned(
            top: -5,
            right: -5,
            child: CircleAvatar(radius: 9, backgroundColor: lastPlayed ? const Color(0xFF7B2CBF) : AppColors.accent, child: Text('$order', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold))),
          ),
      ],
    );
  }
}

class _PipFace extends StatelessWidget {
  const _PipFace({required this.value, required this.pipSize});
  final int value;
  final double pipSize;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PipPainter(value: value, pipSize: pipSize),
      child: const SizedBox.expand(),
    );
  }
}

class _PipPainter extends CustomPainter {
  const _PipPainter({required this.value, required this.pipSize});
  final int value;
  final double pipSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.ink;
    final points = <Offset>[];
    final left = size.width * 0.28;
    final right = size.width * 0.72;
    final top = size.height * 0.28;
    final centerY = size.height * 0.50;
    final bottom = size.height * 0.72;
    final centerX = size.width * 0.50;

    switch (value) {
      case 1:
        points.add(Offset(centerX, centerY));
        break;
      case 2:
        points.addAll([Offset(left, top), Offset(right, bottom)]);
        break;
      case 3:
        points.addAll([Offset(left, top), Offset(centerX, centerY), Offset(right, bottom)]);
        break;
      case 4:
        points.addAll([Offset(left, top), Offset(right, top), Offset(left, bottom), Offset(right, bottom)]);
        break;
      case 5:
        points.addAll([Offset(left, top), Offset(right, top), Offset(centerX, centerY), Offset(left, bottom), Offset(right, bottom)]);
        break;
      case 6:
        points.addAll([Offset(left, top), Offset(right, top), Offset(left, centerY), Offset(right, centerY), Offset(left, bottom), Offset(right, bottom)]);
        break;
    }

    for (final point in points) {
      canvas.drawCircle(point, pipSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PipPainter oldDelegate) => oldDelegate.value != value || oldDelegate.pipSize != pipSize;
}
