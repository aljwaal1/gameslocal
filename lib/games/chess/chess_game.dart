import 'package:flutter/material.dart';

import '../../core/audio_feedback.dart';

enum ChessSide { white, black }

class ChessPiece {
  const ChessPiece(this.symbol, this.side);
  final String symbol;
  final ChessSide side;
}

class ChessGameScreen extends StatefulWidget {
  const ChessGameScreen({super.key});

  @override
  State<ChessGameScreen> createState() => _ChessGameScreenState();
}

class _ChessGameScreenState extends State<ChessGameScreen> {
  late List<ChessPiece?> board;
  ChessSide turn = ChessSide.white;
  int? selected;
  List<int> targets = <int>[];
  String message = 'دور الأبيض';
  final List<List<ChessPiece?>> history = <List<ChessPiece?>>[];
  final List<ChessSide> turnHistory = <ChessSide>[];
  final List<_CastlingRights> castlingHistory = <_CastlingRights>[];
  bool whiteKingMoved = false;
  bool blackKingMoved = false;
  bool whiteLeftRookMoved = false;
  bool whiteRightRookMoved = false;
  bool blackLeftRookMoved = false;
  bool blackRightRookMoved = false;
  int moveCount = 0;

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  void _newGame() {
    const blackBack = ['♜','♞','♝','♛','♚','♝','♞','♜'];
    const whiteBack = ['♖','♘','♗','♕','♔','♗','♘','♖'];
    board = List<ChessPiece?>.filled(64, null);
    for (var i = 0; i < 8; i++) {
      board[i] = ChessPiece(blackBack[i], ChessSide.black);
      board[8 + i] = const ChessPiece('♟', ChessSide.black);
      board[48 + i] = const ChessPiece('♙', ChessSide.white);
      board[56 + i] = ChessPiece(whiteBack[i], ChessSide.white);
    }
    turn = ChessSide.white;
    history.clear();
    turnHistory.clear();
    castlingHistory.clear();
    whiteKingMoved = false;
    blackKingMoved = false;
    whiteLeftRookMoved = false;
    whiteRightRookMoved = false;
    blackLeftRookMoved = false;
    blackRightRookMoved = false;
    moveCount = 0;
    selected = null;
    targets = <int>[];
    message = 'دور الأبيض';
    if (mounted) setState(() {});
  }

  void _tap(int index) {
    final piece = board[index];
    if (selected != null && targets.contains(index)) {
      history.add(List<ChessPiece?>.from(board));
      turnHistory.add(turn);
      castlingHistory.add(_CastlingRights(
        whiteKingMoved, blackKingMoved, whiteLeftRookMoved, whiteRightRookMoved,
        blackLeftRookMoved, blackRightRookMoved,
      ));
      moveCount++;
      final moving = board[selected!];
      board[index] = moving;
      board[selected!] = null;
      _applyCastlingRookMove(moving, selected!, index);
      _markCastlingPieceMoved(moving, selected!);
      if ((moving?.symbol == '♙' && index ~/ 8 == 0) || (moving?.symbol == '♟' && index ~/ 8 == 7)) {
        board[index] = ChessPiece(moving!.side == ChessSide.white ? '♕' : '♛', moving.side);
      }
      selected = null;
      targets = <int>[];
      turn = turn == ChessSide.white ? ChessSide.black : ChessSide.white;
      final checked = _isKingInCheck(turn);
      final hasMove = _hasAnyLegalMove(turn);
      if (checked && !hasMove) {
        message = turn == ChessSide.white ? 'كش مات — فاز الأسود' : 'كش مات — فاز الأبيض';
        GameFeedback.win();
      } else if (!checked && !hasMove) {
        message = 'تعادل — لا توجد نقلة قانونية';
        GameFeedback.tap();
      } else {
        message = checked
            ? (turn == ChessSide.white ? 'كش على الأبيض' : 'كش على الأسود')
            : (turn == ChessSide.white ? 'دور الأبيض' : 'دور الأسود');
        GameFeedback.move();
      }
      setState(() {});
      return;
    }
    if (piece == null || piece.side != turn || message.startsWith('كش مات') || message.startsWith('تعادل')) {
      setState(() { selected = null; targets = <int>[]; });
      return;
    }
    setState(() {
      selected = index;
      targets = _legalMoves(index, piece);
    });
  }

