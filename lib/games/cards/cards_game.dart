import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/app_settings.dart';
import '../../core/audio_feedback.dart';
import '../../design/app_theme.dart';
import '../../core/network/local_network_core.dart';
import '../../core/network/network_message.dart';

class PlayingCardModel {
  const PlayingCardModel({required this.rank, required this.suit});

  final String rank;
  final String suit;

  int get value {
    switch (rank) {
      case 'A':
        return 1;
      case 'J':
        return 11;
      case 'Q':
        return 12;
      case 'K':
        return 13;
      default:
        return int.tryParse(rank) ?? 0;
    }
  }

  int get scoreValue => rank == 'J' || rank == 'Q' || rank == 'K' ? 10 : 1;
  bool get red => suit == '♥' || suit == '♦';
}

enum LastCollector { player, bot }

class CardsGameScreen extends StatefulWidget {
  const CardsGameScreen({super.key, this.networkCore});

  final LocalNetworkCore? networkCore;

  @override
  State<CardsGameScreen> createState() => _CardsGameScreenState();
}

class _CardsGameScreenState extends State<CardsGameScreen> {
  final Random random = Random();
  final settings = AppSettingsController.instance;
  StreamSubscription<NetworkMessage>? networkSubscription;
  int roundSeed = 0;

  List<PlayingCardModel> deck = [];
  List<PlayingCardModel> table = [];
  List<PlayingCardModel> playerHand = [];
  List<PlayingCardModel> botHand = [];
  List<PlayingCardModel> playerPile = [];
  List<PlayingCardModel> botPile = [];
  bool playerTurn = true;
  bool roundFinished = false;
  int playerScore = 0;
  int botScore = 0;
  int playerBasra = 0;
  int botBasra = 0;
  int playerSteals = 0;
  int botSteals = 0;
  LastCollector? lastCollector;
  String message = 'السراقة: الصور = 10، والباقي = 1';

  bool get isNetworkGame => widget.networkCore != null;
  bool get isHost => widget.networkCore?.state.mode == LocalNetworkMode.host;
  bool get isLocalTurn => isNetworkGame ? (isHost ? playerTurn : !playerTurn) : playerTurn;
  List<PlayingCardModel> get localHand => isNetworkGame && !isHost ? botHand : playerHand;
  String get localPlayerId {
    final players = widget.networkCore?.state.players ?? const <LocalPlayer>[];
    final own = players.where((p) => p.isHost == isHost);
    return own.isNotEmpty ? own.first.id : (isHost ? 'host' : 'client');
  }

