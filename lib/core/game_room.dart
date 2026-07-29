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

  bool get isLanOnly => widget.game.id == 'name_animal_object';

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
    _openGame(useNetwork: true);
  }

  void _startGame() {
    if (networkCore.state.mode == LocalNetworkMode.host) {
      networkCore.startGame();
      return;
    }
    if (!isLanOnly && networkCore.state.mode == LocalNetworkMode.idle) {
      _openGame(useNetwork: false);
    }
  }

  void _startOfflineGame() {
    _openGame(useNetwork: false);
  }

  void _openGame({required bool useNetwork}) {
    if (gameOpened) return;
    gameOpened = true;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => widget.game.builder(
          context,
          useNetwork ? networkCore : null,
        ),
      ),
    ).then((_) {
      gameOpened = false;
    });
  }

  String get _offlineTitle {
    switch (widget.game.id) {
      case 'chicken':
        return 'ابدأ اللعبة بدون إنترنت';
      case 'chess':
        return 'العب محليًا على نفس الجهاز';
      default:
        return 'العب ضد الروبوت بدون إنترنت';
    }
  }

  String get _offlineDescription {
    switch (widget.game.id) {
      case 'chicken':
        return 'هذه اللعبة فردية وتعمل بالكامل بدون اتصال.';
      case 'chess':
        return 'لاعبان على نفس الهاتف، ولا حاجة إلى شبكة أو إنترنت.';
      default:
        return 'ابدأ فورًا على هذا الهاتف. لا Wi‑Fi ولا بيانات ولا غرفة لعب.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('اختيار طريقة لعب ${widget.game.name}')),
      body: StreamBuilder<LocalNetworkState>(
        stream: networkCore.stateStream,
        initialData: networkCore.state,
        builder: (context, snapshot) {
          final LocalNetworkState state = snapshot.data ?? LocalNetworkState.idle();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!isLanOnly) ...[
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.smart_toy, color: Theme.of(context).colorScheme.primary, size: 30),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _offlineTitle,
                                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(_offlineDescription, style: const TextStyle(height: 1.45)),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('ابدأ الآن بدون إنترنت'),
                            onPressed: _startOfflineGame,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text('اللعب عبر الشبكة اختياري'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 12),
              ] else ...[
                Card(
                  color: const Color(0xFFE8F5F2),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'هذه اللعبة تعمل على عدة هواتف ضمن نفس Wi-Fi أو Hotspot. ينشئ لاعب واحد الغرفة، ثم ينضم بقية اللاعبين إلى IP المضيف.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
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
                      _NetworkStatusBox(state: state, onReconnect: networkCore.reconnect),
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
  const _NetworkStatusBox({required this.state, required this.onReconnect});

  final LocalNetworkState state;
  final Future<void> Function() onReconnect;

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
          Text('الوضع: $modeText', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(state.message),
          if (state.hostAddress.isNotEmpty) ...[
            const SizedBox(height: 4),
            SelectableText('IP: ${state.hostAddress}:${state.port}'),
          ],
          if (state.roomCode.isNotEmpty) SelectableText('رمز الغرفة: ${state.roomCode}'),
          if (state.status == LocalNetworkStatus.error ||
              state.status == LocalNetworkStatus.disconnected) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onReconnect,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
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
    final bool canStart = state.mode == LocalNetworkMode.host && state.players.length >= 2;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('اللاعبون (${state.players.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            if (state.players.isEmpty)
              const Text('لم ينضم أي لاعب بعد.')
            else
              ...state.players.map((player) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(player.isHost ? Icons.star : Icons.person),
                    title: Text(player.name),
                    trailing: Icon(player.isReady ? Icons.check_circle : Icons.hourglass_empty),
                  )),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canStart ? onStart : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('بدء اللعبة على جميع الأجهزة'),
              ),
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
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('طريقة الاتصال', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('1. اجعل جميع الهواتف على نفس Wi-Fi أو Hotspot.'),
            Text('2. ينشئ اللاعب الأول الغرفة ويشارك عنوان IP.'),
            Text('3. يدخل بقية اللاعبين عنوان IP وينضمون.'),
            Text('4. يبدأ المضيف اللعبة فتفتح الشاشة عند الجميع.'),
          ],
        ),
      ),
    );
  }
}
