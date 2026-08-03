import 'dart:async';

import 'package:flutter/material.dart';

import 'game_definition.dart';
import 'network/local_network_core.dart';
import 'network/local_room_discovery.dart';
import 'network/local_wifi_transport.dart';
import 'network/network_message.dart';

class GameRoomScreen extends StatefulWidget {
  const GameRoomScreen({super.key, required this.game});
  final GameDefinition game;

  @override
  State<GameRoomScreen> createState() => _GameRoomScreenState();
}

class _GameRoomScreenState extends State<GameRoomScreen> {
  late final LocalNetworkCore networkCore;
  final LocalRoomDiscovery _discovery = LocalRoomDiscovery();
  StreamSubscription<NetworkMessage>? _subscription;
  StreamSubscription<LocalNetworkState>? _stateSubscription;
  final TextEditingController _hostController = TextEditingController();
  bool _isHost = true;
  bool _opened = false;
  bool _searching = false;
  List<DiscoveredRoom> _rooms = const <DiscoveredRoom>[];

  bool get _isNameGame => widget.game.id == 'name_animal_object';

  bool get _supportsIphone => const <String>{
        'name_animal_object',
        'sheikh_beard',
        'dots_boxes',
        'xo',
        'checkers',
      }.contains(widget.game.id);

  @override
  void initState() {
    super.initState();
    networkCore = LocalNetworkCore(gameId: widget.game.id);
    _subscription = networkCore.messages.listen((message) {
      if (message.type == NetworkMessageType.startGame && !_opened) {
        _openGame(useNetwork: true);
      }
    });
    _stateSubscription = networkCore.stateStream.listen((state) {
      if (state.mode == LocalNetworkMode.host &&
          state.status == LocalNetworkStatus.ready &&
          state.hostAddress.isNotEmpty) {
        unawaited(_discovery.startAdvertising(
          gameId: widget.game.id,
          host: state.hostAddress,
          port: state.port,
          roomCode: state.roomCode,
          name: '${widget.game.name} • ${state.roomCode}',
        ));
      } else if (state.mode != LocalNetworkMode.host) {
        unawaited(_discovery.stopAdvertising());
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _stateSubscription?.cancel();
    _hostController.dispose();
    unawaited(_discovery.dispose());
    networkCore.dispose();
    super.dispose();
  }

  void _openGame({required bool useNetwork}) {
    if (_opened) return;
    _opened = true;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => widget.game.builder(
          context,
          useNetwork ? networkCore : null,
        ),
      ),
    ).then((_) => _opened = false);
  }

  void _start() {
    if (networkCore.state.mode == LocalNetworkMode.host) {
      networkCore.startGame();
    } else if (!_isNameGame &&
        networkCore.state.mode == LocalNetworkMode.idle) {
      _openGame(useNetwork: false);
    }
  }

  Future<void> _findRooms() async {
    if (_searching) return;
    setState(() {
      _searching = true;
      _rooms = const <DiscoveredRoom>[];
    });
    final rooms = await _discovery.discover(gameId: widget.game.id);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _rooms = rooms;
    });
    if (rooms.length == 1) {
      await _joinDiscoveredRoom(rooms.first);
    }
  }

  Future<void> _joinDiscoveredRoom(DiscoveredRoom room) async {
    await networkCore.joinRoom(
      hostAddress: room.host,
      port: room.port,
      roomCode: room.roomCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.game.name)),
      body: StreamBuilder<LocalNetworkState>(
        stream: networkCore.stateStream,
        initialData: networkCore.state,
        builder: (context, snap) {
          final state = snap.data ?? LocalNetworkState.idle();
          final hostReady = state.mode == LocalNetworkMode.host;
          final canStart = hostReady &&
              (_supportsIphone
                  ? state.players.isNotEmpty
                  : state.players.length >= 2);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        _supportsIphone
                            ? 'العب من أندرويد أو الآيفون على نفس الشبكة'
                            : 'اختر طريقة اللعب',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SegmentedButton<bool>(
                        segments: const <ButtonSegment<bool>>[
                          ButtonSegment<bool>(
                            value: true,
                            icon: Icon(Icons.wifi_tethering),
                            label: Text('إنشاء غرفة'),
                          ),
                          ButtonSegment<bool>(
                            value: false,
                            icon: Icon(Icons.search),
                            label: Text('العثور على غرفة'),
                          ),
                        ],
                        selected: <bool>{_isHost},
                        onSelectionChanged: (value) {
                          setState(() {
                            _isHost = value.first;
                            _rooms = const <DiscoveredRoom>[];
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      if (_isHost)
                        FilledButton.icon(
                          onPressed: networkCore.createRoom,
                          icon: const Icon(Icons.add_link),
                          label: const Text('إنشاء الغرفة'),
                        )
                      else ...<Widget>[
                        FilledButton.icon(
                          onPressed: _searching ? null : _findRooms,
                          icon: _searching
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.radar),
                          label: Text(
                            _searching
                                ? 'جاري البحث على الشبكة...'
                                : 'بحث عن الغرف تلقائيًا',
                          ),
                        ),
                        if (_rooms.isEmpty && !_searching) ...<Widget>[
                          const SizedBox(height: 10),
                          ExpansionTile(
                            title: const Text('الإدخال اليدوي كخيار احتياطي'),
                            children: <Widget>[
                              TextField(
                                controller: _hostController,
                                decoration: const InputDecoration(
                                  labelText: 'IP جهاز المضيف',
                                  hintText: '192.168.1.8',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () => networkCore.joinRoom(
                                  hostAddress: _hostController.text,
                                  port: LocalWifiTransport.defaultPort,
                                ),
                                icon: const Icon(Icons.link),
                                label: const Text('اتصال يدوي'),
                              ),
                            ],
                          ),
                        ],
                        for (final room in _rooms)
                          Card(
                            color: const Color(0xFFEAF7F2),
                            child: ListTile(
                              leading: const Icon(Icons.sports_esports),
                              title: Text(room.name),
                              subtitle: Text('رمز الغرفة: ${room.roomCode}'),
                              trailing: FilledButton(
                                onPressed: () => _joinDiscoveredRoom(room),
                                child: const Text('دخول'),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (state.roomCode.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          'رمز الغرفة: ${state.roomCode}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'اللاعبون المتصلون: ${state.players.length}',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: canStart ? _start : null,
                        icon: const Icon(Icons.play_arrow),
                        label: Text(
                          _supportsIphone
                              ? 'فتح اللعبة وإظهار QR للآيفون'
                              : 'بدء اللعبة على الجميع',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!_supportsIphone) ...<Widget>[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _openGame(useNetwork: false),
                  icon: const Icon(Icons.smart_toy),
                  label: const Text('اللعب بدون شبكة'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
