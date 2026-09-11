import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/app_settings.dart';
import '../../core/audio_feedback.dart';
import '../../core/network/local_network_core.dart';
import '../../core/network/network_message.dart';
import 'domino_four_player_game.dart';
import 'domino_starting_player.dart';

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
  final settings = AppSettingsController.instance;
  final random = Random();
  StreamSubscription<NetworkMessage>? networkSubscription;
  int roundSeed = 0;
  List<DominoTile> stock = <DominoTile>[];
  List<DominoTile> player = <DominoTile>[];
  List<DominoTile> bot = <DominoTile>[];
  List<DominoTile> board = <DominoTile>[];
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
  List<DominoTile> get remoteHand => isNetworkGame && !isHost ? player : bot;
  String get localPlayerId {
    final players = widget.networkCore?.state.players ?? const <LocalPlayer>[];
    final own = players.where((p) => p.isHost == isHost);
    return own.isNotEmpty ? own.first.id : (isHost ? 'host' : 'client');
  }
  String get opponentName {
    if (!isNetworkGame) return 'الروبوت';
    final players = widget.networkCore?.state.players ?? const <LocalPlayer>[];
    final other = players.where((p) => p.isHost != isHost);
    return other.isNotEmpty ? other.first.name : 'اللاعب الآخر';
  }

  @override
  void initState() {
    super.initState();
    networkSubscription = widget.networkCore?.messages.listen(_handleNetworkMessage);
    startRound(resetScore: true);
    if (isNetworkGame && isHost) {
      Future<void>.delayed(const Duration(milliseconds: 250), _sendRoundStart);
    } else if (isNetworkGame) {
      Future<void>.delayed(const Duration(milliseconds: 300), _requestRoundState);
    }
  }

  @override
  void dispose() {
    networkSubscription?.cancel();
    super.dispose();
  }

  void startRound({bool resetScore = false, int? seed, int? round}) {
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
    board = <DominoTile>[];
    lastPlayedTile = null;
    playerTurn = selectDominoStartingPlayer(<List<(int, int)>>[
          player.map((t) => (t.left, t.right)).toList(growable: false),
          bot.map((t) => (t.left, t.right)).toList(growable: false),
        ]) == 0;
    roundFinished = false;
    if (resetScore) {
      playerScore = 0;
      botScore = 0;
    }
    roundNumber = round ?? (resetScore ? 1 : roundNumber);
    message = isNetworkGame
        ? (isLocalTurn ? 'الجولة $roundNumber: دورك' : 'الجولة $roundNumber: بانتظار اللاعب الآخر')
        : (playerTurn ? 'الجولة $roundNumber: دورك، اختر قطعة مناسبة' : 'الجولة $roundNumber: الكمبيوتر يبدأ...');
    setState(() {});
    if (!isNetworkGame && !playerTurn) {
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !roundFinished && !playerTurn) botMove();
      });
    }
  }

  void _requestRoundState() {
    if (!isNetworkGame) return;
    widget.networkCore!.sendMove(<String, dynamic>{'game': 'domino', 'action': 'stateRequest'}, senderId: localPlayerId);
  }

  void _sendRoundStart() {
    if (!isNetworkGame || !isHost) return;
    widget.networkCore!.sendMove(<String, dynamic>{
      'game': 'domino', 'action': 'start', 'seed': roundSeed, 'round': roundNumber,
    }, senderId: localPlayerId);
  }

  void _sendDominoAction(String action, {DominoTile? tile}) {
    if (!isNetworkGame) return;
    widget.networkCore!.sendMove(<String, dynamic>{
      'game': 'domino', 'action': action,
      if (tile != null) 'left': tile.left,
      if (tile != null) 'right': tile.right,
    }, senderId: localPlayerId);
  }

  void _handleNetworkMessage(NetworkMessage msg) {
    if (!mounted || msg.type != NetworkMessageType.move || msg.senderId == localPlayerId || msg.payload['game'] != 'domino') return;
    final payload = msg.payload;
    final action = payload['action']?.toString();
    if (action == 'stateRequest') {
      if (isHost) _sendRoundStart();
      return;
    }
    if (action == 'start') {
      startRound(
        resetScore: ((payload['round'] as num?)?.toInt() ?? 1) == 1,
        seed: (payload['seed'] as num?)?.toInt(),
        round: (payload['round'] as num?)?.toInt(),
      );
      return;
    }
    if (roundFinished) return;
    if (action == 'play') {
      final tile = DominoTile((payload['left'] as num).toInt(), (payload['right'] as num).toInt());
      final hand = isHost ? bot : player;
      final index = hand.indexWhere((t) => t.left == tile.left && t.right == tile.right);
      if (index < 0 || !canPlay(hand[index])) return;
      placeTile(hand[index], hand);
      if (hand.isEmpty) {
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
  bool canPlay(DominoTile tile) => board.isEmpty || tile.matches(leftEnd!) || tile.matches(rightEnd!);
  bool get isBlocked => board.isNotEmpty && stock.isEmpty && !player.any(canPlay) && !bot.any(canPlay);

  void playPlayerTile(DominoTile tile) {
    if (!isLocalTurn || roundFinished) return;
    if (!canPlay(tile)) {
      GameFeedback.error(GameAudioTheme.domino);
      setState(() => message = 'هذه القطعة لا تناسب الطرفين: $leftEnd أو $rightEnd');
      return;
    }
    GameFeedback.move(GameAudioTheme.domino);
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
      GameFeedback.error(GameAudioTheme.domino);
      setState(() => message = 'لا توجد قطع للسحب. مرر إذا لا تملك حركة');
      return;
    }
    GameFeedback.tap(GameAudioTheme.domino);
    localHand.add(stock.removeLast());
    _sendDominoAction('draw');
    message = localHand.any(canPlay) ? 'سحبت قطعة. لديك حركة متاحة' : 'سحبت قطعة، ولا توجد حركة مناسبة بعد';
    setState(() {});
  }

  void passTurn() {
    if (!isLocalTurn || roundFinished) return;
    if (localHand.any(canPlay)) {
      GameFeedback.error(GameAudioTheme.domino);
      setState(() => message = 'لديك قطعة مناسبة، لا يمكنك التمرير');
      return;
    }
    if (stock.isNotEmpty) {
      GameFeedback.error(GameAudioTheme.domino);
      setState(() => message = 'يجب السحب أولًا ما دامت هناك قطع في السحب');
      return;
    }
    GameFeedback.tap(GameAudioTheme.domino);
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
    var playable = bot.where(canPlay).toList();
    while (playable.isEmpty && stock.isNotEmpty) {
      bot.add(stock.removeLast());
      playable = bot.where(canPlay).toList();
    }
    if (playable.isEmpty) {
      if (isBlocked) {
        finishBlockedRound();
        return;
      }
      message = 'الكمبيوتر مرر الدور. دورك';
      playerTurn = true;
      setState(() {});
      return;
    }
    final chosen = chooseBotTile(playable);
    placeTile(chosen, bot);
    GameFeedback.move(GameAudioTheme.domino);
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

  DominoTile chooseBotTile(List<DominoTile> playable) {
    switch (settings.botDifficultyFor('domino')) {
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
    final botFuture = bot.where((c) => c != tile && (c.matches(newLeft) || c.matches(newRight))).length;
    final playerOptions = player.where((c) => c.matches(newLeft) || c.matches(newRight)).length;
    return tile.total + (tile.isDouble ? 4 : 0) + (botFuture * 3) - (playerOptions * 2);
  }

  void finishRound({required bool playerWon, required String reason}) {
    final points = playerWon ? pipsOf(bot) : pipsOf(player);
    if (playerWon) {
      playerScore += points;
      message = '$reason. فزت بالجولة وربحت $points نقطة';
      GameFeedback.win(GameAudioTheme.domino);
    } else {
      botScore += points;
      message = isNetworkGame ? '$reason. اللاعب الآخر ربح $points نقطة' : '$reason. الكمبيوتر ربح $points نقطة';
      GameFeedback.lose(GameAudioTheme.domino);
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
      GameFeedback.win(GameAudioTheme.domino);
    } else if (botPips < playerPips) {
      final points = playerPips - botPips;
      botScore += points;
      message = isNetworkGame ? 'اللعبة مغلقة. اللاعب الآخر قطعه أقل وربح $points نقطة' : 'اللعبة مغلقة. الكمبيوتر قطعُه أقل وربح $points نقطة';
      GameFeedback.lose(GameAudioTheme.domino);
    } else {
      message = 'اللعبة مغلقة وتعادل بالنقاط';
      GameFeedback.tap(GameAudioTheme.domino);
    }
    setState(() {});
  }

  void nextRound() {
    if (isNetworkGame && !isHost) {
      setState(() => message = 'انتظر ${widget.networkCore?.hostPlayerName ?? 'الداعي'} لبدء الجولة الجديدة');
      return;
    }
    GameFeedback.tap(GameAudioTheme.domino);
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
      board.insert(0, tile);
    } else if (tile.left == leftEnd) {
      placed = tile.flipped();
      board.insert(0, placed);
    } else if (tile.left == rightEnd) {
      board.add(tile);
    } else if (tile.right == rightEnd) {
      placed = tile.flipped();
      board.add(placed);
    }
    lastPlayedTile = placed;
  }

  List<Color> feltColors() {
    switch (settings.tableColorIndex) {
      case 1: return const <Color>[Color(0xFF4F2F17), Color(0xFF79502A)];
      case 2: return const <Color>[Color(0xFF083A66), Color(0xFF0D6FA6)];
      case 3: return const <Color>[Color(0xFF202733), Color(0xFF3A4655)];
      default: return const <Color>[Color(0xFF004D3A), Color(0xFF08745A)];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final playableCount = localHand.where(canPlay).length;
        return Scaffold(
          backgroundColor: const Color(0xFF1C1008),
          appBar: AppBar(
            backgroundColor: const Color(0xFF211208),
            foregroundColor: Colors.white,
            title: const Text('الدومينو'),
            actions: <Widget>[
              if (!isNetworkGame)
                IconButton(
                  tooltip: '4 لاعبين محليًا',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DominoFourPlayerScreen())),
                  icon: const Icon(Icons.groups_rounded),
                ),
              IconButton(
                tooltip: 'إعادة المباراة',
                onPressed: () => startRound(resetScore: true),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xFF2D180B), Color(0xFF130A05)]),
              ),
              child: Column(
                children: <Widget>[
                  _ScoreHeader(
                    opponentName: opponentName,
                    playerScore: playerScore,
                    opponentScore: botScore,
                    opponentTiles: remoteHand.length,
                    roundNumber: roundNumber,
                    message: message,
                    isLocalTurn: isLocalTurn,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                      child: _PremiumBoard(
                        board: board,
                        lastPlayedTile: lastPlayedTile,
                        stockCount: stock.length,
                        leftEnd: leftEnd,
                        rightEnd: rightEnd,
                        feltColors: feltColors(),
                        onDraw: roundFinished ? null : drawTile,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: _ActionStrip(
                      stockCount: stock.length,
                      playableCount: playableCount,
                      roundFinished: roundFinished,
                      onDraw: drawTile,
                      onPass: passTurn,
                      onNextRound: nextRound,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _PlayerHand(
                    tiles: sortedPlayerHand,
                    playerTurn: isLocalTurn,
                    roundFinished: roundFinished,
                    canPlay: canPlay,
                    onPlay: playPlayerTile,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({required this.opponentName, required this.playerScore, required this.opponentScore, required this.opponentTiles, required this.roundNumber, required this.message, required this.isLocalTurn});
  final String opponentName;
  final int playerScore;
  final int opponentScore;
  final int opponentTiles;
  final int roundNumber;
  final String message;
  final bool isLocalTurn;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 3),
      child: Column(children: <Widget>[
        Row(children: <Widget>[
          Expanded(child: _PlayerSummary(name: opponentName, score: opponentScore, tiles: opponentTiles, emphasized: !isLocalTurn)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: const Color(0x24FFFFFF), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0x32FFFFFF))),
            child: Column(children: <Widget>[
              const Icon(Icons.casino_rounded, color: Color(0xFFFFD98B), size: 20),
              Text('جولة $roundNumber', style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ]),
          ),
          Expanded(child: _PlayerSummary(name: 'أنت', score: playerScore, emphasized: isLocalTurn)),
        ]),
        const SizedBox(height: 7),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isLocalTurn ? const Color(0x3319D3A2) : const Color(0x22FFFFFF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isLocalTurn ? const Color(0x6634D399) : const Color(0x22FFFFFF)),
          ),
          child: Text(message, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

class _PlayerSummary extends StatelessWidget {
  const _PlayerSummary({required this.name, required this.score, this.tiles, required this.emphasized});
  final String name;
  final int score;
  final int? tiles;
  final bool emphasized;
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: emphasized ? const Color(0x25FFD98B) : const Color(0x12FFFFFF),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: emphasized ? const Color(0x77FFD98B) : const Color(0x20FFFFFF)),
      ),
      child: Column(children: <Widget>[
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text('$score', style: const TextStyle(color: Color(0xFFFFE0A3), fontSize: 23, fontWeight: FontWeight.w900)),
        if (tiles != null) Text('$tiles قطع', style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ]),
    );
  }
}

class _PremiumBoard extends StatelessWidget {
  const _PremiumBoard({required this.board, required this.lastPlayedTile, required this.stockCount, required this.leftEnd, required this.rightEnd, required this.feltColors, required this.onDraw});
  final List<DominoTile> board;
  final DominoTile? lastPlayedTile;
  final int stockCount;
  final int? leftEnd;
  final int? rightEnd;
  final List<Color> feltColors;
  final VoidCallback? onDraw;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[Color(0xFF7A4723), Color(0xFF3A1C0C), Color(0xFF9A6233)]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x99000000), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: feltColors),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0x5532D6A0), width: 1.5),
          boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x77000000), blurRadius: 16, spreadRadius: 1)],
        ),
        child: Stack(children: <Widget>[
          Positioned(top: 10, left: 10, child: _EndBadge(label: 'يسار', value: leftEnd)),
          Positioned(top: 10, right: 10, child: _EndBadge(label: 'يمين', value: rightEnd)),
          Positioned(
            top: 9, left: 0, right: 0,
            child: Center(
              child: InkWell(
                onTap: onDraw,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0x22FFFFFF))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    const Icon(Icons.layers_rounded, color: Color(0xFFFFE1A8), size: 16),
                    const SizedBox(width: 5),
                    Text('$stockCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                  ]),
                ),
              ),
            ),
          ),
          Positioned.fill(
            top: 48,
            child: board.isEmpty
                ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    Icon(Icons.casino_outlined, color: Colors.white38, size: 46),
                    SizedBox(height: 8),
                    Text('ابدأ بأي قطعة من يدك', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w800)),
                  ]))
                : _SerpentineDominoChain(board: board, lastPlayedTile: lastPlayedTile),
          ),
        ]),
      ),
    );
  }
}

