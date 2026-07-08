import 'package:flutter/material.dart';

enum Piece { empty, red, black, redKing, blackKing }

class CheckersGameScreen extends StatefulWidget {
  const CheckersGameScreen({super.key});

  @override
  State<CheckersGameScreen> createState() => _CheckersGameScreenState();
}

class _CheckersGameScreenState extends State<CheckersGameScreen> {
  late List<List<Piece>> board;
  int? selectedRow;
  int? selectedCol;
  bool redTurn = true;
  String message = 'دور الأحمر';

  @override
  void initState() {
    super.initState();
    resetBoard();
  }

  void resetBoard() {
    board = List.generate(8, (_) => List.filled(8, Piece.empty));
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 8; c++) {
        if ((r + c).isOdd) board[r][c] = Piece.black;
      }
    }
    for (int r = 5; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        if ((r + c).isOdd) board[r][c] = Piece.red;
      }
    }
    selectedRow = null;
    selectedCol = null;
    redTurn = true;
    message = 'دور الأحمر';
    setState(() {});
  }

  bool isCurrentPlayerPiece(Piece p) {
    if (redTurn) return p == Piece.red || p == Piece.redKing;
    return p == Piece.black || p == Piece.blackKing;
  }

  bool isOpponentPiece(Piece p) {
    if (redTurn) return p == Piece.black || p == Piece.blackKing;
    return p == Piece.red || p == Piece.redKing;
  }

  void tapCell(int r, int c) {
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
        message = redTurn ? 'دور الأحمر' : 'دور الأسود';
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

    final moving = board[sr][sc];
    final dr = r - sr;
    final dc = c - sc;
    final absDr = dr.abs();
    final absDc = dc.abs();
    final isKing = moving == Piece.redKing || moving == Piece.blackKing;
    final forwardOk = isKing || (redTurn ? dr == -1 || dr == -2 : dr == 1 || dr == 2);

    if (!forwardOk || absDr != absDc || (absDr != 1 && absDr != 2)) {
      setState(() => message = 'حركة غير صحيحة');
      return;
    }

    if (absDr == 2) {
      final midR = (sr + r) ~/ 2;
      final midC = (sc + c) ~/ 2;
      if (!isOpponentPiece(board[midR][midC])) {
        setState(() => message = 'لا يوجد حجر للخصم للقفز عنه');
        return;
      }
      board[midR][midC] = Piece.empty;
    }

    board[r][c] = promoteIfNeeded(moving, r);
    board[sr][sc] = Piece.empty;
    redTurn = !redTurn;
    selectedRow = null;
    selectedCol = null;
    message = redTurn ? 'دور الأحمر' : 'دور الأسود';
    setState(() {});
  }

  Piece promoteIfNeeded(Piece piece, int row) {
    if (piece == Piece.red && row == 0) return Piece.redKing;
    if (piece == Piece.black && row == 7) return Piece.blackKing;
    return piece;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الضامة'),
        actions: [IconButton(onPressed: resetBoard, icon: const Icon(Icons.refresh))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(redTurn ? Icons.circle : Icons.circle_outlined),
                    const SizedBox(width: 10),
                    Expanded(child: Text(message, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
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
                        onTap: () => tapCell(r, c),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Text('هذه نسخة محلية أولى. لاحقًا نفس الحركات سيتم إرسالها عبر الشبكة بين جهازين.'),
          ),
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
    required this.onTap,
  });

  final int row;
  final int col;
  final Piece piece;
  final bool selected;
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
                  ? const Color(0xFF56736D)
                  : const Color(0xFFE8EFEA),
          border: Border.all(color: Colors.white.withOpacity(0.7), width: 0.5),
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
    final isKing = piece == Piece.redKing || piece == Piece.blackKing;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isRed ? const Color(0xFFC84C4C) : const Color(0xFF222831),
        boxShadow: const [BoxShadow(blurRadius: 4, offset: Offset(1, 2), color: Colors.black26)],
      ),
      child: isKing ? const Icon(Icons.star, color: Colors.white, size: 18) : null,
    );
  }
}
