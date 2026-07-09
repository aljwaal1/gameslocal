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

  int get scoreValue => rank == 'J' || rank == 'Q' || rank == 'K' ? 10 : 1;
  String get label => '$rank$suit';
  bool get red => suit == '♥' || suit == '♦';
  bool get face => rank == 'J' || rank == 'Q' || rank == 'K';
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
  int playerSteals = 0;
  int botSteals = 0;
  LastCollector? lastCollector;
  String message = 'السراقة الأردنية/الفلسطينية: الصور = 10، والباقي = 1';

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
      playerSteals = 0;
      botSteals = 0;
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

  int scoreOfCards(List<PlayingCardModel> cards) => cards.fold(0, (sum, card) => sum + card.scoreValue);

  void playPlayerCard(PlayingCardModel card) {
    if (!playerTurn || roundFinished) return;
    GameFeedback.move();
    playCard(card, playerHand, playerPile, botPile, isPlayer: true);
    if (checkRoundEnd()) return;
    playerTurn = false;
    message = 'الكمبيوتر يفكر...';
    setState(() {});
    Future<void>.delayed(const Duration(milliseconds: 550), botMove);
  }

  void botMove() {
    if (roundFinished) return;
    PlayingCardModel? chosen;

    final tablePlayable = botHand.where((card) => table.any((t) => t.value == card.value)).toList();
    final stealPlayable = botHand.where((card) => playerPile.any((p) => p.value == card.value)).toList();

    if (tablePlayable.isNotEmpty) {
      tablePlayable.sort((a, b) => scorePotential(b, table).compareTo(scorePotential(a, table)));
      chosen = tablePlayable.first;
    } else if (stealPlayable.isNotEmpty) {
      stealPlayable.sort((a, b) => scorePotential(b, playerPile).compareTo(scorePotential(a, playerPile)));
      chosen = stealPlayable.first;
    } else if (botHand.isNotEmpty) {
      chosen = botHand[random.nextInt(botHand.length)];
    }

    if (chosen != null) {
      playCard(chosen, botHand, botPile, playerPile, isPlayer: false);
    }
    if (checkRoundEnd()) return;
    playerTurn = true;
    message = 'دورك: اختر ورقة من يدك';
    setState(() {});
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
        message = madeBasra ? 'بسرا! التقطت كل الأرض +10' : 'التقطت من الأرض وربحت $gained نقطة';
      } else {
        botScore += gained + basraBonus;
        if (madeBasra) botBasra++;
        message = madeBasra ? 'الكمبيوتر عمل بسرا +10' : 'الكمبيوتر التقط من الأرض وربح $gained نقطة';
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
          message = 'سرقت من الكمبيوتر ${stolen.length} ورقة وربحت $gained نقطة';
        } else {
          botScore += gained;
          botSteals++;
          message = 'الكمبيوتر سرق منك ${stolen.length} ورقة وربح $gained نقطة';
        }
        GameFeedback.win();
      } else {
        table.add(card);
        message = isPlayer ? 'وضعت الورقة على الأرض' : 'الكمبيوتر وضع ورقة على الأرض';
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
                playerSteals: playerSteals,
                botSteals: botSteals,
              ),
              const SizedBox(height: 8),
              _OpponentPanel(count: botHand.length, pile: botPile.length),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF063B35), Color(0xFF0E6F63)]),
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
                Text('رصيد قابل للسرقة: $pile'),
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
  const PlayingCardView({super.key, required this.card, this.compact = false, this.highlight = false});

  final PlayingCardModel card;
  final bool compact;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 46.0 : 58.0;
    final height = compact ? 66.0 : 88.0;
    final mainColor = card.red ? AppColors.danger : AppColors.ink;

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
      child: Stack(
        children: [
          Positioned(top: 5, left: 6, child: _Corner(card: card, small: compact)),
          Positioned(bottom: 5, right: 6, child: RotatedBox(quarterTurns: 2, child: _Corner(card: card, small: compact))),
          Center(
            child: card.face
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(card.rank, style: TextStyle(fontSize: compact ? 22 : 28, fontWeight: FontWeight.w900, color: mainColor)),
                      Text(card.suit, style: TextStyle(fontSize: compact ? 18 : 24, color: mainColor)),
                    ],
                  )
                : Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 2,
                    runSpacing: 0,
                    children: List.generate(min(card.value, 10), (_) => Text(card.suit, style: TextStyle(fontSize: compact ? 12 : 14, color: mainColor))),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({required this.card, required this.small});
  final PlayingCardModel card;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final color = card.red ? AppColors.danger : AppColors.ink;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(card.rank, style: TextStyle(fontSize: small ? 9 : 11, fontWeight: FontWeight.w900, color: color, height: 0.9)),
        Text(card.suit, style: TextStyle(fontSize: small ? 10 : 12, color: color, height: 0.9)),
      ],
    );
  }
}
