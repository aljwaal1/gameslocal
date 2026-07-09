import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/audio_feedback.dart';
import '../../design/app_theme.dart';

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

  String get label => '$rank$suit';
  bool get red => suit == '♥' || suit == '♦';
}

enum LastCollector { player, bot }

class CardsPlaceholderScreen extends StatefulWidget {
  const CardsPlaceholderScreen({super.key});

  @override
  State<CardsPlaceholderScreen> createState() => _CardsPlaceholderScreenState();
}

class _CardsPlaceholderScreenState extends State<CardsPlaceholderScreen> {
  final Random random = Random();
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
  LastCollector? lastCollector;
  String message = 'دورك: العب ورقة أو التقط بطاقة مطابقة';

  @override
  void initState() {
    super.initState();
    newRound(resetScore: true);
  }

  void newRound({bool resetScore = false}) {
    const ranks = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
    const suits = ['♥', '♦', '♣', '♠'];
    final cards = <PlayingCardModel>[];
    for (final suit in suits) {
      for (final rank in ranks) {
        cards.add(PlayingCardModel(rank: rank, suit: suit));
      }
    }
    cards.shuffle(random);

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
    }
    dealHands();
    message = 'دورك: اختر ورقة من يدك';
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

  void playPlayerCard(PlayingCardModel card) {
    if (!playerTurn || roundFinished) return;
    GameFeedback.move();
    playCard(card, playerHand, playerPile, isPlayer: true);
    if (checkRoundEnd()) return;
    playerTurn = false;
    message = 'الكمبيوتر يفكر...';
    setState(() {});
    Future<void>.delayed(const Duration(milliseconds: 550), botMove);
  }

  void botMove() {
    if (roundFinished) return;
    PlayingCardModel? chosen;
    final playable = botHand.where((card) => table.any((t) => t.value == card.value)).toList();
    if (playable.isNotEmpty) {
      playable.sort((a, b) {
        final aMatches = table.where((t) => t.value == a.value).length;
        final bMatches = table.where((t) => t.value == b.value).length;
        return bMatches.compareTo(aMatches);
      });
      chosen = playable.first;
    } else if (botHand.isNotEmpty) {
      chosen = botHand[random.nextInt(botHand.length)];
    }

    if (chosen != null) {
      playCard(chosen, botHand, botPile, isPlayer: false);
    }
    if (checkRoundEnd()) return;
    playerTurn = true;
    message = 'دورك: اختر ورقة من يدك';
    setState(() {});
  }

  void playCard(PlayingCardModel card, List<PlayingCardModel> hand, List<PlayingCardModel> pile, {required bool isPlayer}) {
    hand.remove(card);
    final matches = table.where((t) => t.value == card.value).toList();
    if (matches.isNotEmpty) {
      pile.add(card);
      pile.addAll(matches);
      table.removeWhere((t) => t.value == card.value);
      lastCollector = isPlayer ? LastCollector.player : LastCollector.bot;
      final capturedPoints = matches.length + 1;
      final madeBasra = table.isEmpty;
      final basraBonus = madeBasra ? 10 : 0;

      if (isPlayer) {
        playerScore += capturedPoints + basraBonus;
        if (madeBasra) playerBasra++;
        message = madeBasra ? 'بسرا! التقطت كل الأرض وربحت مكافأة' : 'التقطت ${matches.length} بطاقة مطابقة';
      } else {
        botScore += capturedPoints + basraBonus;
        if (madeBasra) botBasra++;
        message = madeBasra ? 'الكمبيوتر عمل بسرا' : 'الكمبيوتر التقط ${matches.length} بطاقة';
      }
      GameFeedback.win();
    } else {
      table.add(card);
      message = isPlayer ? 'وضعت الورقة على الأرض' : 'الكمبيوتر وضع ورقة على الأرض';
    }

    if (playerHand.isEmpty && botHand.isEmpty && deck.isNotEmpty) {
      dealHands();
    }
  }

  bool checkRoundEnd() {
    if (deck.isEmpty && playerHand.isEmpty && botHand.isEmpty) {
      roundFinished = true;
      if (table.isNotEmpty && lastCollector != null) {
        if (lastCollector == LastCollector.player) {
          playerPile.addAll(table);
          playerScore += table.length;
        } else {
          botPile.addAll(table);
          botScore += table.length;
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

  @override
  Widget build(BuildContext context) {
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
              ),
              const SizedBox(height: 8),
              _OpponentPanel(count: botHand.length, pile: botPile.length),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
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
                    for (final card in playerHand)
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: playerTurn && !roundFinished ? () => playPlayerCard(card) : null,
                        child: Opacity(
                          opacity: playerTurn && !roundFinished ? 1 : 0.5,
                          child: PlayingCardView(card: card),
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
  });

  final String message;
  final int playerScore;
  final int botScore;
  final int deckCount;
  final int tableCount;
  final int playerBasra;
  final int botBasra;

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
                _MiniStat(label: 'الرزمة', value: '$deckCount'),
                _MiniStat(label: 'الأرض', value: '$tableCount'),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _MiniStat(label: 'بسرا لك', value: '$playerBasra'),
                _MiniStat(label: 'بسرا كمبيوتر', value: '$botBasra'),
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
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: [
                const Icon(Icons.smart_toy, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('يد الكمبيوتر: $count')),
                Text('جمع: $pile'),
              ],
            ),
          ),
        ),
      ],
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
  const PlayingCardView({super.key, required this.card, this.compact = false});

  final PlayingCardModel card;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 46.0 : 56.0;
    final height = compact ? 66.0 : 86.0;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: card.red ? AppColors.danger.withOpacity(0.35) : AppColors.primary.withOpacity(0.35), width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 7, offset: Offset(0, 3))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(card.rank, style: TextStyle(fontSize: compact ? 19 : 24, fontWeight: FontWeight.w900, color: card.red ? AppColors.danger : AppColors.ink)),
          Text(card.suit, style: TextStyle(fontSize: compact ? 18 : 24, color: card.red ? AppColors.danger : AppColors.ink)),
        ],
      ),
    );
  }
}
