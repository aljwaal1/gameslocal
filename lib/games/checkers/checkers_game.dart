import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/app_settings.dart';

enum Piece { empty, red, black, redKing, blackKing }

class CheckersMove {
  const CheckersMove({
    required this.fromRow,
    required this.fromCol,
    required this.toRow,
    required this.toCol,
    this.captureRow,
    this.captureCol,
  });

  final int fromRow;
  final int fromCol;
  final int toRow;
  final int toCol;
  final int? captureRow;
  final int? captureCol;

  bool get isCapture => captureRow != null && captureCol != null;
}

class CheckersGameScreen extends StatefulWidget {
  const CheckersGameScreen({super.key});

  @override
  State<CheckersGameScreen> createState() => _CheckersGameScreenState();
}

class _CheckersGameScreenState extends State<CheckersGameScreen> {
  final settings = AppSettingsController.instance;
  final random = Random();

  late List<List<Piece>> board;
  int? selectedRow;
  int? selectedCol;
  bool redTurn = true;
  bool playVsBot = true;
  bool botThinking = false;
  String message = 'دور الأحمر';

  @override
  void initState() {
    super.initState();
    resetBoard();
  }

  void resetBoard() {
    board = List.generate(8, (_) => List.filled(8, Piece.empty));

    // الضامة المحلية: 16 حجر لكل لاعب.
    // أول سطر من جهة الخصم فارغ، وبعده سطران ممتلئان.
    for (int r = 1; r <= 2; r++) {
      for (int c = 0; c < 8; c++) {
        board[r][c] = Piece.black;
      }
    }

    // آخر سطر من جهة اللاعب فارغ، وقبله سطران ممتلئان.
    for (int r = 5; r <= 6; r++) {
      for (int c = 0; c < 8; c++) {
        board[r][c] = Piece.red;
      }
    }

    selectedRow = null;
    selectedCol = null;
    redTurn = true;
    botThinking = false;
    message = playVsBot ? 'أنت الأحمر - دورك' : 'دور الأحمر';
    if (mounted) setState(() {});
  }

  bool isRedPiece(Piece p) => p == Piece.red || p == Piece.redKing;
  bool isBlackPiece(Piece p) => p == Piece.black || p == Piece.blackKing;
  bool isKing(Piece p) => p == Piece.redKing || p == Piece.blackKing;

  bool isCurrentPlayerPiece(Piece p) {
    if (redTurn) return isRedPiece(p);
    return isBlackPiece(p);
  }

  bool pieceBelongsToTurn(Piece p, bool forRed) {
    return forRed ? isRedPiece(p) : isBlackPiece(p);
  }

  bool opponentForTurn(Piece p, bool forRed) {
    return forRed ? isBlackPiece(p) : isRedPiece(p);
  }

  void tapCell(int r, int c) {
    if (botThinking) return;
    if (playVsBot && !redTurn) return;

    final piece = board[r][c];
    if (selectedRow == null) {
      if (isCurrentPlayerPiece(piece)) {
        setState(() {
          selectedRow = r;
          selectedCol = c;
          message = 'اختر خانة للحركة';
        });
      }
      return;
    }

    final sr = selectedRow!;
    final sc = selectedCol!;

    if (sr == r && sc == c) {
      setState(() {
        selectedRow = null;
        selectedCol = null;
        message = currentTurnMessage();
      });
      return;
    }

    if (board[r][c] != Piece.empty) {
      if (isCurrentPlayerPiece(board[r][c])) {
        setState(() {
          selectedRow = r;
          selectedCol = c;
        });
      }
      return;
    }

    final move = buildMoveIfValid(sr, sc, r, c, redTurn);
    if (move == null) {
      setState(() => message = 'حركة غير صحيحة');
      return;
    }

    applyMove(move);
    finishTurn();
  }

