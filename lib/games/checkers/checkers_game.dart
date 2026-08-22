import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/app_settings.dart';
import '../../core/iphone_game_bridge.dart';
import '../../core/audio_feedback.dart';
import '../../core/pregame_qr_lobby.dart';
import '../../core/network/local_network_core.dart';
import '../../core/network/network_message.dart';
import '../../design/app_theme.dart';

import 'checkers_match_status.dart';
import 'checkers_iphone_web.dart';

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

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'fromRow': fromRow,
      'fromCol': fromCol,
      'toRow': toRow,
      'toCol': toCol,
      'captureRow': captureRow,
      'captureCol': captureCol,
    };
  }

  factory CheckersMove.fromJson(Map<String, dynamic> json) {
    return CheckersMove(
      fromRow: (json['fromRow'] as num).toInt(),
      fromCol: (json['fromCol'] as num).toInt(),
      toRow: (json['toRow'] as num).toInt(),
      toCol: (json['toCol'] as num).toInt(),
      captureRow: (json['captureRow'] as num?)?.toInt(),
      captureCol: (json['captureCol'] as num?)?.toInt(),
    );
  }
}

class CheckersMoveRules {
  const CheckersMoveRules._();

  /// When one or more captures are available, non-capturing moves are illegal.
  static List<CheckersMove> requireCapture(Iterable<CheckersMove> moves) {
    final allMoves = moves.toList(growable: false);
    final captures =
        allMoves.where((move) => move.isCapture).toList(growable: false);
    return captures.isNotEmpty ? captures : allMoves;
  }

  static List<CheckersMove> capturesFrom(
    Iterable<CheckersMove> legalMoves, {
    required int row,
    required int col,
  }) {
    return legalMoves
        .where(
          (move) =>
              move.isCapture && move.fromRow == row && move.fromCol == col,
        )
        .toList(growable: false);
  }

  /// A capture chain may continue only from the piece that made the last capture.
  static List<CheckersMove> chainedCaptures(
    Iterable<CheckersMove> legalMoves,
    CheckersMove previousMove,
  ) {
    return capturesFrom(
      legalMoves,
      row: previousMove.toRow,
      col: previousMove.toCol,
    );
  }
}

class CheckersGameScreen extends StatefulWidget {
  const CheckersGameScreen({super.key, this.networkCore});

  final LocalNetworkCore? networkCore;

  @override
  State<CheckersGameScreen> createState() => _CheckersGameScreenState();
}

class _CheckersGameScreenState extends State<CheckersGameScreen> {
  final settings = AppSettingsController.instance;
  final random = Random();

  late List<List<Piece>> board;
  StreamSubscription<NetworkMessage>? networkSubscription;
  IphoneGameBridge? _iphoneBridge;
  StreamSubscription<List<IphoneWebPlayer>>? _iphonePlayersSub;
  StreamSubscription<IphoneWebEvent>? _iphoneEventsSub;
  String _iphoneUrl = '';
  int _iphonePlayers = 0;
  bool _showNetworkQrLobby = true;
  int? selectedRow;
  int? selectedCol;
  bool redTurn = true;
  bool playVsBot = true;
  bool botThinking = false;
  bool mustContinueCapture = false;
  String message = 'دور الأحمر';
  CheckersMatchStatus? matchStatus;
  bool resultDialogVisible = false;

  bool get gameFinished => matchStatus?.isFinished ?? false;
  int get redPieceCount => board.expand((row) => row).where(isRedPiece).length;
  int get blackPieceCount =>
      board.expand((row) => row).where(isBlackPiece).length;

  bool get networkMode =>
      widget.networkCore != null &&
      widget.networkCore!.state.mode != LocalNetworkMode.idle;
  bool get localPlayerIsRed =>
      widget.networkCore?.state.mode != LocalNetworkMode.client;
  bool get isMyNetworkTurn => !networkMode || redTurn == localPlayerIsRed;
  bool get hasAndroidGuest =>
      widget.networkCore?.state.players
          .any((LocalPlayer player) => !player.isHost) ??
      false;
  Set<String> get forcedCaptureSources => allLegalMoves(forRed: redTurn)
      .where((move) => move.isCapture)
      .map((move) => '${move.fromRow},${move.fromCol}')
      .toSet();