class _SerpentineDominoChain extends StatelessWidget {
  const _SerpentineDominoChain({required this.board, required this.lastPlayedTile});
  final List<DominoTile> board;
  final DominoTile? lastPlayedTile;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final perRow = max(4, min(7, (constraints.maxWidth / 55).floor()));
      final rows = <List<DominoTile>>[];
      for (int i = 0; i < board.length; i += perRow) {
        final row = board.sublist(i, min(i + perRow, board.length));
        rows.add((rows.length.isOdd ? row.reversed : row).toList());
      }
      final compact = rows.length > 4 || constraints.maxHeight < 300;
      return Center(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            for (int r = 0; r < rows.length; r++) ...<Widget>[
              Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                for (int c = 0; c < rows[r].length; c++) ...<Widget>[
                  AnimatedScale(
                    duration: const Duration(milliseconds: 220),
                    scale: rows[r][c].toString() == lastPlayedTile?.toString() ? 1.08 : 1,
                    child: DominoTileView(
                      tile: rows[r][c], compact: compact, horizontal: !rows[r][c].isDouble,
                      lastPlayed: rows[r][c].toString() == lastPlayedTile?.toString(),
                    ),
                  ),
                  if (c != rows[r].length - 1) SizedBox(width: compact ? 2 : 3),
                ],
              ]),
              if (r != rows.length - 1) SizedBox(height: compact ? 3 : 5),
            ],
          ]),
        ),
      );
    });
  }
}

