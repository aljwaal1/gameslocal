import 'dart:math';

import 'package:flutter/material.dart';

import 'domino_blocked_result.dart';
import 'domino_turn_order.dart';

class DominoFourPlayerScreen extends StatefulWidget {
  const DominoFourPlayerScreen({super.key});

  @override
  State<DominoFourPlayerScreen> createState() =>
      _DominoFourPlayerScreenState();
}

class _DominoFourPlayerScreenState extends State<DominoFourPlayerScreen> {
  final turns = DominoTurnOrder(playerCount: 4);
  List<List<_Tile>> hands = [];
  final List<_Tile> board = [];
  int? left, right;
  int consecutivePasses = 0;
  bool gameFinished = false;
  String message = '';

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  void _newGame() {
    final deck = <_Tile>[
      for (var a = 0; a <= 6; a++)
        for (var b = a; b <= 6; b++) _Tile(a, b),
    ]..shuffle(Random());
    hands = List.generate(4, (player) => deck.sublist(player * 7, player * 7 + 7));
    board.clear();
    left = null;
    right = null;
    turns.reset();
    consecutivePasses = 0;
    gameFinished = false;
    message = 'دور اللاعب 1';
    if (mounted) setState(() {});
  }

  bool _legal(_Tile tile) =>
      board.isEmpty ||
      tile.a == left ||
      tile.b == left ||
      tile.a == right ||
      tile.b == right;

  void _finishBlockedGame() {
    final result = calculateDominoBlockedResult(
      hands
          .map(
            (hand) => hand
                .map((tile) => tile.a + tile.b)
                .toList(growable: false),
          )
          .toList(growable: false),
    );
    gameFinished = true;
    final scores = List.generate(
      result.points.length,
      (index) => 'اللاعب ${index + 1}: ${result.points[index]}',
    ).join('، ');
    message = result.winners.length == 1
        ? 'أُغلقت اللعبة — فاز اللاعب ${result.winners.first} بأقل مجموع (${result.bestScore}). $scores'
        : 'أُغلقت اللعبة — تعادل اللاعبون ${result.winners.join(' و ')} بأقل مجموع (${result.bestScore}). $scores';
  }

  void _play(_Tile tile) {
    if (gameFinished) return;
    if (!_legal(tile)) {
      setState(() => message = 'هذه القطعة لا تناسب طرفي السلسلة');
      return;
    }
    setState(() {
      hands[turns.currentPlayer].remove(tile);
      if (board.isEmpty) {
        board.add(tile);
        left = tile.a;
        right = tile.b;
      } else if (tile.a == left) {
        board.insert(0, _Tile(tile.b, tile.a));
        left = tile.b;
      } else if (tile.b == left) {
        board.insert(0, tile);
        left = tile.a;
      } else if (tile.a == right) {
        board.add(tile);
        right = tile.b;
      } else {
        board.add(_Tile(tile.b, tile.a));
        right = tile.a;
      }
      consecutivePasses = 0;
      if (hands[turns.currentPlayer].isEmpty) {
        gameFinished = true;
        message = 'فاز اللاعب ${turns.currentPlayer + 1}!';
        return;
      }
      turns.next();
      message = 'دور اللاعب ${turns.currentPlayer + 1}';
    });
  }

  void _pass() {
    if (gameFinished) return;
    if (hands[turns.currentPlayer].any(_legal)) {
      setState(() => message = 'لديك قطعة صالحة، لا يمكنك التمرير');
      return;
    }
    setState(() {
      consecutivePasses++;
      if (consecutivePasses >= 4) {
        _finishBlockedGame();
        return;
      }
      turns.next();
      message = 'تم التمرير — دور اللاعب ${turns.currentPlayer + 1}';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('دومينو — 4 لاعبين محليًا'),
          actions: [
            IconButton(onPressed: _newGame, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'مرّر الهاتف للاعب صاحب الدور. القطع المخفية للاعبين الآخرين.',
                  textAlign: TextAlign.center,
                ),
              ),
              Wrap(
                spacing: 8,
                children: List.generate(
                  4,
                  (index) => Chip(
                    avatar: CircleAvatar(child: Text('${index + 1}')),
                    label: Text('${hands[index].length} قطع'),
                    backgroundColor:
                        !gameFinished && index == turns.currentPlayer
                            ? Colors.amber
                            : null,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: board.map((tile) => _tile(tile, false)).toList(),
                  ),
                ),
              ),
              const Divider(),
              Text(
                gameFinished
                    ? 'انتهت اللعبة'
                    : 'قطع اللاعب ${turns.currentPlayer + 1}',
              ),
              SizedBox(
                height: 96,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(8),
                  children: hands[turns.currentPlayer]
                      .map((tile) => _tile(tile, !gameFinished))
                      .toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: gameFinished ? null : _pass,
                        icon: const Icon(Icons.skip_next),
                        label: const Text('تمرير الدور'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _newGame,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('لعبة جديدة'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _tile(_Tile tile, bool playable) => Padding(
        padding: const EdgeInsets.all(4),
        child: InkWell(
          onTap: playable ? () => _play(tile) : null,
          child: Container(
            width: 54,
            height: 76,
            decoration: BoxDecoration(
              color: playable && _legal(tile)
                  ? Colors.white
                  : Colors.grey.shade300,
              border: Border.all(
                color: playable && _legal(tile)
                    ? Colors.green
                    : Colors.black54,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(
                  '${tile.a}',
                  style: const TextStyle(fontSize: 22, color: Colors.black),
                ),
                const Divider(height: 2, color: Colors.black),
                Text(
                  '${tile.b}',
                  style: const TextStyle(fontSize: 22, color: Colors.black),
                ),
              ],
            ),
          ),
        ),
      );
}

class _Tile {
  const _Tile(this.a, this.b);

  final int a;
  final int b;
}