  @override
  void initState() {
    super.initState();
    playVsBot = !networkMode;
    networkSubscription =
        widget.networkCore?.messages.listen(_handleNetworkMessage);
    resetBoard();
    if (networkMode && localPlayerIsRed) {
      unawaited(_startIphoneBridge());
    }
  }

  @override
  void dispose() {
    networkSubscription?.cancel();
    _iphonePlayersSub?.cancel();
    _iphoneEventsSub?.cancel();
    unawaited(_iphoneBridge?.dispose());
    super.dispose();
  }

  void resetBoard() {
    board = List.generate(8, (_) => List.filled(8, Piece.empty));

    for (int r = 1; r <= 2; r++) {
      for (int c = 0; c < 8; c++) {
        board[r][c] = Piece.black;
      }
    }
    for (int r = 5; r <= 6; r++) {
      for (int c = 0; c < 8; c++) {
        board[r][c] = Piece.red;
      }
    }

    selectedRow = null;
    selectedCol = null;
    redTurn = true;
    botThinking = false;
    mustContinueCapture = false;
    matchStatus = null;
    resultDialogVisible = false;
    message = currentTurnMessage();
    if (mounted) setState(() {});
    _broadcastIphoneState();
  }

  void requestBoardReset() {
    if (networkMode) {
      GameFeedback.error(GameAudioTheme.checkers);
      setState(() => message =
          'إعادة الضبط متوقفة أثناء اللعب عبر Wi‑Fi حتى لا تختلف اللوحة بين الجهازين');
      return;
    }

    resetBoard();
  }

  bool isRedPiece(Piece p) => p == Piece.red || p == Piece.redKing;
  bool isBlackPiece(Piece p) => p == Piece.black || p == Piece.blackKing;
  bool isKing(Piece p) => p == Piece.redKing || p == Piece.blackKing;
  bool isCurrentPlayerPiece(Piece p) =>
      redTurn ? isRedPiece(p) : isBlackPiece(p);
  bool pieceBelongsToTurn(Piece p, bool forRed) =>
      forRed ? isRedPiece(p) : isBlackPiece(p);
  bool opponentForTurn(Piece p, bool forRed) =>
      forRed ? isBlackPiece(p) : isRedPiece(p);

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

  Set<String> get possibleTargets {
    if (selectedRow == null || selectedCol == null) return {};
    final moves = allLegalMoves(forRed: redTurn)
        .where((m) => m.fromRow == selectedRow && m.fromCol == selectedCol)
        .map((m) => '${m.toRow},${m.toCol}')
        .toSet();
    return moves;
  }

  void tapCell(int r, int c) => _tapCell(r, c);

