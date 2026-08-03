import 'dart:async';

import 'package:flutter/material.dart';

import 'game_definition.dart';
import 'network/local_network_core.dart';
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
  StreamSubscription<NetworkMessage>? _subscription;
  final TextEditingController _hostController = TextEditingController();
  bool _isHost = true;
  bool _opened = false;

  bool get _isNameGame => widget.game.id == 'name_animal_object';

  bool get _supportsIphone => const <String>{
        'name_animal_object',
        'sheikh_beard',
        'dots_boxes',
        'xo',
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
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _hostController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.game.name)),
      body: StreamBuilder<LocalNetworkState>(
        stream: networkCore.stateStream,
        initialData: networkCore.state,
        builder: (BuildContext context, AsyncSnapshot<LocalNetworkState> snap) {
          final LocalNetworkState state = snap.data ?? LocalNetworkState.idle();
          final bool hostReady = state.mode == LocalNetworkMode.host;
          final bool canStart = hostReady &&
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
                            icon: Icon(Icons.login),
                            label: Text('انضمام'),
                          ),
                        ],
                        selected: <bool>{_isHost},
                        onSelectionChanged: (Set<bool> value) {
                          setState(() => _isHost = value.first);
                        },
                      ),
                      const SizedBox(height: 14),
                      if (!_isHost)
                        TextField(
                          controller: _hostController,
                          decoration: const InputDecoration(
                            labelText: 'عنوان جهاز المضيف',
                            hintText: '192.168.1.8',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      if (!_isHost) const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () {
                          if (_isHost) {
                            networkCore.createRoom();
                          } else {
                            networkCore.joinRoom(
                              hostAddress: _hostController.text,
                              port: LocalWifiTransport.defaultPort,
                            );
                          }
                        },
                        icon: Icon(_isHost ? Icons.add_link : Icons.link),
                        label: Text(_isHost ? 'إنشاء الغرفة' : 'الانضمام'),
                      ),
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
                      if (state.hostAddress.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        SelectableText(
                          '${state.hostAddress}:${state.port}',
                          textAlign: TextAlign.center,
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