  CheckersMove? buildMoveIfValid(int sr, int sc, int r, int c, bool forRed) {
    final moving = board[sr][sc];
    if (!pieceBelongsToTurn(moving, forRed)) return null;
    if (board[r][c] != Piece.empty) return null;

    final dr = r - sr;
    final dc = c - sc;
    final absDr = dr.abs();
    final absDc = dc.abs();
    final movingIsKing = isKing(moving);
    final forwardOk = movingIsKing || (forRed ? dr == -1 || dr == -2 : dr == 1 || dr == 2);

    if (!forwardOk || absDr != absDc || (absDr != 1 && absDr != 2)) return null;

    if (absDr == 2) {
      final midR = (sr + r) ~/ 2;
      final midC = (sc + c) ~/ 2;
      if (!opponentForTurn(board[midR][midC], forRed)) return null;
      return CheckersMove(fromRow: sr, fromCol: sc, toRow: r, toCol: c, captureRow: midR, captureCol: midC);
    }

    return CheckersMove(fromRow: sr, fromCol: sc, toRow: r, toCol: c);
  }

  void applyMove(CheckersMove move) {
    final moving = board[move.fromRow][move.fromCol];
    board[move.toRow][move.toCol] = promoteIfNeeded(moving, move.toRow);
    board[move.fromRow][move.fromCol] = Piece.empty;
    if (move.isCapture) {
      board[move.captureRow!][move.captureCol!] = Piece.empty;
    }
  }

  void finishTurn() {
    redTurn = !redTurn;
    selectedRow = null;
    selectedCol = null;
    message = currentTurnMessage();
    setState(() {});

    if (playVsBot && !redTurn) {
      runBotMove();
    }
  }

  String currentTurnMessage() {
    if (playVsBot) return redTurn ? 'أنت الأحمر - دورك' : 'الكمبيوتر يفكر...';
    return redTurn ? 'دور الأحمر' : 'دور الأسود';
  }

  Future<void> runBotMove() async {
    setState(() {
      botThinking = true;
      message = 'الكمبيوتر يفكر...';
    });

    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;

    final move = chooseBotMove();
    if (move == null) {
      setState(() {
        botThinking = false;
        message = 'فزت! لا توجد حركة للكمبيوتر';
      });
      return;
    }

    applyMove(move);
    redTurn = true;
    botThinking = false;
    message = 'أنت الأحمر - دورك';
    setState(() {});
  }

  CheckersMove? chooseBotMove() {
    final moves = allLegalMoves(forRed: false);
    if (moves.isEmpty) return null;

    final captures = moves.where((m) => m.isCapture).toList();

    switch (settings.botDifficulty) {
      case BotDifficulty.easy:
        return moves[random.nextInt(moves.length)];
      case BotDifficulty.normal:
        if (captures.isNotEmpty) return captures.first;
        moves.sort((a, b) => b.toRow.compareTo(a.toRow));
        return moves.first;
      case BotDifficulty.hard:
        moves.sort((a, b) => scoreBotMove(b).compareTo(scoreBotMove(a)));
        return moves.first;
    }
  }

  int scoreBotMove(CheckersMove move) {
    final moving = board[move.fromRow][move.fromCol];
    var score = 0;
    if (move.isCapture) score += 100;
    if (move.toRow == 7 && moving == Piece.black) score += 60;
    if (move.toRow > move.fromRow) score += 8;
    if (move.toCol == 0 || move.toCol == 7) score += 4;
    if (isMoveExposed(move)) score -= 35;
    return score;
  }

  bool isMoveExposed(CheckersMove move) {
    final temp = board.map((row) => List<Piece>.from(row)).toList();
    final moving = temp[move.fromRow][move.fromCol];
    temp[move.toRow][move.toCol] = promoteIfNeeded(moving, move.toRow);
    temp[move.fromRow][move.fromCol] = Piece.empty;
    if (move.isCapture) temp[move.captureRow!][move.captureCol!] = Piece.empty;

    for (final d in const [
      [-1, -1],
      [-1, 1],
    ]) {
      final attackerR = move.toRow + d[0];
      final attackerC = move.toCol + d[1];
      final landingR = move.toRow - d[0];
      final landingC = move.toCol - d[1];
      if (!inside(attackerR, attackerC) || !inside(landingR, landingC)) continue;
      if (isRedPiece(temp[attackerR][attackerC]) && temp[landingR][landingC] == Piece.empty) return true;
    }
    return false;
  }

