import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/app_settings.dart';
import '../../core/iphone_game_bridge.dart';
import '../../core/network/local_network_core.dart';
import '../../core/network/network_message.dart';
import '../../design/app_theme.dart';
import 'xo_iphone_bridge.dart';

enum XoCell { empty, x, o }

class XoGameScreen extends StatefulWidget {
  const XoGameScreen({super.key, this.networkCore});

  final LocalNetworkCore? networkCore;

  @override
  State<XoGameScreen> createState() => _XoGameScreenState();
}

class _XoGameScreenState extends State<XoGameScreen> {
  final AppSettingsController settings = AppSettingsController.instance;
  final Random random = Random();

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
    if (playVsBot && !xTurn) return;
    if (mark != (xTurn ? XoCell.x : XoCell.o)) return;
    if (isHost && isNetworkGame && senderId != _turnId) return;

    setState(() => cells[index] = mark);
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
      _syncState();
      return;
    }
    if (!cells.contains(XoCell.empty)) {
      if (!roundCounted) {
        draws++;
        roundCounted = true;
      }
      setState(() => message = 'تعادل');
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
    final win = findBestMoveFor(XoCell.o);
    if (win >= 0) return win;
    final block = findBestMoveFor(XoCell.x);
    if (block >= 0) return block;
    if (settings.botDifficulty == BotDifficulty.hard &&
        cells[4] == XoCell.empty) {
      return 4;
    }
    final empty = <int>[
      for (var i = 0; i < cells.length; i++)
        if (cells[i] == XoCell.empty) i,
    ];
    return empty.isEmpty ? -1 : empty[random.nextInt(empty.length)];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إكس أو'),
        actions: <Widget>[
          IconButton(onPressed: reset, icon: const Icon(Icons.refresh)),
          IconButton(
              onPressed: resetScore, icon: const Icon(Icons.restart_alt)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (isHost && isNetworkGame)
            Card(
              color: const Color(0xFFEDE4FF),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: <Widget>[
                    const Text('دخول الآيفون',
                        style: TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w900)),
                    if (_iphoneUrl.startsWith('http')) ...<Widget>[
                      const SizedBox(height: 8),
                      QrImageView(
                          data: _iphoneUrl,
                          size: 165,
                          backgroundColor: Colors.white),
                    ],
                    const SizedBox(height: 7),
                    SelectableText(
                      _iphoneUrl.isEmpty ? 'جاري تجهيز الرابط...' : _iphoneUrl,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('لاعبو الآيفون: ${_iphonePlayers.length}'),
                  ],
                ),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  Text(message,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  if (!isNetworkGame) ...<Widget>[
                    const SizedBox(height: 12),
                    SegmentedButton<bool>(
                      segments: const <ButtonSegment<bool>>[
                        ButtonSegment<bool>(
                            value: false,
                            label: Text('لاعبان'),
                            icon: Icon(Icons.people)),
                        ButtonSegment<bool>(
                            value: true,
                            label: Text('روبوت'),
                            icon: Icon(Icons.smart_toy)),
                      ],
                      selected: <bool>{playVsBot},
                      onSelectionChanged: (value) {
                        playVsBot = value.first;
                        reset();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                  child: _ScoreTile(
                      label: 'X', value: xWins, color: AppColors.danger)),
              const SizedBox(width: 8),
              Expanded(
                  child: _ScoreTile(
                      label: 'تعادل', value: draws, color: AppColors.muted)),
              const SizedBox(width: 8),
              Expanded(
                  child: _ScoreTile(
                      label: 'O', value: oWins, color: AppColors.primaryDark)),
            ],
          ),
          const SizedBox(height: 20),
          AspectRatio(
            aspectRatio: 1,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemCount: 9,
              itemBuilder: (context, index) {
                final cell = cells[index];
                final winning = winLine.contains(index);
                return InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => tapCell(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: winning ? AppColors.accent : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 4)),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        cell == XoCell.empty ? '' : cell.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 58,
                          fontWeight: FontWeight.w900,
                          color: cell == XoCell.x
                              ? AppColors.danger
                              : AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile(
      {required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: <Widget>[
          Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w900)),
          Text('$value',
              style: TextStyle(
                  color: color, fontSize: 24, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