  @override
  void initState() {
    super.initState();
    networkSubscription = widget.networkCore?.messages.listen(_handleNetworkMessage);
    newRound(resetScore: true);
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

  void newRound({bool resetScore = false, int? seed}) {
    const ranks = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
    const suits = ['♥', '♦', '♣', '♠'];
    final cards = <PlayingCardModel>[];
    for (final suit in suits) {
      for (final rank in ranks) {
        cards.add(PlayingCardModel(rank: rank, suit: suit));
      }
    }
    roundSeed = seed ?? random.nextInt(1 << 31);
    cards.shuffle(Random(roundSeed));

    deck = cards;
    table = deck.take(4).toList();
    deck = deck.skip(4).toList();
    playerHand = [];
    botHand = [];
    playerPile = [];
    botPile = [];
    playerTurn = true;
    roundFinished = false;
    lastCollector = null;
    if (resetScore) {
      playerScore = 0;
      botScore = 0;
      playerBasra = 0;
      botBasra = 0;
      playerSteals = 0;
      botSteals = 0;
    }
    dealHands();
    message = isNetworkGame ? (isLocalTurn ? 'دورك: اختر ورقة' : 'بانتظار اللاعب الآخر') : 'دورك: اختر ورقة متشابهة للالتقاط أو السرقة';
    setState(() {});
  }

  void _requestRoundState() {
    if (!isNetworkGame) return;
    widget.networkCore!.sendMove(<String, dynamic>{'game': 'cards', 'action': 'stateRequest'}, senderId: localPlayerId);
  }

  void _sendRoundStart() {
    if (!isNetworkGame || !isHost) return;
    widget.networkCore!.sendMove(<String, dynamic>{'game': 'cards', 'action': 'start', 'seed': roundSeed}, senderId: localPlayerId);
  }

  void _sendCard(PlayingCardModel card) {
    widget.networkCore?.sendMove(<String, dynamic>{'game': 'cards', 'action': 'play', 'rank': card.rank, 'suit': card.suit}, senderId: localPlayerId);
  }

  void _handleNetworkMessage(NetworkMessage networkMessage) {
    if (!mounted || networkMessage.type != NetworkMessageType.move || networkMessage.senderId == localPlayerId || networkMessage.payload['game'] != 'cards') return;
    final p = networkMessage.payload;
    if (p['action'] == 'stateRequest') {
      if (isHost) _sendRoundStart();
      return;
    }
    if (p['action'] == 'start') {
      newRound(resetScore: true, seed: (p['seed'] as num).toInt());
      return;
    }
    if (p['action'] != 'play' || roundFinished) return;
    final remoteHand = isHost ? botHand : playerHand;
    final index = remoteHand.indexWhere((card) => card.rank == p['rank'] && card.suit == p['suit']);
    if (index < 0) return;
    playCard(remoteHand[index], remoteHand, isHost ? botPile : playerPile, isHost ? playerPile : botPile, isPlayer: !isHost);
    if (checkRoundEnd()) return;
    playerTurn = !playerTurn;
    message = isLocalTurn ? 'دورك: اختر ورقة' : 'بانتظار اللاعب الآخر';
    setState(() {});
  }

  void dealHands() {
    while (playerHand.length < 4 && deck.isNotEmpty) {
      playerHand.add(deck.removeLast());
    }
    while (botHand.length < 4 && deck.isNotEmpty) {
      botHand.add(deck.removeLast());
    }
  }

  int scoreOfCards(List<PlayingCardModel> cards) => cards.fold(0, (sum, card) => sum + card.scoreValue);

  void playPlayerCard(PlayingCardModel card) {
    if (!isLocalTurn || roundFinished) return;
    GameFeedback.move();
    final ownPile = isNetworkGame && !isHost ? botPile : playerPile;
    final opponentPile = isNetworkGame && !isHost ? playerPile : botPile;
    playCard(card, localHand, ownPile, opponentPile, isPlayer: !isNetworkGame || isHost);
    if (isNetworkGame) _sendCard(card);
    if (checkRoundEnd()) return;
    playerTurn = !playerTurn;
    message = isNetworkGame ? 'بانتظار اللاعب الآخر' : 'الكمبيوتر يفكر...';
    setState(() {});
    if (!isNetworkGame) Future<void>.delayed(const Duration(milliseconds: 550), botMove);
  }

  void botMove() {
    if (roundFinished) return;
    final chosen = chooseBotCard();
    if (chosen != null) {
      playCard(chosen, botHand, botPile, playerPile, isPlayer: false);
    }
    if (checkRoundEnd()) return;
    playerTurn = true;
    message = 'دورك: اختر ورقة متشابهة للالتقاط أو السرقة';
    setState(() {});
  }

  PlayingCardModel? chooseBotCard() {
    if (botHand.isEmpty) return null;

    final tablePlayable = botHand.where((card) => table.any((t) => t.value == card.value)).toList();
    final stealPlayable = botHand.where((card) => playerPile.any((p) => p.value == card.value)).toList();

    switch (settings.botDifficulty) {
      case BotDifficulty.easy:
        if (tablePlayable.isNotEmpty && random.nextBool()) return tablePlayable.first;
        return botHand[random.nextInt(botHand.length)];
      case BotDifficulty.normal:
        if (tablePlayable.isNotEmpty) return tablePlayable.first;
        if (stealPlayable.isNotEmpty && random.nextBool()) return stealPlayable.first;
        return botHand[random.nextInt(botHand.length)];
      case BotDifficulty.hard:
        final allGood = [...tablePlayable, ...stealPlayable];
        if (allGood.isNotEmpty) {
          allGood.sort((a, b) => max(scorePotential(b, table), scorePotential(b, playerPile)).compareTo(max(scorePotential(a, table), scorePotential(a, playerPile))));
          return allGood.first;
        }
        return botHand[random.nextInt(botHand.length)];
    }
  }

  int scorePotential(PlayingCardModel card, List<PlayingCardModel> source) {
    final matches = source.where((x) => x.value == card.value).toList();
    return card.scoreValue + scoreOfCards(matches);
  }

  void playCard(
    PlayingCardModel card,
    List<PlayingCardModel> hand,
    List<PlayingCardModel> ownPile,
    List<PlayingCardModel> opponentPile, {
    required bool isPlayer,
  }) {
    hand.remove(card);

    final tableMatches = table.where((t) => t.value == card.value).toList();
    if (tableMatches.isNotEmpty) {
      ownPile.add(card);
      ownPile.addAll(tableMatches);
      table.removeWhere((t) => t.value == card.value);
      lastCollector = isPlayer ? LastCollector.player : LastCollector.bot;

      final gained = card.scoreValue + scoreOfCards(tableMatches);
      final madeBasra = table.isEmpty;
      final basraBonus = madeBasra ? 10 : 0;

      if (isPlayer) {
        playerScore += gained + basraBonus;
        if (madeBasra) playerBasra++;
        message = madeBasra ? 'بسرا! التقطت كل الأرض +10' : 'التقطت أوراقًا متشابهة وربحت $gained نقطة';
      } else {
        botScore += gained + basraBonus;
        if (madeBasra) botBasra++;
        message = madeBasra ? 'الكمبيوتر عمل بسرا +10' : 'الكمبيوتر التقط أوراقًا متشابهة وربح $gained نقطة';
      }
      GameFeedback.win();
    } else {
      final stolen = opponentPile.where((p) => p.value == card.value).toList();
      if (stolen.isNotEmpty) {
        opponentPile.removeWhere((p) => p.value == card.value);
        ownPile.add(card);
        ownPile.addAll(stolen);
        lastCollector = isPlayer ? LastCollector.player : LastCollector.bot;
        final gained = card.scoreValue + scoreOfCards(stolen);

        if (isPlayer) {
          playerScore += gained;
          playerSteals++;
          message = 'سرقت متشابهات من الكمبيوتر وربحت $gained نقطة';
        } else {
          botScore += gained;
          botSteals++;
          message = 'الكمبيوتر سرق متشابهات منك وربح $gained نقطة';
        }
        GameFeedback.win();
      } else {
        table.add(card);
        message = isPlayer ? 'لا يوجد متشابه، وضعت الورقة على الأرض' : 'الكمبيوتر وضع ورقة على الأرض';
      }
    }

    if (playerHand.isEmpty && botHand.isEmpty && deck.isNotEmpty) {
      dealHands();
    }
  }

  bool checkRoundEnd() {
    if (deck.isEmpty && playerHand.isEmpty && botHand.isEmpty) {
      roundFinished = true;
      if (table.isNotEmpty && lastCollector != null) {
        final remainingScore = scoreOfCards(table);
        if (lastCollector == LastCollector.player) {
          playerPile.addAll(table);
          playerScore += remainingScore;
        } else {
          botPile.addAll(table);
          botScore += remainingScore;
        }
        table.clear();
      }
      if (playerScore > botScore) {
        message = 'انتهت الجولة: فزت $playerScore مقابل $botScore';
        GameFeedback.win();
      } else if (botScore > playerScore) {
        message = 'انتهت الجولة: فاز الكمبيوتر $botScore مقابل $playerScore';
        GameFeedback.error();
      } else {
        message = 'انتهت الجولة بتعادل $playerScore - $botScore';
        GameFeedback.tap();
      }
      setState(() {});
      return true;
    }
    setState(() {});
    return false;
  }

  bool canCaptureOrSteal(PlayingCardModel card) {
    return table.any((t) => t.value == card.value) || botPile.any((p) => p.value == card.value);
  }

  Color get tableColor {
    switch (settings.tableColorIndex) {
      case 1:
        return const Color(0xFF6B4F2A);
      case 2:
        return const Color(0xFF1E3A8A);
      case 3:
        return const Color(0xFF111827);
      default:
        return AppColors.primaryDark;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('الشدة / السراقة'),
            actions: [IconButton(onPressed: () => newRound(resetScore: true), icon: const Icon(Icons.refresh))],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Column(
                children: [
                  _StatusCard(
                    message: message,
                    playerScore: playerScore,
                    botScore: botScore,
                    deckCount: deck.length,
                    tableCount: table.length,
                    playerBasra: playerBasra,
                    botBasra: botBasra,
                    playerSteals: playerSteals,
                    botSteals: botSteals,
                    botLevel: settings.botDifficultyText,
                  ),
                  const SizedBox(height: 8),
                  _OpponentPanel(count: botHand.length, pile: botPile.length),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [tableColor, tableColor.withOpacity(0.72)]),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: table.isEmpty
                          ? const Center(child: Text('لا توجد أوراق على الأرض', style: TextStyle(color: Colors.white)))
                          : Wrap(
                              alignment: WrapAlignment.center,
                              runAlignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [for (final card in table) PlayingCardView(card: card, compact: true)],
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 116,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      runAlignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final card in localHand)
                          InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: isLocalTurn && !roundFinished ? () => playPlayerCard(card) : null,
                            child: Opacity(
                              opacity: isLocalTurn && !roundFinished ? 1 : 0.5,
                              child: PlayingCardView(card: card, highlight: canCaptureOrSteal(card)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (roundFinished)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => newRound(),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('جولة جديدة'),
                      ),
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

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.message,
    required this.playerScore,
    required this.botScore,
    required this.deckCount,
    required this.tableCount,
    required this.playerBasra,
    required this.botBasra,
    required this.playerSteals,
    required this.botSteals,
    required this.botLevel,
  });

  final String message;
  final int playerScore;
  final int botScore;
  final int deckCount;
  final int tableCount;
  final int playerBasra;
  final int botBasra;
  final int playerSteals;
  final int botSteals;
  final String botLevel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.style, color: Color(0xFF7B2CBF)),
                const SizedBox(width: 8),
                Expanded(child: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _MiniStat(label: 'نقاطك', value: '$playerScore'),
                _MiniStat(label: 'الكمبيوتر', value: '$botScore'),
                _MiniStat(label: 'المستوى', value: botLevel),
                _MiniStat(label: 'الرزمة', value: '$deckCount'),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _MiniStat(label: 'بسرا لك', value: '$playerBasra'),
                _MiniStat(label: 'بسرا كمبيوتر', value: '$botBasra'),
                _MiniStat(label: 'سرقاتك', value: '$playerSteals'),
                _MiniStat(label: 'سرقاته', value: '$botSteals'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OpponentPanel extends StatelessWidget {
  const _OpponentPanel({required this.count, required this.pile});
  final int count;
  final int pile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          const Icon(Icons.smart_toy, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text('يد الكمبيوتر: $count')),
          Text('رصيد للسرقة: $pile'),
        ],
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
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class PlayingCardView extends StatelessWidget {
  const PlayingCardView({super.key, required this.card, this.compact = false, this.highlight = false});

  final PlayingCardModel card;
  final bool compact;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 48.0 : 60.0;
    final height = compact ? 68.0 : 90.0;
    final mainColor = card.red ? AppColors.danger : AppColors.ink;
    final rankSize = compact ? 24.0 : 30.0;
    final suitSize = compact ? 24.0 : 32.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: highlight ? AppColors.accent : mainColor.withOpacity(0.25), width: highlight ? 3 : 1.4),
        boxShadow: [BoxShadow(color: highlight ? AppColors.accent.withOpacity(0.45) : Colors.black26, blurRadius: highlight ? 10 : 7, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(card.rank, maxLines: 1, style: TextStyle(fontSize: rankSize, fontWeight: FontWeight.w900, color: mainColor, height: 0.9)),
            const SizedBox(height: 5),
            Text(card.suit, style: TextStyle(fontSize: suitSize, fontWeight: FontWeight.bold, color: mainColor, height: 0.9)),
            const SizedBox(height: 3),
            Text('${card.scoreValue}', style: TextStyle(fontSize: compact ? 10 : 11, fontWeight: FontWeight.bold, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