class _EndBadge extends StatelessWidget {
  const _EndBadge({required this.label, required this.value});
  final String label;
  final int? value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(14)),
    child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9)),
      const SizedBox(width: 5),
      Text(value?.toString() ?? '—', style: const TextStyle(color: Color(0xFFFFE0A3), fontWeight: FontWeight.w900)),
    ]),
  );
}

class _ActionStrip extends StatelessWidget {
  const _ActionStrip({required this.stockCount, required this.playableCount, required this.roundFinished, required this.onDraw, required this.onPass, required this.onNextRound});
  final int stockCount;
  final int playableCount;
  final bool roundFinished;
  final VoidCallback onDraw;
  final VoidCallback onPass;
  final VoidCallback onNextRound;
  @override
  Widget build(BuildContext context) => Row(children: <Widget>[
    Expanded(child: FilledButton.icon(
      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0E6F55), foregroundColor: Colors.white, minimumSize: const Size(0, 44)),
      onPressed: roundFinished ? null : onDraw,
      icon: const Icon(Icons.add_circle_outline_rounded, size: 19),
      label: Text('سحب ($stockCount)'),
    )),
    const SizedBox(width: 8),
    Expanded(child: OutlinedButton.icon(
      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFFD98B), side: const BorderSide(color: Color(0x66FFD98B)), minimumSize: const Size(0, 44)),
      onPressed: roundFinished ? onNextRound : onPass,
      icon: Icon(roundFinished ? Icons.play_arrow_rounded : Icons.skip_next_rounded),
      label: Text(roundFinished ? 'جولة جديدة' : 'تمرير'),
    )),
    const SizedBox(width: 8),
    Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: const Color(0x22FFFFFF), borderRadius: BorderRadius.circular(14)),
      alignment: Alignment.center,
      child: Text('$playableCount متاحة', style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ),
  ]);
}

