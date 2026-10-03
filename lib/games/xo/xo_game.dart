import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/app_settings.dart';
import '../../core/audio_feedback.dart';
import '../../core/pregame_qr_lobby.dart';
import '../../core/iphone_game_bridge.dart';
import '../../core/network/local_network_core.dart';
import '../../core/network/network_message.dart';
import 'xo_iphone_bridge.dart';

enum XoCell { empty, x, o }

class XoGameScreen extends StatefulWidget {
  const XoGameScreen({super.key, this.networkCore});

  final LocalNetworkCore? networkCore;

  @override
  State<XoGameScreen> createState() => _XoGameScreenState();
}

class _XoGameScreenState extends State<XoGameScreen> with SingleTickerProviderStateMixin {
  final AppSettingsController settings = AppSettingsController.instance;
  final Random random = Random();
  late final AnimationController lineController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));

  List<XoCell> cells = List<XoCell>.filled(9, XoCell.empty);
  bool xTurn = true;
  bool playVsBot = true;
  bool botThinking = false;
  String message = 'أنت X - دورك';
  List<int> winLine = <int>[];
  int xWins = 0;
  int oWins = 0;
  int draws = 0;
  bool roundCounted = false;
  bool connectionLost = false;

  StreamSubscription<NetworkMessage>? networkSubscription;
  IphoneGameBridge? _iphoneBridge;
  StreamSubscription<List<IphoneWebPlayer>>? _iphonePlayersSub;
  StreamSubscription<IphoneWebEvent>? _iphoneEventsSub;
  List<IphoneWebPlayer> _iphonePlayers = <IphoneWebPlayer>[];
  String _iphoneUrl = '';
  bool _showNetworkQrLobby = true;

  bool get isNetworkGame => widget.networkCore != null;
  bool get isHost => widget.networkCore?.state.mode == LocalNetworkMode.host;
  XoCell get localMark => isHost ? XoCell.x : XoCell.o;

  String get localPlayerId {
    final players = widget.networkCore?.state.players ?? const <LocalPlayer>[];
    final matching = players.where((player) => player.isHost == isHost);
    return matching.isNotEmpty
        ? matching.first.id
        : (isHost ? 'host' : 'client');
  }

  String get _hostId {
    final players = widget.networkCore?.state.players ?? const <LocalPlayer>[];
    final host = players.where((player) => player.isHost);
    return host.isNotEmpty ? host.first.id : 'host';
  }

  String get _opponentId {
    if (_iphonePlayers.isNotEmpty) return _iphonePlayers.first.id;
    final players = widget.networkCore?.state.players ?? const <LocalPlayer>[];
    final guest = players.where((player) => !player.isHost);
    return guest.isNotEmpty ? guest.first.id : '';
  }

  String get _turnId => xTurn ? _hostId : _opponentId;

  @override
  void initState() {
    super.initState();
    if (isNetworkGame) {
      playVsBot = false;
      message = isHost ? 'أنت X - دورك' : 'أنت O - بانتظار دور X';
      networkSubscription =
          widget.networkCore!.messages.listen(_handleNetworkMessage);
      if (isHost) _startIphoneBridge();
    }
  }

  Future<void> _startIphoneBridge() async {
    final bridge = createXoIphoneBridge();
    _iphoneBridge = bridge;
    _iphonePlayersSub = bridge.players.stream.listen((players) {
      if (!mounted) return;
      setState(() => _iphonePlayers = players);
      _broadcastWebState();
    });
    _iphoneEventsSub = bridge.events.stream.listen((event) {
      if (event.type == 'move') {
        final index = (event.data['index'] as num?)?.toInt() ?? -1;
        _place(index, XoCell.o, senderId: event.playerId, notify: false);
      } else if (event.type == 'reset') {
        _resetBoard(notifyPeer: true);
      }
    });
    try {
      final url = await bridge.start();
      if (mounted) setState(() => _iphoneUrl = url);
      _broadcastWebState();
    } catch (_) {
      if (mounted) setState(() => _iphoneUrl = 'تعذر تشغيل رابط الآيفون');
    }
  }

  @override
  void dispose() {
    networkSubscription?.cancel();
    _iphonePlayersSub?.cancel();
    _iphoneEventsSub?.cancel();
    unawaited(_iphoneBridge?.dispose());
    lineController.dispose();
    super.dispose();
  }

  void _handleNetworkMessage(NetworkMessage networkMessage) {
    if (!mounted || networkMessage.senderId == localPlayerId) return;
    if (networkMessage.type == NetworkMessageType.disconnect) {
      setState(() {
        connectionLost = true;
        botThinking = false;
        message = 'انقطع اتصال اللاعب الآخر.';
      });
      return;
    }
    if (connectionLost || networkMessage.type != NetworkMessageType.move)
      return;
    final action = networkMessage.payload['action']?.toString();
    if (action == 'reset') {
      _resetBoard(notifyPeer: false);
      return;
    }
    if (action == 'xo_state' && !isHost) {
      final raw = networkMessage.payload['cells'] as List<dynamic>? ?? const [];
      if (raw.length != 9) return;
      setState(() {
        cells = raw.map((value) {
          final name = value.toString();
          return XoCell.values.firstWhere(
            (cell) => cell.name == name,
            orElse: () => XoCell.empty,
          );
        }).toList();
        xTurn = networkMessage.payload['xTurn'] == true;
        message = (networkMessage.payload['message'] ?? '').toString();
        xWins = (networkMessage.payload['xWins'] as num?)?.toInt() ?? xWins;
        oWins = (networkMessage.payload['oWins'] as num?)?.toInt() ?? oWins;
        draws = (networkMessage.payload['draws'] as num?)?.toInt() ?? draws;
        winLine =
            (networkMessage.payload['winLine'] as List<dynamic>? ?? const [])
                .map((value) => (value as num).toInt())
                .toList();
        roundCounted = networkMessage.payload['finished'] == true;
      });
      return;
    }
    final index = (networkMessage.payload['index'] as num?)?.toInt() ?? -1;
    final mark =
        networkMessage.payload['mark'] == XoCell.x.name ? XoCell.x : XoCell.o;
    if (action == 'place') {
      _place(index, mark, senderId: networkMessage.senderId, notify: false);
    }
  }

  void _resetBoard({required bool notifyPeer}) {
    setState(() {
      cells = List<XoCell>.filled(9, XoCell.empty);
      xTurn = true;
      botThinking = false;
      winLine = <int>[];
      lineController.reset();
      roundCounted = false;
      if (!isNetworkGame) connectionLost = false;
      message = isNetworkGame
          ? (isHost ? 'أنت X - دورك' : 'أنت O - بانتظار دور X')
          : (playVsBot ? 'أنت X - دورك' : 'دور X');
    });
    if (notifyPeer && isNetworkGame) {
      widget.networkCore?.sendMove(
        <String, dynamic>{'action': 'reset'},
        senderId: localPlayerId,
      );
    }
    _syncState();
  }

  void reset() => _resetBoard(notifyPeer: true);

  void resetScore() {
    setState(() {
      xWins = 0;
      oWins = 0;
      draws = 0;
    });
    reset();
  }

  void tapCell(int index) {
    final mark = xTurn ? XoCell.x : XoCell.o;
    if (isNetworkGame && mark != localMark) return;
    _place(index, mark, senderId: localPlayerId, notify: true);
  }

  void _place(
    int index,
    XoCell mark, {
    required String senderId,
    required bool notify,
  }) {
    if (connectionLost ||
        index < 0 ||
        index >= cells.length ||
        cells[index] != XoCell.empty ||
        winLine.isNotEmpty ||
        botThinking ||
        roundCounted) return;
    if (playVsBot && !xTurn && senderId != 'bot') return;
    if (mark != (xTurn ? XoCell.x : XoCell.o)) return;
    if (isHost && isNetworkGame && senderId != _turnId) return;

    setState(() => cells[index] = mark);
    GameFeedback.tap(GameAudioTheme.xo);
    if (notify && isNetworkGame) {
      widget.networkCore?.sendMove(
        <String, dynamic>{'action': 'place', 'index': index, 'mark': mark.name},
        senderId: localPlayerId,
      );
    }
    afterMove();
  }

  void afterMove() {
    final winner = findWinner();
    if (winner != null) {
      if (!roundCounted) {
        winner == XoCell.x ? xWins++ : oWins++;
        roundCounted = true;
      }
      setState(() => message = winner == XoCell.x ? 'فاز X' : 'فاز O');
      final bool localWon = isNetworkGame
          ? winner == localMark
          : (!playVsBot || winner == XoCell.x);
      if (localWon) {
        GameFeedback.win(GameAudioTheme.xo);
        lineController.forward(from: 0);
      } else {
        GameFeedback.lose(GameAudioTheme.xo);
        lineController.forward(from: 0);
      }
      _syncState();
      return;
    }
    if (!cells.contains(XoCell.empty)) {
      if (!roundCounted) {
        draws++;
        roundCounted = true;
      }
      setState(() => message = 'تعادل');
      GameFeedback.tap(GameAudioTheme.xo);
      _syncState();
      return;
    }

    xTurn = !xTurn;
    message = isNetworkGame
        ? ((xTurn ? XoCell.x : XoCell.o) == localMark
            ? 'أنت ${localMark.name.toUpperCase()} - دورك'
            : 'دور اللاعب الآخر')
        : (playVsBot
            ? (xTurn ? 'أنت X - دورك' : 'الكمبيوتر يفكر...')
            : (xTurn ? 'دور X' : 'دور O'));
    setState(() {});
    _syncState();
    if (playVsBot && !xTurn) runBot();
  }

  void _syncState() {
    if (!isHost) return;
    _broadcastWebState();
    widget.networkCore?.sendMove(
      <String, dynamic>{
        'action': 'xo_state',
        'cells': cells.map((cell) => cell.name).toList(),
        'xTurn': xTurn,
        'message': message,
        'xWins': xWins,
        'oWins': oWins,
        'draws': draws,
        'winLine': winLine,
        'finished': roundCounted,
      },
      senderId: localPlayerId,
    );
  }

  void _broadcastWebState() {
    _iphoneBridge?.broadcast(<String, dynamic>{
      'type': 'state',
      'cells': cells
          .map((cell) => cell == XoCell.empty ? '' : cell.name.toUpperCase())
          .toList(),
      'turnId': _turnId,
      'message': message,
      'xWins': xWins,
      'oWins': oWins,
      'draws': draws,
      'finished': roundCounted,
    });
  }

  Future<void> runBot() async {
    setState(() => botThinking = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted || roundCounted) return;
    final move = chooseBotMove();
    botThinking = false;
    if (move >= 0) _place(move, XoCell.o, senderId: 'bot', notify: false);
  }

  int chooseBotMove() {
    final empty = <int>[
      for (var i = 0; i < cells.length; i++)
        if (cells[i] == XoCell.empty) i,
    ];
    if (empty.isEmpty) return -1;

    final difficulty = settings.botDifficultyFor('xo');
    if (difficulty == BotDifficulty.easy) {
      return empty[random.nextInt(empty.length)];
    }

    final win = findBestMoveFor(XoCell.o);
    if (win >= 0) return win;
    final block = findBestMoveFor(XoCell.x);
    if (block >= 0) return block;

    if (difficulty == BotDifficulty.hard) {
      if (cells[4] == XoCell.empty) return 4;
      final corners = <int>[0, 2, 6, 8]
          .where((index) => cells[index] == XoCell.empty)
          .toList();
      if (corners.isNotEmpty) return corners[random.nextInt(corners.length)];
    }

    return empty[random.nextInt(empty.length)];
  }

  int findBestMoveFor(XoCell player) {
    for (var i = 0; i < 9; i++) {
      if (cells[i] != XoCell.empty) continue;
      final copy = List<XoCell>.from(cells)..[i] = player;
      if (winnerOf(copy) == player) return i;
    }
    return -1;
  }

  XoCell? findWinner() {
    const lines = <List<int>>[
      <int>[0, 1, 2],
      <int>[3, 4, 5],
      <int>[6, 7, 8],
      <int>[0, 3, 6],
      <int>[1, 4, 7],
      <int>[2, 5, 8],
      <int>[0, 4, 8],
      <int>[2, 4, 6],
    ];
    for (final line in lines) {
      final first = cells[line.first];
      if (first != XoCell.empty &&
          first == cells[line[1]] &&
          first == cells[line[2]]) {
        winLine = line;
        return first;
      }
    }
    return null;
  }

  XoCell? winnerOf(List<XoCell> board) {
    const lines = <List<int>>[
      <int>[0, 1, 2],
      <int>[3, 4, 5],
      <int>[6, 7, 8],
      <int>[0, 3, 6],
      <int>[1, 4, 7],
      <int>[2, 5, 8],
      <int>[0, 4, 8],
      <int>[2, 4, 6],
    ];
    for (final line in lines) {
      final first = board[line.first];
      if (first != XoCell.empty &&
          first == board[line[1]] &&
          first == board[line[2]]) return first;
    }
    return null;
  }

  Future<void> _showBrowserQr() async {
    if (!_iphoneUrl.startsWith('http')) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('اللعب عبر QR'),
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
            const SizedBox(height: 10),
            SelectableText(_iphoneUrl, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('المتصلون: ${_iphonePlayers.length}'),
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
    final hasAndroidGuest = widget.networkCore?.state.players
            .any((player) => !player.isHost) ??
        false;
    if (isNetworkGame &&
        isHost &&
        _showNetworkQrLobby &&
        !hasAndroidGuest) {
      return PregameQrLobby(
        title: 'إكس أو • دعوة لاعب',
        url: _iphoneUrl,
        connectedPlayers: _iphonePlayers.length,
        accent: const Color(0xFF7C3AED),
        onStart: () {
          GameFeedback.tap(GameAudioTheme.xo);
          setState(() => _showNetworkQrLobby = false);
          _broadcastWebState();
        },
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF8F6FB),
        foregroundColor: const Color(0xFF4B4453),
        centerTitle: true,
        title: const Text('إكس أو', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: <Widget>[
          if (isHost && isNetworkGame && _iphoneUrl.startsWith('http'))
            IconButton(tooltip: 'QR للمتصفح', onPressed: _showBrowserQr, icon: const Icon(Icons.qr_code_2_rounded)),
          IconButton(tooltip: 'جولة جديدة', onPressed: reset, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 620 || constraints.maxWidth < 350;
            final padding = compact ? 10.0 : 14.0;
            return Padding(
              padding: EdgeInsets.fromLTRB(padding, 4, padding, padding),
              child: Column(
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 10 : 14),
                    decoration: BoxDecoration(color: const Color(0xFFF8F6FB), borderRadius: BorderRadius.circular(24)),
                    child: Column(
                      children: <Widget>[
                        Text(message,textAlign: TextAlign.center,style: TextStyle(color: const Color(0xFF6D28D9),fontSize: compact ? 19 : 23,fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        if (!isNetworkGame)
                          Row(
                            children: <Widget>[
                              Expanded(child: ChoiceChip(label: const Text('ضد صديق'),selected: !playVsBot,onSelected: (_) {GameFeedback.uiTap();setState(() => playVsBot = false);reset();})),
                              const SizedBox(width: 8),
                              Expanded(child: ChoiceChip(label: Text('ضد الكمبيوتر • ${settings.botDifficultyTextFor('xo')}'),selected: playVsBot,onSelected: (_) {GameFeedback.uiTap();setState(() => playVsBot = true);reset();})),
                            ],
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(color: const Color(0xFFEDE9FE),borderRadius: BorderRadius.circular(16)),
                            child: Text(isHost ? 'أنت X • اللعب عبر الشبكة' : 'أنت O • اللعب عبر الشبكة',style: const TextStyle(color: Color(0xFF6D28D9), fontWeight: FontWeight.w800)),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: compact ? 6 : 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      _ScorePill(label: 'X', value: xWins, color: const Color(0xFF6D28D9)),
                      _ScorePill(label: playVsBot && !isNetworkGame ? '🤖' : 'O', value: oWins, color: const Color(0xFFF97316)),
                      _ScorePill(label: 'تعادل', value: draws, color: const Color(0xFF64748B)),
                    ],
                  ),
                  SizedBox(height: compact ? 8 : 12),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: LayoutBuilder(
                          builder: (context, boardConstraints) {
                            final size = boardConstraints.maxWidth;
                            return Stack(
                              children: <Widget>[
                                GridView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: 9,
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: compact ? 7 : 10,
                                    mainAxisSpacing: compact ? 7 : 10,
                                  ),
                                  itemBuilder: (context, index) {
                                    final cell = cells[index];
                                    final value = cell == XoCell.empty ? '' : cell.name.toUpperCase();
                                    final winning = winLine.contains(index);
                                    return InkWell(
                                      borderRadius: BorderRadius.circular(compact ? 18 : 24),
                                      onTap: () => tapCell(index),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 180),
                                        curve: Curves.easeOutCubic,
                                        decoration: BoxDecoration(
                                          color: value == 'X' ? const Color(0xFFEDE9FE) : value == 'O' ? const Color(0xFFFFEDD5) : Colors.white,
                                          borderRadius: BorderRadius.circular(compact ? 18 : 24),
                                          border: Border.all(color: winning ? const Color(0xFF10B981) : const Color(0xFFE9D5FF),width: winning ? 4 : 2),
                                          boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 5))],
                                        ),
                                        child: Center(
                                          child: AnimatedScale(
                                            duration: const Duration(milliseconds: 220),
                                            curve: Curves.elasticOut,
                                            scale: value.isEmpty ? 0 : 1,
                                            child: Text(value,style: TextStyle(fontSize: compact ? 48 : 58,fontWeight: FontWeight.w900,color: value == 'X' ? const Color(0xFF6D28D9) : const Color(0xFFF97316))),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                if (winLine.isNotEmpty)
                                  IgnorePointer(
                                    child: AnimatedBuilder(
                                      animation: lineController,
                                      builder: (context, _) => CustomPaint(size: Size.square(size),painter: _XoWinLinePainter(winLine, lineController.value)),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  if (connectionLost)
                    const Padding(padding: EdgeInsets.only(top: 8),child: Text('انقطع اتصال اللاعب الآخر', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800))),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(14)),
        child: Column(children: <Widget>[
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text('\$value', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15)),
        ]),
      );
}

class _XoWinLinePainter extends CustomPainter {
  const _XoWinLinePainter(this.line, this.progress);
  final List<int> line;
  final double progress;
  Offset _center(int index, Size size) {
    final row = index ~/ 3, col = index % 3;
    final gap = size.width * .026;
    final cell = (size.width - gap * 2) / 3;
    return Offset(col * (cell + gap) + cell / 2, row * (cell + gap) + cell / 2);
  }
  @override
  void paint(Canvas canvas, Size size) {
    if (line.length != 3) return;
    final start = _center(line.first, size), end = _center(line.last, size);
    final current = Offset.lerp(start, end, Curves.easeOutCubic.transform(progress))!;
    canvas.drawLine(start, current, Paint()..color = const Color(0xFF10B981)..strokeWidth = 8..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(covariant _XoWinLinePainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.line != line;
}
