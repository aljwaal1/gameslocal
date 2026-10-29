import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/app_settings.dart';
import '../../core/audio_feedback.dart';
import '../../core/network/local_network_core.dart';
import '../../core/network/network_message.dart';

enum ChessSide { white, black }

class ChessPiece {
  const ChessPiece(this.symbol, this.side);
  final String symbol;
  final ChessSide side;
}

class ChessGameScreen extends StatefulWidget {
  const ChessGameScreen({super.key, this.networkCore});

  final LocalNetworkCore? networkCore;

  @override
  State<ChessGameScreen> createState() => _ChessGameScreenState();
}

class _ChessGameScreenState extends State<ChessGameScreen> {
  final AppSettingsController settings = AppSettingsController.instance;
  final Random random = Random();
  StreamSubscription<NetworkMessage>? _networkSubscription;
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
  bool playVsBot = true;
  bool botThinking = false;

  bool get isNetworkGame => widget.networkCore != null;
  bool get isHost =>
      widget.networkCore?.state.mode != LocalNetworkMode.client;
  ChessSide get localSide => isHost ? ChessSide.white : ChessSide.black;
  String get localPlayerId => widget.networkCore?.localPlayerId ?? 'local';

  @override
  void initState() {
    super.initState();
    playVsBot = !isNetworkGame;
    _networkSubscription =
        widget.networkCore?.messages.listen(_handleNetworkMessage);
    _newGame();
  }

  @override
  void dispose() {
    _networkSubscription?.cancel();
    super.dispose();
  }

  void _newGame() {
    const blackBack = ['♜', '♞', '♝', '♛', '♚', '♝', '♞', '♜'];
    const whiteBack = ['♖', '♘', '♗', '♕', '♔', '♗', '♘', '♖'];
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
    botThinking = false;
    selected = null;
    targets = <int>[];
    message = isNetworkGame && !isHost ? 'بانتظار نقلة الأبيض' : 'دور الأبيض';
    if (mounted) setState(() {});
  }

  void _tap(int index) {
    if (botThinking || (isNetworkGame && turn != localSide)) return;
    final piece = board[index];
    if (selected != null && targets.contains(index)) {
      final from = selected!;
      _makeMove(from, index, notifyPeer: isNetworkGame);
      return;
    }
    if (piece == null ||
        piece.side != turn ||
        message.startsWith('كش مات') ||
        message.startsWith('تعادل')) {
      setState(() {
        selected = null;
        targets = <int>[];
      });
      return;
    }
    setState(() {
      selected = index;
      targets = _legalMoves(index, piece);
    });
  }

  void _makeMove(int from, int to, {required bool notifyPeer}) {
    final moving = board[from];
    if (moving == null || moving.side != turn || !_legalMoves(from, moving).contains(to)) {
      return;
    }
    history.add(List<ChessPiece?>.from(board));
    turnHistory.add(turn);
    castlingHistory.add(_CastlingRights(
      whiteKingMoved,
      blackKingMoved,
      whiteLeftRookMoved,
      whiteRightRookMoved,
      blackLeftRookMoved,
      blackRightRookMoved,
    ));
    moveCount++;
    board[to] = moving;
    board[from] = null;
    _applyCastlingRookMove(moving, from, to);
    _markCastlingPieceMoved(moving, from);
    if ((moving.symbol == '♙' && to ~/ 8 == 0) ||
        (moving.symbol == '♟' && to ~/ 8 == 7)) {
      board[to] = ChessPiece(
        moving.side == ChessSide.white ? '♕' : '♛',
        moving.side,
      );
    }
    selected = null;
    targets = <int>[];
    turn = turn == ChessSide.white ? ChessSide.black : ChessSide.white;
    _updateStatus();
    if (notifyPeer) {
      widget.networkCore?.sendMove(
        <String, dynamic>{'action': 'chess_move', 'from': from, 'to': to},
        senderId: localPlayerId,
      );
    }
    setState(() {});
    if (playVsBot && turn == ChessSide.black && !_gameFinished) {
      unawaited(_runBotMove());
    }
  }

  bool get _gameFinished =>
      message.startsWith('كش مات') || message.startsWith('تعادل');

  void _updateStatus() {
    final checked = _isKingInCheck(turn);
    final hasMove = _hasAnyLegalMove(turn);
    if (checked && !hasMove) {
      message = turn == ChessSide.white
          ? 'كش مات — فاز الأسود'
          : 'كش مات — فاز الأبيض';
      GameFeedback.win(GameAudioTheme.chess);
    } else if (!checked && !hasMove) {
      message = 'تعادل — لا توجد نقلة قانونية';
      GameFeedback.tap(GameAudioTheme.chess);
    } else {
      message = checked
          ? (turn == ChessSide.white ? 'كش على الأبيض' : 'كش على الأسود')
          : (turn == ChessSide.white ? 'دور الأبيض' : 'دور الأسود');
      GameFeedback.move(GameAudioTheme.chess);
    }
  }