class _PlayerHand extends StatelessWidget {
  const _PlayerHand({required this.tiles, required this.playerTurn, required this.roundFinished, required this.canPlay, required this.onPlay});
  final List<DominoTile> tiles;
  final bool playerTurn;
  final bool roundFinished;
  final bool Function(DominoTile tile) canPlay;
  final void Function(DominoTile tile) onPlay;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(8, 9, 8, 7),
    decoration: const BoxDecoration(color: Color(0xFF261309), border: Border(top: BorderSide(color: Color(0x553B2417)))),
    child: SizedBox(
      height: 94,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: tiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 5),
        itemBuilder: (context, index) {
          final tile = tiles[index];
          final enabled = playerTurn && !roundFinished && canPlay(tile);
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: enabled ? 1 : 0.48,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 180),
              offset: enabled ? const Offset(0, -0.05) : Offset.zero,
              child: InkWell(
                onTap: enabled ? () => onPlay(tile) : null,
                borderRadius: BorderRadius.circular(12),
                child: DominoTileView(tile: tile, playable: enabled),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class DominoTileView extends StatelessWidget {
  const DominoTileView({super.key, required this.tile, this.compact = false, this.playable = false, this.lastPlayed = false, this.horizontal = false});
  final DominoTile tile;
  final bool compact;
  final bool playable;
  final bool lastPlayed;
  final bool horizontal;
  @override
  Widget build(BuildContext context) {
    final longSide = compact ? 49.0 : 78.0;
    final shortSide = compact ? 27.0 : 45.0;
    final width = horizontal ? longSide : shortSide;
    final height = horizontal ? shortSide : longSide;
    final pipSize = compact ? 2.6 : 3.8;
    final borderColor = lastPlayed ? const Color(0xFFFFD166) : playable ? const Color(0xFF38D9A9) : const Color(0xFFB8A88A);
    final faces = <Widget>[
      Expanded(child: _PipFace(value: tile.left, pipSize: pipSize)),
      Container(
        width: horizontal ? 1.2 : null,
        height: horizontal ? null : 1.2,
        margin: horizontal ? const EdgeInsets.symmetric(vertical: 4) : const EdgeInsets.symmetric(horizontal: 4),
        color: const Color(0xFFB8AB8D),
      ),
      Expanded(child: _PipFace(value: tile.right, pipSize: pipSize)),
    ];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[Color(0xFFFFF9E7), Color(0xFFEADFC5)]),
        borderRadius: BorderRadius.circular(compact ? 7 : 10),
        border: Border.all(color: borderColor, width: playable || lastPlayed ? 2.3 : 1.1),
        boxShadow: <BoxShadow>[BoxShadow(color: playable || lastPlayed ? const Color(0x5500D6A0) : const Color(0x66000000), blurRadius: playable || lastPlayed ? 10 : 5, offset: const Offset(0, 3))],
      ),
      child: horizontal ? Row(children: faces) : Column(children: faces),
    );
  }
}