  void _undo() {
    if (history.isEmpty) return;
    setState(() {
      board = history.removeLast();
      turn = turnHistory.removeLast();
      final rights = castlingHistory.removeLast();
      whiteKingMoved = rights.whiteKingMoved;
      blackKingMoved = rights.blackKingMoved;
      whiteLeftRookMoved = rights.whiteLeftRookMoved;
      whiteRightRookMoved = rights.whiteRightRookMoved;
      blackLeftRookMoved = rights.blackLeftRookMoved;
      blackRightRookMoved = rights.blackRightRookMoved;
      moveCount = (moveCount - 1).clamp(0, 999).toInt();
      selected = null;
      targets = <int>[];
      message = turn == ChessSide.white ? 'دور الأبيض' : 'دور الأسود';
    });
    GameFeedback.tap();
  }

  List<int> _legalMoves(int index, ChessPiece piece) {
    return _moves(index, piece).where((target) {
      final captured = board[target];
      if (captured?.symbol == '♔' || captured?.symbol == '♚') return false;
      final original = board[index];
      board[target] = original;
      board[index] = null;
      final leavesKingChecked = _isKingInCheck(piece.side);
      board[index] = original;
      board[target] = captured;
      return !leavesKingChecked;
    }).toList();
  }

  bool _hasAnyLegalMove(ChessSide side) {
    for (var i = 0; i < board.length; i++) {
      final piece = board[i];
      if (piece != null && piece.side == side && _legalMoves(i, piece).isNotEmpty) return true;
    }
    return false;
  }

  bool _isKingInCheck(ChessSide side) {
    final kingSymbol = side == ChessSide.white ? '♔' : '♚';
    final king = board.indexWhere((piece) => piece?.symbol == kingSymbol);
    if (king < 0) return true;
    final opponent = side == ChessSide.white ? ChessSide.black : ChessSide.white;
    return _isSquareAttacked(king, opponent);
  }

  bool _isSquareAttacked(int square, ChessSide bySide) {
    final targetRow = square ~/ 8;
    final targetCol = square % 8;
    for (var i = 0; i < board.length; i++) {
      final piece = board[i];
      if (piece == null || piece.side != bySide) continue;
      final row = i ~/ 8;
      final col = i % 8;
      if ('♙♟'.contains(piece.symbol)) {
        final direction = bySide == ChessSide.white ? -1 : 1;
        if (targetRow == row + direction && (targetCol - col).abs() == 1) return true;
      } else if (_moves(i, piece).contains(square)) {
        return true;
      }
    }
    return false;
  }

  List<int> _moves(int index, ChessPiece piece) {
    final r = index ~/ 8, c = index % 8;
    final out = <int>[];
    void add(int nr, int nc) {
      if (nr < 0 || nr > 7 || nc < 0 || nc > 7) return;
      final target = board[nr * 8 + nc];
      if (target == null || target.side != piece.side) out.add(nr * 8 + nc);
    }
    void ray(int dr, int dc) {
      var nr = r + dr, nc = c + dc;
      while (nr >= 0 && nr < 8 && nc >= 0 && nc < 8) {
        final i = nr * 8 + nc, target = board[i];
        if (target == null) {
          out.add(i);
        } else {
          if (target.side != piece.side) out.add(i);
          break;
        }
        nr += dr; nc += dc;
      }
    }
    if ('♙♟'.contains(piece.symbol)) {
      final d = piece.side == ChessSide.white ? -1 : 1;
      final one = (r + d) * 8 + c;
      if (r + d >= 0 && r + d < 8 && board[one] == null) {
        out.add(one);
        final start = piece.side == ChessSide.white ? 6 : 1;
        final two = (r + d * 2) * 8 + c;
        if (r == start && board[two] == null) out.add(two);
      }
      for (final dc in [-1, 1]) {
        final nr = r + d, nc = c + dc;
        if (nr >= 0 && nr < 8 && nc >= 0 && nc < 8) {
          final target = board[nr * 8 + nc];
          if (target != null && target.side != piece.side) out.add(nr * 8 + nc);
        }
      }
    } else if ('♘♞'.contains(piece.symbol)) {
      for (final d in const [[-2,-1],[-2,1],[-1,-2],[-1,2],[1,-2],[1,2],[2,-1],[2,1]]) add(r+d[0], c+d[1]);
    } else if ('♔♚'.contains(piece.symbol)) {
      for (var dr=-1; dr<=1; dr++) for (var dc=-1; dc<=1; dc++) if (dr!=0 || dc!=0) add(r+dr,c+dc);
      _addCastlingMoves(index, piece, out);
    } else {
      if ('♖♜♕♛'.contains(piece.symbol)) for (final d in const [[-1,0],[1,0],[0,-1],[0,1]]) ray(d[0],d[1]);
      if ('♗♝♕♛'.contains(piece.symbol)) for (final d in const [[-1,-1],[-1,1],[1,-1],[1,1]]) ray(d[0],d[1]);
    }
    return out;
  }

