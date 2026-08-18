import 'dart:async';

import 'package:flutter/material.dart';

import '../design/app_theme.dart';
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

  bool get _supportsBrowserQr => const <String>{
        'name_animal_object',
        'sheikh_beard',
        'dots_boxes',
        'xo',
        'checkers',
      }.contains(widget.game.id);

  Color get _accent {
    switch (widget.game.id) {
      case 'football_penalties':
      case 'champions_penalties':
        return const Color(0xFF0EA5E9);
      case 'xo':
        return const Color(0xFF7C3AED);
      case 'checkers':
        return const Color(0xFFE11D48);
      case 'domino':
        return const Color(0xFF0F766E);
      case 'cards':
        return const Color(0xFFF59E0B);
      case 'name_animal_object':
        return const Color(0xFF8B5CF6);
      case 'sheikh_beard':
        return const Color(0xFF2563EB);
      case 'dots_boxes':
        return const Color(0xFF14B8A6);
      default:
        return AppColors.primary;
    }
  }

  @override
  void initState() {
    super.initState();
    networkCore = LocalNetworkCore(gameId: widget.game.id);
    _subscription = networkCore.messages.listen((NetworkMessage message) {
      if (message.type == NetworkMessageType.startGame && !_opened) {
        _openGame(useNetwork: true);
      }
    });
    _stateSubscription =
        networkCore.stateStream.listen((LocalNetworkState state) {
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

  Widget _modeButton({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[_accent, _accent.withOpacity(.72)],
                  )
                : null,
            color: selected ? null : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? _accent : const Color(0x1F0F172A),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: _accent.withOpacity(.24),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: Column(
            children: <Widget>[
              Icon(icon, color: selected ? Colors.white : _accent, size: 30),
              const SizedBox(height: 7),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white70 : AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roomStatusCard(LocalNetworkState state, bool hostReady) {
    final bool active = state.mode != LocalNetworkMode.idle;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: <Color>[
            const Color(0xFF071A26),
            Color.lerp(const Color(0xFF071A26), _accent, .34)!,
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x2A0F172A),
            blurRadius: 20,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  active ? Icons.wifi_tethering_rounded : Icons.link_off_rounded,
                  color: active ? const Color(0xFF5EEAD4) : Colors.white54,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      active ? 'الغرفة جاهزة' : 'لم يتم إنشاء غرفة بعد',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0x225EEAD4)
                      : const Color(0x18FFFFFF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: active
                        ? const Color(0x665EEAD4)
                        : const Color(0x28FFFFFF),
                  ),
                ),
                child: Text(
                  active ? 'متصل' : 'غير متصل',
                  style: TextStyle(
                    color: active ? const Color(0xFF99F6E4) : Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (state.roomCode.isNotEmpty) ...<Widget>[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.09),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(.12)),
              ),
              child: Column(
                children: <Widget>[
                  const Text(
                    'رمز الغرفة',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    state.roomCode,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      letterSpacing: 5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _supportsBrowserQr
                        ? 'افتح اللعبة لإظهار QR للمتصفح بعد انضمام اللاعب'
                        : 'شارك الرمز مع اللاعب الموجود على نفس الشبكة',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _roomMetric(
                  Icons.people_alt_rounded,
                  '${state.players.length}',
                  'متصلون',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _roomMetric(
                  hostReady ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                  hostReady ? 'جاهز' : 'انتظار',
                  'الحالة',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roomMetric(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, color: const Color(0xFF99F6E4), size: 17),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _playerStrip(LocalNetworkState state) {
    if (state.players.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x140F172A)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.person_add_alt_1_rounded, color: AppColors.muted),
            SizedBox(width: 8),
            Text(
              'بانتظار انضمام لاعب',
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: <Widget>[
        for (final LocalPlayer player in state.players)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: player.isHost ? _accent.withOpacity(.10) : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: player.isHost
                    ? _accent.withOpacity(.38)
                    : const Color(0x180F172A),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CircleAvatar(
                  radius: 11,
                  backgroundColor: player.isHost ? _accent : const Color(0xFFE2E8F0),
                  child: Icon(
                    player.isHost ? Icons.star_rounded : Icons.person_rounded,
                    size: 13,
                    color: player.isHost ? Colors.white : AppColors.ink,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  player.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _joinPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FilledButton.icon(
          onPressed: _searching || _joining ? null : _findRooms,
          icon: _searching || _joining
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.radar_rounded),
          label: Text(
            _joining
                ? 'جاري الدخول...'
                : _searching
                    ? 'جاري البحث على الشبكة...'
                    : 'البحث عن الغرف القريبة',
          ),
        ),
        if (_rooms.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          for (final DiscoveredRoom room in _rooms)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _accent.withOpacity(.22)),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.sports_esports_rounded, color: _accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          room.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'رمز ${room.roomCode}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: _joining ? null : () => _joinDiscoveredRoom(room),
                    child: const Text('دخول'),
                  ),
                ],
              ),
            ),
        ],
        if (_rooms.isEmpty && !_searching) ...<Widget>[
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 8),
            title: const Text(
              'اتصال يدوي',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text('استخدمه فقط إذا لم تظهر الغرفة تلقائيًا'),
            childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            children: <Widget>[
              TextField(
                controller: _hostController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'IP جهاز المضيف',
                  hintText: '192.168.1.8',
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
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
                            if (mounted) setState(() => _joining = false);
                          }
                        },
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('اتصال يدوي'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.game.name)),
      body: StreamBuilder<LocalNetworkState>(
        stream: networkCore.stateStream,
        initialData: networkCore.state,
        builder:
            (BuildContext context, AsyncSnapshot<LocalNetworkState> snapshot) {
          final LocalNetworkState state =
              snapshot.data ?? LocalNetworkState.idle();
          final bool hostReady = state.mode == LocalNetworkMode.host &&
              (state.status == LocalNetworkStatus.ready ||
                  state.status == LocalNetworkStatus.connected);
          final bool canStart = hostReady &&
              (_supportsBrowserQr
                  ? state.players.isNotEmpty
                  : state.players.length >= 2);
          final bool operationPending =
              state.status == LocalNetworkStatus.preparing || _joining;

          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 22),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: <Color>[
                      _accent.withOpacity(.15),
                      Colors.white,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: _accent.withOpacity(.16)),
                ),
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[_accent, _accent.withOpacity(.72)],
                        ),
                        borderRadius: BorderRadius.circular(19),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: _accent.withOpacity(.24),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.groups_2_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'اللعب الجماعي',
                      style: TextStyle(
                        color: _accent,
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      widget.game.name,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _supportsBrowserQr
                          ? 'أنشئ غرفة ثم ابدأ اللعبة؛ يمكن للاعب الآخر الانضمام من التطبيق أو المتصفح عبر QR.'
                          : 'اجعل الجهازين على نفس شبكة Wi-Fi، ثم أنشئ غرفة أو ابحث عن غرفة قريبة.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  _modeButton(
                    selected: _isHost,
                    icon: Icons.add_circle_outline_rounded,
                    title: 'إنشاء غرفة',
                    subtitle: 'أنا المضيف',
                    onTap: operationPending
                        ? null
                        : () => unawaited(_changeMode(true)),
                  ),
                  const SizedBox(width: 10),
                  _modeButton(
                    selected: !_isHost,
                    icon: Icons.travel_explore_rounded,
                    title: 'انضمام',
                    subtitle: 'ابحث عن المضيف',
                    onTap: operationPending
                        ? null
                        : () => unawaited(_changeMode(false)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isHost && state.mode == LocalNetworkMode.idle)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: _accent,
                  ),
                  onPressed: operationPending ? null : networkCore.createRoom,
                  icon: operationPending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering_rounded),
                  label: const Text('إنشاء الغرفة الآن'),
                )
              else if (!_isHost)
                _joinPanel(),
              if (_isHost || state.mode != LocalNetworkMode.idle) ...<Widget>[
                if (!(_isHost && state.mode == LocalNetworkMode.idle))
                  _roomStatusCard(state, hostReady),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(Icons.people_alt_rounded, color: _accent),
                            const SizedBox(width: 8),
                            const Text(
                              'اللاعبون في الغرفة',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _playerStrip(state),
                        if (_isHost) ...<Widget>[
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              backgroundColor: canStart ? _accent : null,
                            ),
                            onPressed: canStart ? _start : null,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: Text(
                              canStart
                                  ? (_supportsBrowserQr
                                      ? 'بدء اللعبة وفتح QR'
                                      : 'بدء اللعبة على الجميع')
                                  : 'بانتظار لاعب للبدء',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              if (!_isNameGame) ...<Widget>[
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFF0F766E), Color(0xFF6D28D9)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(color: Color(0x260F172A), blurRadius: 14, offset: Offset(0, 6)),
                    ],
                  ),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: () => _openGame(useNetwork: false),
                    icon: const Icon(Icons.smart_toy_rounded),
                    label: const Text(
                      'اللعب مع الروبوت / محليًا',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