  List<CheckersMove> allLegalMoves({required bool forRed}) {
    final moves = <CheckersMove>[];
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final piece = board[r][c];
        if (!pieceBelongsToTurn(piece, forRed)) continue;
        final directions = isKing(piece)
            ? const [
                [-1, -1],
                [-1, 1],
                [1, -1],
                [1, 1],
              ]
            : forRed
                ? const [
                    [-1, -1],
                    [-1, 1],
                  ]
                : const [
                    [1, -1],
                    [1, 1],
                  ];

        for (final d in directions) {
          final oneR = r + d[0];
          final oneC = c + d[1];
          if (inside(oneR, oneC)) {
            final move = buildMoveIfValid(r, c, oneR, oneC, forRed);
            if (move != null) moves.add(move);
          }

          final twoR = r + d[0] * 2;
          final twoC = c + d[1] * 2;
          if (inside(twoR, twoC)) {
            final move = buildMoveIfValid(r, c, twoR, twoC, forRed);
            if (move != null) moves.add(move);
          }
        }
      }
    }
    return moves;
  }

  bool inside(int r, int c) => r >= 0 && r < 8 && c >= 0 && c < 8;

  Piece promoteIfNeeded(Piece piece, int row) {
    if (piece == Piece.red && row == 0) return Piece.redKing;
    if (piece == Piece.black && row == 7) return Piece.blackKing;
    return piece;
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
        return const Color(0xFF1F6F63);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('الضامة'),
            actions: [IconButton(onPressed: resetBoard, icon: const Icon(Icons.refresh))],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(redTurn ? Icons.circle : Icons.smart_toy_outlined),
                            const SizedBox(width: 10),
                            Expanded(child: Text(message, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _InfoChip(label: 'اللعب', value: playVsBot ? 'ضد الكمبيوتر' : 'لاعب ضد لاعب')),
                            const SizedBox(width: 8),
                            Expanded(child: _InfoChip(label: 'مستوى الكمبيوتر', value: settings.botDifficultyText)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: false, label: Text('لاعب ضد لاعب'), icon: Icon(Icons.people)),
                            ButtonSegment(value: true, label: Text('ضد الكمبيوتر'), icon: Icon(Icons.smart_toy)),
                          ],
                          selected: {playVsBot},
                          onSelectionChanged: (value) {
                            setState(() => playVsBot = value.first);
                            resetBoard();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tableColor,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFFFC857), width: 5),
                          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 6))],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
                            itemCount: 64,
                            itemBuilder: (context, index) {
                              final r = index ~/ 8;
                              final c = index % 8;
                              return _BoardCell(
                                row: r,
                                col: c,
                                piece: board[r][c],
                                selected: selectedRow == r && selectedCol == c,
                                tableColor: tableColor,
                                onTap: () => tapCell(r, c),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: Text(
                  'التوزيع المحلي: 16 حجر لكل لاعب، سطران ممتلئان لكل جهة مع سطر خلفي فارغ.',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1F6F63).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }
}

class _BoardCell extends StatelessWidget {
  const _BoardCell({
    required this.row,
    required this.col,
    required this.piece,
    required this.selected,
    required this.tableColor,
    required this.onTap,
  });

  final int row;
  final int col;
  final Piece piece;
  final bool selected;
  final Color tableColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = (row + col).isOdd;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFFD166)
              : dark
                  ? tableColor.withOpacity(0.78)
                  : const Color(0xFFF2D7A0),
          border: Border.all(color: Colors.black.withOpacity(0.22), width: 0.45),
        ),
        child: Center(child: _PieceView(piece: piece)),
      ),
    );
  }
}

class _PieceView extends StatelessWidget {
  const _PieceView({required this.piece});
  final Piece piece;

  @override
  Widget build(BuildContext context) {
    if (piece == Piece.empty) return const SizedBox.shrink();
    final isRed = piece == Piece.red || piece == Piece.redKing;
    final king = piece == Piece.redKing || piece == Piece.blackKing;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isRed ? const Color(0xFFC84C4C) : const Color(0xFF222831),
        border: Border.all(color: Colors.white.withOpacity(0.75), width: 1.4),
        boxShadow: const [BoxShadow(blurRadius: 4, offset: Offset(1, 2), color: Colors.black26)],
      ),
      child: king ? const Icon(Icons.star, color: Colors.white, size: 18) : null,
    );
  }
}