  void _tapCell(int r, int c, {bool fromIphone = false}) {
    if (gameFinished || botThinking) return;
    if (playVsBot && !redTurn) return;
    if (networkMode && !(fromIphone ? !redTurn : isMyNetworkTurn)) {
      GameFeedback.error(GameAudioTheme.checkers);
      setState(() => message = 'انتظر حركة اللاعب الآخر');
      return;
    }

    final piece = board[r][c];
    if (selectedRow == null) {
      if (isCurrentPlayerPiece(piece)) {
        GameFeedback.tap(GameAudioTheme.checkers);
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
      if (mustContinueCapture) {
        GameFeedback.error(GameAudioTheme.checkers);
        setState(() => message = 'يجب إكمال الأكل بالحجر نفسه');
        return;
      }
      GameFeedback.tap(GameAudioTheme.checkers);
      setState(() {
        selectedRow = null;
        selectedCol = null;
        message = currentTurnMessage();
      });
      return;
    }

    if (board[r][c] != Piece.empty) {
      if (isCurrentPlayerPiece(board[r][c])) {
        if (mustContinueCapture) {
          GameFeedback.error(GameAudioTheme.checkers);
          setState(() => message = 'يجب إكمال الأكل بالحجر نفسه');
          return;
        }
        GameFeedback.tap(GameAudioTheme.checkers);
        setState(() {
          selectedRow = r;
          selectedCol = c;
        });
      }
      return;
    }

    final move = legalMoveFor(sr, sc, r, c, redTurn);
    if (move == null) {
      GameFeedback.error(GameAudioTheme.checkers);
      setState(() => message = 'حركة غير صحيحة');
      return;
    }

    if (move.isCapture) {
      GameFeedback.capture(GameAudioTheme.checkers);
    } else {
      GameFeedback.move(GameAudioTheme.checkers);
    }
    applyMove(move);
    if (networkMode && !fromIphone) {
      widget.networkCore!.sendMove(move.toJson(), senderId: _localPlayerId());
    }
    if (updateMatchStatus()) {
      setState(() {});
      return;
    }
    if (continueCaptureIfAvailable(move)) {
      setState(() {});
      return;
    }
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
    final forwardOk =
        movingIsKing || (forRed ? dr == -1 || dr == -2 : dr == 1 || dr == 2);

    if (!forwardOk || absDr != absDc || (absDr != 1 && absDr != 2)) return null;

    if (absDr == 2) {
      final midR = (sr + r) ~/ 2;
      final midC = (sc + c) ~/ 2;
      if (!opponentForTurn(board[midR][midC], forRed)) return null;
      return CheckersMove(
          fromRow: sr,
          fromCol: sc,
          toRow: r,
          toCol: c,
          captureRow: midR,
          captureCol: midC);
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

  CheckersMove? legalMoveFor(int sr, int sc, int r, int c, bool forRed) {
    for (final move in allLegalMoves(forRed: forRed)) {
      if (move.fromRow == sr &&
          move.fromCol == sc &&
          move.toRow == r &&
          move.toCol == c) {
        return move;
      }
    }
    return null;
  }

  List<CheckersMove> captureMovesFrom(int row, int col, bool forRed) {
    return CheckersMoveRules.capturesFrom(
      allLegalMoves(forRed: forRed),
      row: row,
      col: col,
    );
  }

  bool continueCaptureIfAvailable(CheckersMove move) {
    if (!move.isCapture) return false;
    final captures = captureMovesFrom(move.toRow, move.toCol, redTurn);
    if (captures.isEmpty) return false;

    selectedRow = move.toRow;
    selectedCol = move.toCol;
    mustContinueCapture = true;
    message = 'أكمل الأكل بالحجر نفسه';
    return true;
  }

  bool updateMatchStatus() {
    final status = CheckersMatchEvaluator.evaluate(
      redPieces: redPieceCount,
      blackPieces: blackPieceCount,
      redHasMove: allLegalMoves(forRed: true).isNotEmpty,
      blackHasMove: allLegalMoves(forRed: false).isNotEmpty,
    );
    matchStatus = status;
    if (!status.isFinished) return false;

    selectedRow = null;
    selectedCol = null;
    botThinking = false;
    mustContinueCapture = false;
    message = status.resultText;
    if (status.winner == CheckersWinner.draw) {
      GameFeedback.tap(GameAudioTheme.checkers);
    } else {
      final bool localWon = status.winner ==
          (localPlayerIsRed ? CheckersWinner.red : CheckersWinner.black);
      if (!playVsBot && !networkMode || localWon) {
        GameFeedback.win(GameAudioTheme.checkers);
      } else {
        GameFeedback.lose(GameAudioTheme.checkers);
      }
    }
    _showMatchResultDialog(status);
    return true;
  }

  void _showMatchResultDialog(CheckersMatchStatus status) {
    if (resultDialogVisible || !mounted) return;
    resultDialogVisible = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('انتهت المباراة'),
          content: Text(status.resultText),
          actions: [
            if (!networkMode)
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  resetBoard();
                },
                icon: const Icon(Icons.replay),
                label: const Text('مباراة جديدة'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ).whenComplete(() {
        if (mounted) resultDialogVisible = false;
      });
    });
  }

  void finishTurn() {
    mustContinueCapture = false;
    if (updateMatchStatus()) {
      setState(() {});
      return;
    }

    redTurn = !redTurn;
    selectedRow = null;
    selectedCol = null;
    message = currentTurnMessage();
    setState(() {});
    _broadcastIphoneState();

    if (playVsBot && !redTurn) runBotMove();
  }

  String currentTurnMessage() {
    if (networkMode) {
      if (isMyNetworkTurn)
        return localPlayerIsRed ? 'أنت الأحمر - دورك' : 'أنت الأسود - دورك';
      return 'انتظار اللاعب الآخر';
    }
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

    var move = chooseBotMove();
    if (move == null) {
      updateMatchStatus();
      setState(() {});
      return;
    }

    while (move != null) {
      GameFeedback.move(GameAudioTheme.checkers);
      applyMove(move);
      if (updateMatchStatus()) {
        setState(() {});
        return;
      }

      final nextCaptures = move.isCapture
          ? captureMovesFrom(move.toRow, move.toCol, false)
          : const <CheckersMove>[];
      if (nextCaptures.isEmpty) break;

      setState(() => message = 'الكمبيوتر يكمل الأكل...');
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      move = nextCaptures[random.nextInt(nextCaptures.length)];
    }
    redTurn = true;
    botThinking = false;
    message = 'أنت الأحمر - دورك';
    setState(() {});
    _broadcastIphoneState();
  }

  CheckersMove? chooseBotMove() {
    final moves = allLegalMoves(forRed: false);
    if (moves.isEmpty) return null;

    switch (settings.botDifficulty) {
      case BotDifficulty.easy:
        return moves[random.nextInt(moves.length)];
      case BotDifficulty.normal:
        final captures = moves.where((m) => m.isCapture).toList();
        if (captures.isNotEmpty) return captures.first;
        moves.sort((a, b) => b.toRow.compareTo(a.toRow));
        return moves.first;
      case BotDifficulty.hard:
        moves.sort((a, b) => scoreMove(b).compareTo(scoreMove(a)));
        return moves.first;
    }
  }

  int scoreMove(CheckersMove move) {
    int score = 0;
    if (move.isCapture) score += 50;
    final moving = board[move.fromRow][move.fromCol];
    if (moving == Piece.black && move.toRow == 7) score += 40;
    if (moving == Piece.blackKing) score += 10;
    score += move.toRow * 2;
    if (move.toCol > 0 && move.toCol < 7) score += 4;
    return score;
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
                [1, 1]
              ]
            : forRed
                ? const [
                    [-1, -1],
                    [-1, 1]
                  ]
                : const [
                    [1, -1],
                    [1, 1]
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
    return CheckersMoveRules.requireCapture(moves);
  }

  bool inside(int r, int c) => r >= 0 && r < 8 && c >= 0 && c < 8;

  Piece promoteIfNeeded(Piece piece, int row) {
    if (piece == Piece.red && row == 0) return Piece.redKing;
    if (piece == Piece.black && row == 7) return Piece.blackKing;
    return piece;
  }

  String _localPlayerId() {
    final LocalNetworkCore? core = widget.networkCore;
    if (core == null || core.localPlayerId == 'system') {
      return localPlayerIsRed ? 'host-checkers' : 'client-checkers';
    }
    return core.localPlayerId;
  }

  void _handleNetworkMessage(NetworkMessage networkMessage) {
    if (!mounted ||
        !networkMode ||
        gameFinished ||
        isMyNetworkTurn ||
        networkMessage.type != NetworkMessageType.move ||
        networkMessage.senderId == _localPlayerId()) {
      return;
    }

    try {
      final move = CheckersMove.fromJson(networkMessage.payload);
      if (mustContinueCapture &&
          (selectedRow != move.fromRow || selectedCol != move.fromCol)) {
        return;
      }

      final validMove = legalMoveFor(
          move.fromRow, move.fromCol, move.toRow, move.toCol, redTurn);
      if (validMove == null) return;

      GameFeedback.move(GameAudioTheme.checkers);
      applyMove(validMove);
      if (updateMatchStatus()) {
        setState(() {});
        return;
      }
      if (continueCaptureIfAvailable(validMove)) {
        message = 'اللاعب الآخر يكمل الأكل...';
        setState(() {});
        return;
      }
      finishTurn();
    } catch (_) {
      setState(() => message = 'وصلت حركة غير صالحة من اللاعب الآخر');
    }
  }

  Future<void> _startIphoneBridge() async {
    final bridge = IphoneGameBridge(html: checkersIphoneHtml, port: 40450);
    _iphoneBridge = bridge;
    _iphonePlayersSub = bridge.players.stream.listen((players) {
      if (!mounted) return;
      setState(() => _iphonePlayers = players.length);
      _broadcastIphoneState();
    });
    _iphoneEventsSub = bridge.events.stream.listen((event) {
      if (event.type != 'tap' || redTurn || gameFinished || hasAndroidGuest) {
        return;
      }
      final row = (event.data['row'] as num?)?.toInt() ?? -1;
      final col = (event.data['col'] as num?)?.toInt() ?? -1;
      if (!inside(row, col)) return;
      _tapCell(row, col, fromIphone: true);
      _broadcastIphoneState();
    });
    try {
      final url = await bridge.start();
      if (mounted) setState(() => _iphoneUrl = url);
      _broadcastIphoneState();
    } catch (_) {
      if (mounted) setState(() => _iphoneUrl = 'تعذر تشغيل رابط الآيفون');
    }
  }

  void _broadcastIphoneState() {
    final bridge = _iphoneBridge;
    if (bridge == null) return;
    bridge.broadcast(<String, dynamic>{
      'type': 'state',
      'message': message,
      'redTurn': redTurn,
      'canPlay': !redTurn && !gameFinished && !hasAndroidGuest,
      'finished': gameFinished,
      'redCount': redPieceCount,
      'blackCount': blackPieceCount,
      'selected': selectedRow == null ? '' : '$selectedRow,$selectedCol',
      'targets': possibleTargets.toList(),
      'board':
          board.map((row) => row.map((piece) => piece.name).toList()).toList(),
    });
  }

  Widget _iphoneCard() {
    if (!networkMode || !localPlayerIsRed) return const SizedBox.shrink();
    if (hasAndroidGuest) {
      return const Card(
        color: Color(0xFFFFF4D8),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'تم اتصال لاعب أندرويد؛ تم تعطيل دخول Safari لأن الضامة مخصصة للاعبين فقط.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
    }
    return Card(
      color: const Color(0xFFEAF8F1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: <Widget>[
            const Text('دخول الآيفون',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 8),
            if (_iphoneUrl.startsWith('http'))
              QrImageView(
                  data: _iphoneUrl, size: 150, backgroundColor: Colors.white),
            SelectableText(
                _iphoneUrl.isEmpty ? 'جاري تجهيز الرابط...' : _iphoneUrl,
                textAlign: TextAlign.center),
            Text('لاعبو Safari: $_iphonePlayers'),
          ],
        ),
      ),
    );
  }

  Future<void> _showBrowserQr() async {
    if (!_iphoneUrl.startsWith('http') || hasAndroidGuest) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('الضامة عبر QR'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            QrImageView(
              data: _iphoneUrl,
              size: (MediaQuery.sizeOf(dialogContext).shortestSide * .58)
                  .clamp(120.0, 320.0)
                  .toDouble(),
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 8),
            SelectableText(_iphoneUrl, textAlign: TextAlign.center),
            Text('المتصلون: $_iphonePlayers'),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (networkMode &&
        localPlayerIsRed &&
        _showNetworkQrLobby &&
        !hasAndroidGuest) {
      return PregameQrLobby(
        title: 'الضامة • دعوة لاعب',
        url: _iphoneUrl,
        connectedPlayers: _iphonePlayers,
        accent: const Color(0xFFE11D48),
        onStart: () {
          GameFeedback.tap(GameAudioTheme.checkers);
          setState(() => _showNetworkQrLobby = false);
          _broadcastIphoneState();
        },
      );
    }
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final targets = possibleTargets;
        return Scaffold(
          appBar: AppBar(
            title: const Text('الضامة'),
            actions: [
              if (networkMode && localPlayerIsRed && _iphoneUrl.startsWith('http') && !hasAndroidGuest)
                IconButton(tooltip: 'QR للمتصفح', onPressed: _showBrowserQr, icon: const Icon(Icons.qr_code_2_rounded)),
              IconButton(
                tooltip: 'إعادة المباراة',
                onPressed: requestBoardReset,
                icon: const Icon(Icons.refresh_rounded),
              )
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: <Color>[
                        Color(0xFFFFFFFF),
                        Color(0xFFF5FAF9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0x1A0F172A)),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x140F172A),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(11),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: redTurn
                                    ? const Color(0x16E11D48)
                                    : const Color(0x120F172A),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                redTurn
                                    ? Icons.circle_rounded
                                    : Icons.circle_outlined,
                                color: redTurn
                                    ? const Color(0xFFE11D48)
                                    : const Color(0xFF0F172A),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(message,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                                child: _InfoChip(
                                    label: 'المستوى',
                                    value: networkMode
                                        ? 'Wi‑Fi'
                                        : settings.botDifficultyText)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _InfoChip(
                                    label: 'الوضع',
                                    value: networkMode
                                        ? 'جهازان'
                                        : playVsBot
                                            ? 'ضد الكمبيوتر'
                                            : 'لاعبان')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                                child: _InfoChip(
                                    label: 'أحجار الأحمر',
                                    value: '$redPieceCount')),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _InfoChip(
                                    label: 'أحجار الأسود',
                                    value: '$blackPieceCount')),
                          ],
                        ),
                        if (gameFinished) ...[
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: networkMode ? null : resetBoard,
                            icon: const Icon(Icons.replay),
                            label: Text(networkMode
                                ? 'انتهت المباراة'
                                : 'مباراة جديدة'),
                          ),
                        ],
                        if (!networkMode) ...[
                          const SizedBox(height: 10),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                  value: false,
                                  label: Text('لاعب ضد لاعب'),
                                  icon: Icon(Icons.people_alt_rounded)),
                              ButtonSegment(
                                  value: true,
                                  label: Text('ضد الكمبيوتر'),
                                  icon: Icon(Icons.smart_toy_rounded)),
                            ],
                            selected: {playVsBot},
                            onSelectionChanged: (value) {
                              setState(() => playVsBot = value.first);
                              resetBoard();
                            },
                          ),
                        ],
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              tableColor.withValues(alpha: .98),
                              tableColor.withValues(alpha: .72),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: const Color(0xFFF5B82E),
                            width: 3,
                          ),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x42000000),
                              blurRadius: 22,
                              offset: Offset(0, 10),
                            ),
                            BoxShadow(
                              color: Color(0x33F5B82E),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 8),
                            itemCount: 64,
                            itemBuilder: (context, index) {
                              final r = index ~/ 8;
                              final c = index % 8;
                              return _BoardCell(
                                row: r,
                                col: c,
                                piece: board[r][c],
                                selected: selectedRow == r && selectedCol == c,
                                possibleMove: targets.contains('$r,$c'),
                                forcedCapture:
                                    forcedCaptureSources.contains('$r,$c'),
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
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
      decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _BoardCell extends StatelessWidget {
  const _BoardCell(
      {required this.row,
      required this.col,
      required this.piece,
      required this.selected,
      required this.possibleMove,
      required this.forcedCapture,
      required this.onTap});
  final int row;
  final int col;
  final Piece piece;
  final bool selected;
  final bool possibleMove;
  final bool forcedCapture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = (row + col).isOdd;
    final baseColor = dark ? const Color(0xFF7A542B) : const Color(0xFFF4DCA8);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? const [Color(0xFFFFE08A), Color(0xFFFFB703)]
                : possibleMove
                    ? const [Color(0xFFE9FBCF), Color(0xFF9BE564)]
                    : [baseColor.withOpacity(0.92), baseColor],
          ),
          border: Border.all(
              color: forcedCapture
                  ? const Color(0xFFFF3B30)
                  : Colors.black.withOpacity(0.25),
              width: forcedCapture ? 3 : 0.55),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (possibleMove && piece == Piece.empty)
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.38)),
              ),
            if (forcedCapture)
              const Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(Icons.priority_high,
                      color: Color(0xFFFF3B30), size: 16)),
            _PieceView(piece: piece),
          ],
        ),
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
    final mainColor = isRed ? const Color(0xFFD94B4B) : const Color(0xFF222831);
    final darkColor = isRed ? const Color(0xFF8E2525) : const Color(0xFF0B0F14);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 0.95,
          colors: [Colors.white.withOpacity(0.35), mainColor, darkColor],
          stops: const [0.05, 0.55, 1],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.82), width: 1.5),
        boxShadow: const [
          BoxShadow(blurRadius: 7, offset: Offset(1, 3), color: Colors.black38)
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 27,
            height: 27,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withOpacity(0.20), width: 1.1)),
          ),
          if (king)
            const Icon(Icons.workspace_premium,
                color: Color(0xFFFFD166), size: 21),
        ],
      ),
    );
  }
}