  void _addCastlingMoves(int index, ChessPiece king, List<int> out) {
    final isWhite = king.side == ChessSide.white;
    final row = isWhite ? 7 : 0;
    final home = row * 8 + 4;
    if (index != home || _isKingInCheck(king.side) || (isWhite ? whiteKingMoved : blackKingMoved)) return;
    final opponent = isWhite ? ChessSide.black : ChessSide.white;
    final rookSymbol = isWhite ? '♖' : '♜';
    final leftRookMoved = isWhite ? whiteLeftRookMoved : blackLeftRookMoved;
    final rightRookMoved = isWhite ? whiteRightRookMoved : blackRightRookMoved;
    final kingSideRook = board[row * 8 + 7];
    if (!rightRookMoved && kingSideRook?.symbol == rookSymbol &&
        board[row * 8 + 5] == null && board[row * 8 + 6] == null &&
        !_isSquareAttacked(row * 8 + 5, opponent) && !_isSquareAttacked(row * 8 + 6, opponent)) {
      out.add(row * 8 + 6);
    }
    final queenSideRook = board[row * 8];
    if (!leftRookMoved && queenSideRook?.symbol == rookSymbol &&
        board[row * 8 + 1] == null && board[row * 8 + 2] == null && board[row * 8 + 3] == null &&
        !_isSquareAttacked(row * 8 + 3, opponent) && !_isSquareAttacked(row * 8 + 2, opponent)) {
      out.add(row * 8 + 2);
    }
  }

  void _applyCastlingRookMove(ChessPiece? moving, int from, int to) {
    if (moving == null || !'♔♚'.contains(moving.symbol) || (to - from).abs() != 2) return;
    final row = from ~/ 8;
    if (to > from) {
      board[row * 8 + 5] = board[row * 8 + 7];
      board[row * 8 + 7] = null;
    } else {
      board[row * 8 + 3] = board[row * 8];
      board[row * 8] = null;
    }
  }

  void _markCastlingPieceMoved(ChessPiece? piece, int from) {
    if (piece == null) return;
    if (piece.symbol == '♔') whiteKingMoved = true;
    if (piece.symbol == '♚') blackKingMoved = true;
    if (from == 56) whiteLeftRookMoved = true;
    if (from == 63) whiteRightRookMoved = true;
    if (from == 0) blackLeftRookMoved = true;
    if (from == 7) blackRightRookMoved = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الشطرنج'), actions: [IconButton(onPressed: history.isEmpty ? null : _undo, tooltip: 'تراجع', icon: const Icon(Icons.undo)), IconButton(onPressed: _newGame, tooltip: 'لعبة جديدة', icon: const Icon(Icons.refresh))]),
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(message, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), Chip(label: Text('نقلة $moveCount'))])),
        Expanded(child: Center(child: AspectRatio(aspectRatio: 1, child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
          itemCount: 64,
          itemBuilder: (_, i) {
            final r=i~/8,c=i%8, dark=(r+c).isOdd;
            final isTarget = targets.contains(i);
            final isCapture = isTarget && board[i] != null;
            return InkWell(
              onTap: () => _tap(i),
              child: Container(
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF769656) : const Color(0xFFEEEED2),
                  border: selected == i ? Border.all(color: Colors.orange.shade800, width: 3) : null,
                ),
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isTarget && !isCapture)
                      Container(width: 16, height: 16, decoration: const BoxDecoration(color: Color(0xAA1B5E20), shape: BoxShape.circle)),
                    if (isTarget && isCapture)
                      Container(width: 38, height: 38, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.red.shade700, width: 3))),
                    Text(board[i]?.symbol ?? '', style: const TextStyle(fontSize: 34, color: Colors.black)),
                  ],
                ),
              ),
            );
          },
        )))),
        const Padding(padding: EdgeInsets.all(12), child: Text('شطرنج قانوني: كش وكش مات وتعادل • تراجع • ترقية البيدق')),
      ])),
    );
  }
}

class _CastlingRights {
  const _CastlingRights(this.whiteKingMoved, this.blackKingMoved, this.whiteLeftRookMoved, this.whiteRightRookMoved, this.blackLeftRookMoved, this.blackRightRookMoved);
  final bool whiteKingMoved, blackKingMoved, whiteLeftRookMoved, whiteRightRookMoved, blackLeftRookMoved, blackRightRookMoved;
}
