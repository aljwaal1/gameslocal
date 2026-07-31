import 'dart:async';

import 'package:flutter/material.dart';

import 'game_definition.dart';
import 'network/lan_room_discovery.dart';
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
  late final LanRoomDiscovery discovery;
  StreamSubscription<NetworkMessage>? networkSubscription;
  bool isHost = true;
  bool gameOpened = false;
  bool discovering = false;
  final TextEditingController hostAddressController = TextEditingController();
  final TextEditingController roomCodeController = TextEditingController();

  bool get isLanOnly => widget.game.id == 'name_animal_object';

  @override
  void initState() {
    super.initState();
    networkCore = LocalNetworkCore(gameId: widget.game.id);
    discovery = LanRoomDiscovery(gameId: widget.game.id);
    networkSubscription = networkCore.messages.listen(_handleRoomMessage);
  }

  @override
  void dispose() {
    networkSubscription?.cancel();
    discovery.dispose();
    hostAddressController.dispose();
    roomCodeController.dispose();
    networkCore.dispose();
    super.dispose();
  }

  void _handleRoomMessage(NetworkMessage message) {
    if (!mounted || message.type != NetworkMessageType.startGame || gameOpened) {
      return;
    }
    _openGame(useNetwork: true);
  }

  Future<void> _createRoom() async {
    await networkCore.createRoom();
    final LocalNetworkState state = networkCore.state;
    if (state.mode == LocalNetworkMode.host &&
        state.status != LocalNetworkStatus.error) {
      await discovery.startAdvertising(
        roomCode: state.roomCode,
        gamePort: state.port,
      );
    }
  }

  Future<void> _discoverAndJoin() async {
    if (discovering) return;
    setState(() => discovering = true);
    final DiscoveredLanRoom? room = await discovery.discover();
    if (!mounted) return;
    if (room == null) {
      setState(() => discovering = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم يتم العثور على غرفة. تأكد أن الأجهزة على نفس الشبكة.'),
        ),
      );
      return;
    }
    hostAddressController.text = room.host;
    roomCodeController.text = room.roomCode;
    await networkCore.joinRoom(
      hostAddress: room.host,
      port: room.port,
      roomCode: room.roomCode,
    );
    if (mounted) setState(() => discovering = false);
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

  void _startOfflineGame() => _openGame(useNetwork: false);

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
    ).then((_) => gameOpened = false);
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
        return 'ابدأ فورًا على هذا الهاتف دون إنشاء غرفة.';
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
          final LocalNetworkState state =
              snapshot.data ?? LocalNetworkState.idle();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!isLanOnly) ...[
                Card(
                  elevation: 0,
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.55),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _offlineTitle,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(_offlineDescription),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _startOfflineGame,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('ابدأ الآن بدون إنترنت'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ] else ...[
                const Card(
                  color: Color(0xFFE8F5F2),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'ضع الهواتف على نفس Wi-Fi أو Hotspot. التطبيق سيكتشف غرفة اللعبة تلقائيًا دون كتابة IP.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.game.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('عدد اللاعبين: ${widget.game.playersText}'),
                      const SizedBox(height: 16),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: true,
                            label: Text('إنشاء غرفة'),
                            icon: Icon(Icons.wifi_tethering),
                          ),
                          ButtonSegment(
                            value: false,
                            label: Text('انضمام'),
                            icon: Icon(Icons.login),
                          ),
                        ],
                        selected: {isHost},
                        onSelectionChanged: (value) {
                          setState(() => isHost = value.first);
                          if (!value.first && isLanOnly) {
                            _discoverAndJoin();
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      if (!isHost && isLanOnly)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: discovering ? null : _discoverAndJoin,
                            icon: discovering
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.radar),
                            label: Text(
                              discovering
                                  ? 'جاري البحث عن الغرفة...'
                                  : 'البحث والاتصال تلقائيًا',
                            ),
                          ),
                        ),
                      if (!isHost && !isLanOnly) ...[
                        TextField(
                          controller: hostAddressController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'IP جهاز المضيف',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (isHost)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _createRoom,
                            icon: const Icon(Icons.add_link),
                            label: const Text('إنشاء الغرفة'),
                          ),
                        )
                      else if (!isLanOnly)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => networkCore.joinRoom(
                              hostAddress: hostAddressController.text,
                              port: LocalWifiTransport.defaultPort,
                              roomCode: roomCodeController.text.trim(),
                            ),
                            icon: const Icon(Icons.link),
                            label: const Text('الاتصال بالغرفة'),
                          ),
                        ),
                      const SizedBox(height: 12),
                      _NetworkStatusBox(
                        state: state,
                        onReconnect: networkCore.reconnect,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _PlayersCard(state: state, onStart: _startGame),
              const SizedBox(height: 12),
              _ConnectionPlanCard(autoDiscovery: isLanOnly),
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
      LocalNetworkMode.host => 'مضيف',
      LocalNetworkMode.client => 'لاعب',
      LocalNetworkMode.idle => 'غير متصل',
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
          Text('الوضع: $modeText',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(state.message),
          if (state.roomCode.isNotEmpty)
            Text('رمز الغرفة: ${state.roomCode}'),
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
    final bool canStart =
        state.mode == LocalNetworkMode.host && state.players.length >= 2;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'اللاعبون (${state.players.length}/12)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            if (state.players.isEmpty)
              const Text('لم ينضم أي لاعب بعد.')
            else
              ...state.players.map(
                (player) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    player.isHost ? Icons.workspace_premium : Icons.person,
                  ),
                  title: Text(player.name),
                  subtitle: Text(player.isHost ? 'المضيف • لاعب' : 'لاعب'),
                  trailing: Icon(
                    player.isReady
                        ? Icons.check_circle
                        : Icons.hourglass_empty,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canStart ? onStart : null,
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  canStart
                      ? 'بدء اللعبة على جميع الأجهزة'
                      : 'بانتظار لاعب آخر',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionPlanCard extends StatelessWidget {
  const _ConnectionPlanCard({required this.autoDiscovery});

  final bool autoDiscovery;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'طريقة الاتصال',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('1. اجعل جميع الهواتف على نفس Wi-Fi أو Hotspot.'),
            const Text('2. ينشئ لاعب واحد الغرفة.'),
            Text(
              autoDiscovery
                  ? '3. يضغط بقية اللاعبين انضمام، وسيتم اكتشاف الغرفة تلقائيًا.'
                  : '3. يدخل بقية اللاعبين عنوان المضيف للانضمام.',
            ),
            const Text('4. يبدأ المضيف اللعبة عند وجود لاعبين على الأقل.'),
          ],
        ),
      ),
    );
  }
}