class _PipFace extends StatelessWidget {
  const _PipFace({required this.value, required this.pipSize});
  final int value;
  final double pipSize;
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _PipPainter(value: value, pipSize: pipSize), child: const SizedBox.expand());
}

class _PipPainter extends CustomPainter {
  const _PipPainter({required this.value, required this.pipSize});
  final int value;
  final double pipSize;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF17382F);
    final l = size.width * .27, r = size.width * .73, t = size.height * .27, cy = size.height * .5, b = size.height * .73, cx = size.width * .5;
    final points = <Offset>[];
    switch (value) {
      case 1: points.add(Offset(cx, cy)); break;
      case 2: points.addAll(<Offset>[Offset(l, t), Offset(r, b)]); break;
      case 3: points.addAll(<Offset>[Offset(l, t), Offset(cx, cy), Offset(r, b)]); break;
      case 4: points.addAll(<Offset>[Offset(l, t), Offset(r, t), Offset(l, b), Offset(r, b)]); break;
      case 5: points.addAll(<Offset>[Offset(l, t), Offset(r, t), Offset(cx, cy), Offset(l, b), Offset(r, b)]); break;
      case 6: points.addAll(<Offset>[Offset(l, t), Offset(r, t), Offset(l, cy), Offset(r, cy), Offset(l, b), Offset(r, b)]); break;
    }
    for (final p in points) { canvas.drawCircle(p, pipSize, paint); }
  }
  @override
  bool shouldRepaint(covariant _PipPainter oldDelegate) => oldDelegate.value != value || oldDelegate.pipSize != pipSize;
}
