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
  StreamSubscription<NetworkMessage>? networkSubscription;
  bool isHost = true;
  bool gameOpened = false;
  final TextEditingController hostAddressController = TextEditingController();
  final TextEditingController roomCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    networkCore = LocalNetworkCore(gameId: widget.game.id);
    networkSubscription = networkCore.messages.listen(_handleRoomMessage);
  }

  @override
  void dispose() {
    networkSubscription?.cancel();
    hostAddressController.dispose();
    roomCodeController.dispose();
    networkCore.dispose();
    super.dispose();
  }

  void _handleRoomMessage(NetworkMessage message) {
    if (!mounted || message.type != NetworkMessageType.startGame || gameOpened) return;
    _openGame();
  }

  void _startGame() {
    if (networkCore.state.mode == LocalNetworkMode.host) {
      networkCore.startGame();
      return;
    }

    if (networkCore.state.mode == LocalNetworkMode.idle) {
      _openGame();
    }
  }

  void _openGame() {
    if (gameOpened) return;
    gameOpened = true;
    Navigator.push(context, MaterialPageRoute(builder: (context) => widget.game.builder(context, networkCore))).then((_) {
      gameOpened = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('غرفة ${widget.game.name}')),
      body: StreamBuilder<LocalNetworkState>(
        stream: networkCore.stateStream,
        initialData: networkCore.state,
        builder: (context, snapshot) {
          final LocalNetworkState state = snapshot.data ?? LocalNetworkState.idle();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.game.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('عدد اللاعبين: ${widget.game.playersText}'),
                      const SizedBox(height: 16),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: true, label: Text('إنشاء غرفة'), icon: Icon(Icons.wifi_tethering)),
                          ButtonSegment(value: false, label: Text('انضمام'), icon: Icon(Icons.login)),
                        ],
                        selected: {isHost},
                        onSelectionChanged: (value) => setState(() => isHost = value.first),
                      ),
                      const SizedBox(height: 16),
                      if (!isHost) ...[
                        TextField(
                          controller: hostAddressController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'IP جهاز اللاعب الأول',
                            hintText: 'مثال: 192.168.1.8',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: roomCodeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'رمز الغرفة اختياري',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      FilledButton.icon(
                        icon: Icon(isHost ? Icons.add_link : Icons.link),
                        label: Text(isHost ? 'تشغيل Host' : 'الاتصال بالغرفة'),
                        onPressed: () {
                          if (isHost) {
                            networkCore.createRoom();
                          } else {
                            networkCore.joinRoom(
                              hostAddress: hostAddressController.text,
                              port: LocalWifiTransport.defaultPort,
                              roomCode: roomCodeController.text.trim(),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _NetworkStatusBox(state: state),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _PlayersCard(state: state, onStart: _startGame),
              const SizedBox(height: 12),
              const _ConnectionPlanCard(),
            ],
          );
        },
      ),
    );
  }
}

class _NetworkStatusBox extends StatelessWidget {
  const _NetworkStatusBox({required this.state});

  final LocalNetworkState state;

  @override
  Widget build(BuildContext context) {
    final String modeText = switch (state.mode) {
      LocalNetworkMode.host => 'Host',
      LocalNetworkMode.client => 'Client',
      LocalNetworkMode.idle => 'لم يتم الاختيار',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('حالة الاتصال: $modeText', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(state.message, style: const TextStyle(height: 1.4)),
          if (state.hostAddress.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('IP اللاعب الأول: ${state.hostAddress}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Port: ${state.port}'),
          ],
          if (state.roomCode.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('رمز الغرفة: ${state.roomCode}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }
}

class _PlayersCard extends StatelessWidget {
  const _PlayersCard({required this.state, required this.onStart});

  final LocalNetworkState state;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final List<LocalPlayer> players = state.players.isEmpty
        ? const <LocalPlayer>[
            LocalPlayer(id: 'local-1', name: 'اللاعب 1', isHost: true, isReady: true),
            LocalPlayer(id: 'local-2', name: 'اللاعب 2', isHost: false),
          ]
        : state.players;
    final bool waitingForHost = state.mode == LocalNetworkMode.client;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اللاعبون', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            for (final LocalPlayer player in players)
              ListTile(
                leading: Icon(player.isHost ? Icons.person : Icons.person_outline),
                title: Text(player.name),
                subtitle: Text(player.isReady ? 'جاهز' : 'بانتظار الجاهزية'),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: Text(waitingForHost ? 'بانتظار بدء اللاعب الأول' : 'ابدأ اللعب'),
              onPressed: waitingForHost ? null : onStart,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionPlanCard extends StatelessWidget {
  const _ConnectionPlanCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'خطة الاتصال الحالية: أولًا Wi-Fi/Hotspot، ثم نقل حركة الضامة بين جهازين. اللعب عبر الإنترنت يأتي لاحقًا بعد استقرار Wi-Fi المحلي.',
          style: TextStyle(height: 1.5),
        ),
      ),
    );
  }
}
