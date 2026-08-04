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
  bool _joining = false;
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
    _subscription = networkCore.messages.listen((NetworkMessage message) {
      if (message.type == NetworkMessageType.startGame && !_opened) {
        _openGame(useNetwork: true);
      }
    });
    _stateSubscription = networkCore.stateStream.listen((LocalNetworkState state) {
      if (state.mode == LocalNetworkMode.host &&
          (state.status == LocalNetworkStatus.ready ||
              state.status == LocalNetworkStatus.connected) &&
          state.hostAddress.isNotEmpty) {
        unawaited(_startAdvertisingSafely(state));
      } else if (state.mode != LocalNetworkMode.host) {
        unawaited(_discovery.stopAdvertising());
      }
    });
  }

  Future<void> _startAdvertisingSafely(LocalNetworkState state) async {
    try {
      await _discovery.startAdvertising(
        gameId: widget.game.id,
        host: state.hostAddress,
        port: state.port,
        roomCode: state.roomCode,
        name: '${widget.game.name} • ${state.roomCode}',
      );
    } catch (_) {}
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
        builder: (BuildContext context) => widget.game.builder(
          context,
          useNetwork ? networkCore : null,
        ),
      ),
    ).then((_) {
      _opened = false;
    });
  }

  void _start() {
    final LocalNetworkState state = networkCore.state;
    if (state.mode == LocalNetworkMode.host &&
        (state.status == LocalNetworkStatus.ready ||
            state.status == LocalNetworkStatus.connected)) {
      networkCore.startGame();
    } else if (!_isNameGame && state.mode == LocalNetworkMode.idle) {
      _openGame(useNetwork: false);
    }
  }

  Future<void> _changeMode(bool host) async {
    if (_isHost == host) return;
    if (networkCore.state.mode != LocalNetworkMode.idle) {
      networkCore.disconnect();
    }
    await _discovery.stopAdvertising();
    if (!mounted) return;
    setState(() {
      _isHost = host;
      _rooms = const <DiscoveredRoom>[];
      _searching = false;
      _joining = false;
    });
  }

  Future<void> _findRooms() async {
    if (_searching || _joining) return;
    setState(() {
      _searching = true;
      _rooms = const <DiscoveredRoom>[];
    });

    List<DiscoveredRoom> rooms = const <DiscoveredRoom>[];
    try {
      rooms = await _discovery.discover(gameId: widget.game.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر البحث التلقائي. تأكد من اتصال الجهازين بنفس Wi-Fi أو استخدم الاتصال اليدوي.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
          _rooms = rooms;
        });
      }
    }

    if (mounted && rooms.length == 1) {
      await _joinDiscoveredRoom(rooms.first);
    }
  }

  Future<void> _joinDiscoveredRoom(DiscoveredRoom room) async {
    if (_joining) return;
    setState(() => _joining = true);
    try {
      if (networkCore.state.mode == LocalNetworkMode.host) {
        networkCore.disconnect();
        await _discovery.stopAdvertising();
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      await networkCore.joinRoom(
        hostAddress: room.host,
        port: room.port,
        roomCode: room.roomCode,
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.game.name)),
      body: StreamBuilder<LocalNetworkState>(
        stream: networkCore.stateStream,
        initialData: networkCore.state,
        builder: (BuildContext context,
            AsyncSnapshot<LocalNetworkState> snapshot) {
          final LocalNetworkState state =
              snapshot.data ?? LocalNetworkState.idle();
          final bool hostReady = state.mode == LocalNetworkMode.host &&
              (state.status == LocalNetworkStatus.ready ||
                  state.status == LocalNetworkStatus.connected);
          final bool canStart = hostReady &&
              (_supportsIphone
                  ? state.players.isNotEmpty
                  : state.players.length >= 2);
          final bool operationPending =
              state.status == LocalNetworkStatus.preparing || _joining;

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
                        onSelectionChanged: operationPending
                            ? null
                            : (Set<bool> value) {
                                unawaited(_changeMode(value.first));
                              },
                      ),
                      const SizedBox(height: 14),
                      if (_isHost)
                        FilledButton.icon(
                          onPressed:
                              operationPending ? null : networkCore.createRoom,
                          icon: operationPending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.add_link),
                          label: const Text('إنشاء الغرفة'),
                        )
                      else ...<Widget>[
                        FilledButton.icon(
                          onPressed: _searching || _joining ? null : _findRooms,
                          icon: _searching || _joining
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.radar),
                          label: Text(
                            _joining
                                ? 'جاري الدخول...'
                                : _searching
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
                                keyboardType: TextInputType.url,
                                decoration: const InputDecoration(
                                  labelText: 'IP جهاز المضيف',
                                  hintText: '192.168.1.8',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: _joining
                                    ? null
                                    : () async {
                                        setState(() => _joining = true);
                                        try {
                                          await networkCore.joinRoom(
                                            hostAddress: _hostController.text,
                                            port: LocalWifiTransport.defaultPort,
                                          );
                                        } finally {
                                          if (mounted) {
                                            setState(() => _joining = false);
                                          }
                                        }
                                      },
                                icon: const Icon(Icons.link),
                                label: const Text('اتصال يدوي'),
                              ),
                            ],
                          ),
                        ],
                        for (final DiscoveredRoom room in _rooms)
                          Card(
                            color: const Color(0xFFEAF7F2),
                            child: ListTile(
                              leading: const Icon(Icons.sports_esports),
                              title: Text(room.name),
                              subtitle: Text('رمز الغرفة: ${room.roomCode}'),
                              trailing: FilledButton(
                                onPressed: _joining
                                    ? null
                                    : () => _joinDiscoveredRoom(room),
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