  void _handleNetworkMessage(NetworkMessage networkMessage) {
    if (!mounted || networkMessage.senderId == localPlayerId) return;
    if (networkMessage.type == NetworkMessageType.disconnect) {
      setState(() => message = 'انقطع اتصال اللاعب الآخر');
      return;
    }
    if (networkMessage.type != NetworkMessageType.move) return;
    final payload = networkMessage.payload;
    if (payload['action'] == 'chess_move') {
      final from = (payload['from'] as num?)?.toInt() ?? -1;
      final to = (payload['to'] as num?)?.toInt() ?? -1;
      if (from >= 0 && to >= 0) _makeMove(from, to, notifyPeer: false);
    } else if (payload['action'] == 'chess_reset') {
      _newGame();
    }
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
    GameFeedback.tap(GameAudioTheme.chess);
  }

  Future<void> _runBotMove() async {
    setState(() {
      botThinking = true;
      message = "الروبوت (${settings.botDifficultyTextFor('chess')}) يفكر...";
    });
    await Future<void>.delayed(const Duration(milliseconds: 520));
    if (!mounted || turn != ChessSide.black || _gameFinished) return;
    final moves = _allMoves(ChessSide.black);
    if (moves.isEmpty) {
      botThinking = false;
      _updateStatus();
      setState(() {});
      return;
    }
    final chosen = _chooseBotMove(moves);
    botThinking = false;
    _makeMove(chosen.$1, chosen.$2, notifyPeer: false);
  }

  List<(int, int)> _allMoves(ChessSide side) {
    final result = <(int, int)>[];
    for (var from = 0; from < board.length; from++) {
      final piece = board[from];
      if (piece == null || piece.side != side) continue;
      for (final to in _legalMoves(from, piece)) {
        result.add((from, to));
      }
    }
    return result;
  }

  (int, int) _chooseBotMove(List<(int, int)> moves) {
    final difficulty = settings.botDifficultyFor('chess');
    if (difficulty == BotDifficulty.easy) {
      return moves[random.nextInt(moves.length)];
    }
    final scored = <((int, int), int)>[
      for (final move in moves) (move, _scoreBotMove(move.$1, move.$2)),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    if (difficulty == BotDifficulty.normal) {
      final useful = scored.where((entry) => entry.$2 >= 100).toList();
      return useful.isEmpty
          ? moves[random.nextInt(moves.length)]
          : useful[random.nextInt(useful.length.clamp(1, 3).toInt())].$1;
    }
    return scored.first.$1;
  }

  int _scoreBotMove(int from, int to) {
    final moving = board[from]!;
    final captured = board[to];
    var score = _pieceValue(captured?.symbol) * 100;
    final original = board[to];
    board[to] = moving;
    board[from] = null;
    if (_isKingInCheck(ChessSide.white)) score += 35;
    if (_isSquareAttacked(to, ChessSide.white)) {
      score -= _pieceValue(moving.symbol) * 35;
    }
    final row = to ~/ 8;
    final column = to % 8;
    score += 8 - ((row - 3).abs() + (column - 3).abs());
    board[from] = moving;
    board[to] = original;
    return score;
  }

  int _pieceValue(String? symbol) {
    if (symbol == null) return 0;
    if ('♙♟'.contains(symbol)) return 1;
    if ('♘♞♗♝'.contains(symbol)) return 3;
    if ('♖♜'.contains(symbol)) return 5;
    if ('♕♛'.contains(symbol)) return 9;
    return 0;
  }

  void _resetGame({bool notifyPeer = true}) {
    _newGame();
    if (isNetworkGame && notifyPeer) {
      widget.networkCore?.sendMove(
        <String, dynamic>{'action': 'chess_reset'},
        senderId: localPlayerId,
      );
    }
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
      if (piece != null &&
          piece.side == side &&
          _legalMoves(i, piece).isNotEmpty) return true;
    }
    return false;
  }

