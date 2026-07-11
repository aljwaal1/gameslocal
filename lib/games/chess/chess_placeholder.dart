import 'package:flutter/material.dart';

import '../../core/audio_feedback.dart';

enum ChessSide { white, black }

class ChessPiece {
  const ChessPiece(this.symbol, this.side);
  final String symbol;
  final ChessSide side;
}

class ChessPlaceholderScreen extends StatefulWidget {
  const ChessPlaceholderScreen({super.key});

  @override
  State<ChessPlaceholderScreen> createState() => _ChessPlaceholderScreenState();
}

class _ChessPlaceholderScreenState extends State<ChessPlaceholderScreen> {
  late List<ChessPiece?> board;
  ChessSide turn = ChessSide.white;
  int? selected;
  List<int> targets = <int>[];
  String message = 'دور الأبيض';
  final List<List<ChessPiece?>> history = <List<ChessPiece?>>[];
  final List<ChessSide> turnHistory = <ChessSide>[];
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
      moveCount++;
      final moving = board[selected!];
      final captured = board[index];
      board[index] = moving;
      board[selected!] = null;
      if ((moving?.symbol == '♙' && index ~/ 8 == 0) || (moving?.symbol == '♟' && index ~/ 8 == 7)) {
        board[index] = ChessPiece(moving!.side == ChessSide.white ? '♕' : '♛', moving.side);
      }
      selected = null;
      targets = <int>[];
      if (captured?.symbol == '♔' || captured?.symbol == '♚') {
        message = turn == ChessSide.white ? 'فاز الأبيض' : 'فاز الأسود';
        GameFeedback.win();
      } else {
        turn = turn == ChessSide.white ? ChessSide.black : ChessSide.white;
        message = turn == ChessSide.white ? 'دور الأبيض' : 'دور الأسود';
        GameFeedback.move();
      }
      setState(() {});
      return;
    }
    if (piece == null || piece.side != turn || message.startsWith('فاز')) {
      setState(() { selected = null; targets = <int>[]; });
      return;
    }
    setState(() {
      selected = index;
      targets = _moves(index, piece);
    });
  }

  void _undo() {
    if (history.isEmpty) return;
    setState(() {
      board = history.removeLast();
      turn = turnHistory.removeLast();
      moveCount = (moveCount - 1).clamp(0, 999).toInt();
      selected = null;
      targets = <int>[];
      message = turn == ChessSide.white ? 'دور الأبيض' : 'دور الأسود';
    });
    GameFeedback.tap();
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
    } else {
      if ('♖♜♕♛'.contains(piece.symbol)) for (final d in const [[-1,0],[1,0],[0,-1],[0,1]]) ray(d[0],d[1]);
      if ('♗♝♕♛'.contains(piece.symbol)) for (final d in const [[-1,-1],[-1,1],[1,-1],[1,1]]) ray(d[0],d[1]);
    }
    return out;
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
            return InkWell(onTap: ()=>_tap(i), child: Container(
              color: targets.contains(i) ? Colors.amber : (selected==i ? Colors.orange : (dark ? const Color(0xFF769656) : const Color(0xFFEEEED2))),
              alignment: Alignment.center,
              child: Text(board[i]?.symbol ?? '', style: const TextStyle(fontSize: 34, color: Colors.black)),
            ));
          },
        )))),
        const Padding(padding: EdgeInsets.all(12), child: Text('لعب محلي للاعبين • تراجع عن النقلة • ترقية البيدق تلقائياً إلى وزير')),
      ])),
    );
  }
}