  bool _isKingInCheck(ChessSide side) {
    final kingSymbol = side == ChessSide.white ? '♔' : '♚';
    final king = board.indexWhere((piece) => piece?.symbol == kingSymbol);
    if (king < 0) return true;
    final opponent =
        side == ChessSide.white ? ChessSide.black : ChessSide.white;
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
        if (targetRow == row + direction && (targetCol - col).abs() == 1)
          return true;
      } else if ('♔♚'.contains(piece.symbol)) {
        if ((targetRow - row).abs() <= 1 && (targetCol - col).abs() <= 1)
          return true;
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
        nr += dr;
        nc += dc;
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
      for (final d in const [
        [-2, -1],
        [-2, 1],
        [-1, -2],
        [-1, 2],
        [1, -2],
        [1, 2],
        [2, -1],
        [2, 1]
      ]) add(r + d[0], c + d[1]);
    } else if ('♔♚'.contains(piece.symbol)) {
      for (var dr = -1; dr <= 1; dr++)
        for (var dc = -1; dc <= 1; dc++)
          if (dr != 0 || dc != 0) add(r + dr, c + dc);
      _addCastlingMoves(index, piece, out);
    } else {
      if ('♖♜♕♛'.contains(piece.symbol))
        for (final d in const [
          [-1, 0],
          [1, 0],
          [0, -1],
          [0, 1]
        ]) ray(d[0], d[1]);
      if ('♗♝♕♛'.contains(piece.symbol))
        for (final d in const [
          [-1, -1],
          [-1, 1],
          [1, -1],
          [1, 1]
        ]) ray(d[0], d[1]);
    }
    return out;
  }

  void _addCastlingMoves(int index, ChessPiece king, List<int> out) {
    final isWhite = king.side == ChessSide.white;
    final row = isWhite ? 7 : 0;
    final home = row * 8 + 4;
    if (index != home ||
        _isKingInCheck(king.side) ||
        (isWhite ? whiteKingMoved : blackKingMoved)) return;
    final opponent = isWhite ? ChessSide.black : ChessSide.white;
    final rookSymbol = isWhite ? '♖' : '♜';
    final leftRookMoved = isWhite ? whiteLeftRookMoved : blackLeftRookMoved;
    final rightRookMoved = isWhite ? whiteRightRookMoved : blackRightRookMoved;
    final kingSideRook = board[row * 8 + 7];
    if (!rightRookMoved &&
        kingSideRook?.symbol == rookSymbol &&
        board[row * 8 + 5] == null &&
        board[row * 8 + 6] == null &&
        !_isSquareAttacked(row * 8 + 5, opponent) &&
        !_isSquareAttacked(row * 8 + 6, opponent)) {
      out.add(row * 8 + 6);
    }
    final queenSideRook = board[row * 8];
    if (!leftRookMoved &&
        queenSideRook?.symbol == rookSymbol &&
        board[row * 8 + 1] == null &&
        board[row * 8 + 2] == null &&
        board[row * 8 + 3] == null &&
        !_isSquareAttacked(row * 8 + 3, opponent) &&
        !_isSquareAttacked(row * 8 + 2, opponent)) {
      out.add(row * 8 + 2);
    }
  }

  void _applyCastlingRookMove(ChessPiece? moving, int from, int to) {
    if (moving == null ||
        !'♔♚'.contains(moving.symbol) ||
        (to - from).abs() != 2) return;
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
      appBar: AppBar(title: const Text('الشطرنج'), actions: [
        if (!isNetworkGame)
          IconButton(
            onPressed: () {
              setState(() => playVsBot = !playVsBot);
              _resetGame(notifyPeer: false);
            },
            tooltip: playVsBot ? 'التحويل إلى لاعبين محليًا' : 'اللعب ضد الروبوت',
            icon: Icon(playVsBot ? Icons.smart_toy_rounded : Icons.people_rounded),
          ),
        IconButton(
            onPressed: history.isEmpty || isNetworkGame || playVsBot ? null : _undo,
            tooltip: 'تراجع',
            icon: const Icon(Icons.undo)),
        IconButton(
            onPressed: _resetGame,
            tooltip: 'لعبة جديدة',
            icon: const Icon(Icons.refresh))
      ]),
      body: SafeArea(
          child: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(message,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Chip(label: Text('نقلة $moveCount'))
                ])),
        if (playVsBot && !isNetworkGame)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              "ضد الروبوت • المستوى ${settings.botDifficultyTextFor('chess')}",
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        Expanded(
            child: Center(
                child: AspectRatio(
                    aspectRatio: 1,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 8),
                      itemCount: 64,
                      itemBuilder: (_, i) {
                        final r = i ~/ 8, c = i % 8, dark = (r + c).isOdd;
                        final isTarget = targets.contains(i);
                        final isCapture = isTarget && board[i] != null;
                        return InkWell(
                          onTap: () => _tap(i),
                          child: Container(
                            decoration: BoxDecoration(
                              color: dark
                                  ? const Color(0xFF1F5D50)
                                  : const Color(0xFFF0E5C9),
                              border: selected == i
                                  ? Border.all(
                                      color: const Color(0xFFFFB703), width: 3)
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (isTarget && !isCapture)
                                  Container(
                                      width: 16,
                                      height: 16,
                                      decoration: const BoxDecoration(
                                          color: Color(0xAA1B5E20),
                                          shape: BoxShape.circle)),
                                if (isTarget && isCapture)
                                  Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.red.shade700,
                                              width: 3))),
                                Text(board[i]?.symbol ?? '',
                                    style: const TextStyle(
                                        fontSize: 32, color: Color(0xFF0F172A))),
                              ],
                            ),
                          ),
                        );
                      },
                    )))),
      ])),
    );
  }
}

class _CastlingRights {
  const _CastlingRights(
      this.whiteKingMoved,
      this.blackKingMoved,
      this.whiteLeftRookMoved,
      this.whiteRightRookMoved,
      this.blackLeftRookMoved,
      this.blackRightRookMoved);
  final bool whiteKingMoved,
      blackKingMoved,
      whiteLeftRookMoved,
      whiteRightRookMoved,
      blackLeftRookMoved,
      blackRightRookMoved;
}
