import 'dart:async';
import 'dart:collection';

import 'internet_relay_transport.dart';
import 'local_wifi_transport.dart';
import 'network_message.dart';
import 'network_transport.dart';

class LocalPlayer {
  const LocalPlayer({
    required this.id,
    required this.name,
    required this.isHost,
    this.isReady = false,
  });

  final String id;
  final String name;
  final bool isHost;
  final bool isReady;

  LocalPlayer copyWith(
      {String? id, String? name, bool? isHost, bool? isReady}) {
    return LocalPlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      isHost: isHost ?? this.isHost,
      isReady: isReady ?? this.isReady,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'isHost': isHost,
        'isReady': isReady,
      };

  factory LocalPlayer.fromJson(Map<dynamic, dynamic> json) {
    return LocalPlayer(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'لاعب').toString(),
      isHost: json['isHost'] == true,
      isReady: json['isReady'] == true,
    );
  }
}

enum LocalNetworkMode { idle, host, client }

enum NetworkConnectionKind { local, internet }

enum LocalNetworkStatus {
  idle,
  preparing,
  ready,
  connected,
  disconnected,
  error,
}

class LocalNetworkState {
  const LocalNetworkState({
    required this.mode,
    required this.status,
    required this.players,
    this.connectionKind = NetworkConnectionKind.local,
    this.roomCode = '',
    this.hostAddress = '',
    this.port = LocalWifiTransport.defaultPort,
    this.message = 'غير متصل',
  });

  final LocalNetworkMode mode;
  final LocalNetworkStatus status;
  final List<LocalPlayer> players;
  final NetworkConnectionKind connectionKind;
  final String roomCode;
  final String hostAddress;
  final int port;
  final String message;

  factory LocalNetworkState.idle() {
    return const LocalNetworkState(
      mode: LocalNetworkMode.idle,
      status: LocalNetworkStatus.idle,
      players: <LocalPlayer>[],
    );
  }

  LocalNetworkState copyWith({
    LocalNetworkMode? mode,
    LocalNetworkStatus? status,
    List<LocalPlayer>? players,
    NetworkConnectionKind? connectionKind,
    String? roomCode,
    String? hostAddress,
    int? port,
    String? message,
  }) {
    return LocalNetworkState(
      mode: mode ?? this.mode,
      status: status ?? this.status,
      players: players ?? this.players,
      connectionKind: connectionKind ?? this.connectionKind,
      roomCode: roomCode ?? this.roomCode,
      hostAddress: hostAddress ?? this.hostAddress,
      port: port ?? this.port,
      message: message ?? this.message,
    );
  }
}

class LocalNetworkCore {
  LocalNetworkCore({required this.gameId}) {
    _activeCores[gameId] = this;
    _transport = LocalWifiTransport(gameId: gameId);
    _bindTransport();
  }

  void _bindTransport() {
    _transportStatusSubscription =
        _transport.status.listen((String statusMessage) {
      _emit(_state.copyWith(message: statusMessage));
    });
    _transportMessageSubscription =
        _transport.messages.listen(_handleIncomingMessage);
  }

  static final Map<String, LocalNetworkCore> _activeCores =
      <String, LocalNetworkCore>{};

  static LocalNetworkCore? activeFor(String gameId) => _activeCores[gameId];

  final String gameId;
  final StreamController<LocalNetworkState> _stateController =
      StreamController<LocalNetworkState>.broadcast();
  final StreamController<NetworkMessage> _messageController =
      StreamController<NetworkMessage>.broadcast();
  late NetworkTransport _transport;
  StreamSubscription<String>? _transportStatusSubscription;
  StreamSubscription<NetworkMessage>? _transportMessageSubscription;
  final Set<String> _seenMessageKeys = <String>{};
  final Queue<String> _seenMessageOrder = Queue<String>();

  LocalNetworkState _state = LocalNetworkState.idle();
  String _localPlayerId = 'system';

  LocalNetworkState get state => _state;
  Stream<LocalNetworkState> get stateStream => _stateController.stream;
  Stream<NetworkMessage> get messages => _messageController.stream;
  String get localPlayerId => _localPlayerId;
  bool get isInternetConfigured => InternetRelayTransport.isConfigured;
  String get hostPlayerName {
    final List<LocalPlayer> hosts =
        _state.players.where((LocalPlayer player) => player.isHost).toList();
    return hosts.isEmpty ? 'الداعي' : hosts.first.name;
  }

  Future<void> createRoom({required String playerName}) async {
    final String cleanedPlayerName = playerName.trim();
    if (cleanedPlayerName.isEmpty) {
      _emit(_state.copyWith(
        status: LocalNetworkStatus.error,
        message: 'اكتب اسمك قبل إنشاء الغرفة.',
      ));
      return;
    }
    _emit(_state.copyWith(
      mode: LocalNetworkMode.host,
      connectionKind: NetworkConnectionKind.local,
      status: LocalNetworkStatus.preparing,
      players: const <LocalPlayer>[],
      message: 'جاري تشغيل الدعوة على Wi-Fi / Hotspot...',
    ));

    try {
      final LocalWifiTransport transport = LocalWifiTransport(gameId: gameId);
      await _replaceTransport(transport);
      final String endpoint = await transport.startHost();
      final List<String> endpointParts = endpoint.split(':');
      final String hostAddress =
          endpointParts.isNotEmpty ? endpointParts.first : '';
      final int port = endpointParts.length > 1
          ? int.tryParse(endpointParts.last) ?? LocalWifiTransport.defaultPort
          : LocalWifiTransport.defaultPort;
      final String roomCode = _buildRoomCode();
      final LocalPlayer host = LocalPlayer(
        id: 'host-$roomCode',
        name: cleanedPlayerName,
        isHost: true,
        isReady: true,
      );
      _localPlayerId = host.id;

      _emit(LocalNetworkState(
        mode: LocalNetworkMode.host,
        status: LocalNetworkStatus.ready,
        roomCode: roomCode,
        hostAddress: hostAddress,
        port: port,
        players: <LocalPlayer>[host],
        message: 'الغرفة تعمل. يمكن لعدة لاعبين الانضمام إلى نفس IP.',
      ));

      _publish(NetworkMessage(
        type: NetworkMessageType.roomCreated,
        gameId: gameId,
        senderId: host.id,
        payload: <String, dynamic>{
          'roomCode': roomCode,
          'hostAddress': hostAddress,
          'port': port,
        },
      ));
    } catch (_) {
      _emit(_state.copyWith(
        status: LocalNetworkStatus.error,
        message: 'تعذر تشغيل الغرفة. تأكد من Wi-Fi أو Hotspot.',
      ));
    }
  }

  Future<void> joinRoom({
    required String hostAddress,
    required String playerName,
    int port = LocalWifiTransport.defaultPort,
    String roomCode = '',
  }) async {
    final String cleanedHost = hostAddress.trim();
    final String cleanedPlayerName = playerName.trim();
    if (cleanedPlayerName.isEmpty) {
      _emit(_state.copyWith(
        status: LocalNetworkStatus.error,
        message: 'اكتب اسمك قبل الانضمام إلى الغرفة.',
      ));
      return;
    }
    if (cleanedHost.isEmpty) {
      _emit(_state.copyWith(
        status: LocalNetworkStatus.error,
        message: 'أدخل IP جهاز الداعي.',
      ));
      return;
    }

    _emit(_state.copyWith(
      mode: LocalNetworkMode.client,
      connectionKind: NetworkConnectionKind.local,
      status: LocalNetworkStatus.preparing,
      hostAddress: cleanedHost,
      port: port,
      message: 'جاري الاتصال بالغرفة...',
    ));

    try {
      final LocalWifiTransport transport = LocalWifiTransport(gameId: gameId);
      await _replaceTransport(transport);
      await transport.connectToHost(host: cleanedHost, port: port);
      final String suffix = DateTime.now().microsecondsSinceEpoch.toString();
      final LocalPlayer guest = LocalPlayer(
        id: 'client-$suffix',
        name: cleanedPlayerName,
        isHost: false,
        isReady: true,
      );
      _localPlayerId = guest.id;

      _emit(LocalNetworkState(
        mode: LocalNetworkMode.client,
        status: LocalNetworkStatus.connected,
        roomCode: roomCode,
        hostAddress: cleanedHost,
        port: port,
        players: <LocalPlayer>[guest],
        message: 'تم الاتصال بالغرفة. انتظر الداعي لبدء اللعبة.',
      ));

      _transport.send(NetworkMessage(
        type: NetworkMessageType.playerJoined,
        gameId: gameId,
        senderId: guest.id,
        payload: <String, dynamic>{
          'roomCode': roomCode,
          'hostAddress': cleanedHost,
          'port': port,
          'name': guest.name,
        },
      ));
    } catch (_) {
      _emit(_state.copyWith(
        status: LocalNetworkStatus.error,
        message: 'فشل الاتصال. تأكد أن الأجهزة على نفس الشبكة وأن IP صحيح.',
      ));
    }
  }

  Future<void> createInternetRoom({required String playerName}) async {
    final String cleanedPlayerName = playerName.trim();
    if (cleanedPlayerName.isEmpty) {
      _emit(_state.copyWith(
        status: LocalNetworkStatus.error,
        message: 'اكتب اسمك قبل إنشاء الغرفة.',
      ));
      return;
    }
    if (!InternetRelayTransport.isConfigured) {
      _emit(_state.copyWith(
        connectionKind: NetworkConnectionKind.internet,
        status: LocalNetworkStatus.error,
        message: 'خادم اللعب عبر الإنترنت غير مهيأ في هذه النسخة.',
      ));
      return;
    }

    _emit(_state.copyWith(
      mode: LocalNetworkMode.host,
      connectionKind: NetworkConnectionKind.internet,
      status: LocalNetworkStatus.preparing,
      players: const <LocalPlayer>[],
      hostAddress: '',
      message: 'جاري إنشاء غرفة إنترنت آمنة...',
    ));
    try {
      final InternetRelayTransport transport =
          InternetRelayTransport(gameId: gameId);
      await _replaceTransport(transport);
      final String roomCode = await transport.createRoom();
      final LocalPlayer host = LocalPlayer(
        id: 'host-$roomCode',
        name: cleanedPlayerName,
        isHost: true,
        isReady: true,
      );
      _localPlayerId = host.id;
      _emit(LocalNetworkState(
        mode: LocalNetworkMode.host,
        connectionKind: NetworkConnectionKind.internet,
        status: LocalNetworkStatus.ready,
        roomCode: roomCode,
        players: <LocalPlayer>[host],
        message: 'غرفة الإنترنت جاهزة. شارك الرمز مع من تريد.',
      ));
      _publish(NetworkMessage(
        type: NetworkMessageType.roomCreated,
        gameId: gameId,
        senderId: host.id,
        payload: <String, dynamic>{'roomCode': roomCode, 'internet': true},
      ));
    } catch (_) {
      _emit(_state.copyWith(
        status: LocalNetworkStatus.error,
        message: 'تعذر إنشاء غرفة الإنترنت. تحقق من اتصالك وحاول مجددًا.',
      ));
    }
  }

  Future<void> joinInternetRoom({
    required String roomCode,
    required String playerName,
  }) async {
    final String cleanedPlayerName = playerName.trim();
    final String cleanedRoomCode = roomCode
        .toUpperCase()
        .replaceAll(RegExp('[^A-Z0-9]'), '');
    if (cleanedPlayerName.isEmpty) {
      _emit(_state.copyWith(
        status: LocalNetworkStatus.error,
        message: 'اكتب اسمك قبل الانضمام إلى الغرفة.',
      ));
      return;
    }
    if (cleanedRoomCode.length != 6) {
      _emit(_state.copyWith(
        connectionKind: NetworkConnectionKind.internet,
        status: LocalNetworkStatus.error,
        message: 'أدخل رمز الغرفة المكوّن من 6 أحرف وأرقام.',
      ));
      return;
    }
    if (!InternetRelayTransport.isConfigured) {
      _emit(_state.copyWith(
        connectionKind: NetworkConnectionKind.internet,
        status: LocalNetworkStatus.error,
        message: 'خادم اللعب عبر الإنترنت غير مهيأ في هذه النسخة.',
      ));
      return;
    }

    _emit(_state.copyWith(
      mode: LocalNetworkMode.client,
      connectionKind: NetworkConnectionKind.internet,
      status: LocalNetworkStatus.preparing,
      roomCode: cleanedRoomCode,
      hostAddress: '',
      message: 'جاري الدخول إلى غرفة الإنترنت...',
    ));
    try {
      final InternetRelayTransport transport =
          InternetRelayTransport(gameId: gameId);
      await _replaceTransport(transport);
      final String acceptedRoomCode = await transport.joinRoom(cleanedRoomCode);
      final String suffix = DateTime.now().microsecondsSinceEpoch.toString();
      final LocalPlayer guest = LocalPlayer(
        id: 'client-$suffix',
        name: cleanedPlayerName,
        isHost: false,
        isReady: true,
      );
      _localPlayerId = guest.id;
      _emit(LocalNetworkState(
        mode: LocalNetworkMode.client,
        connectionKind: NetworkConnectionKind.internet,
        status: LocalNetworkStatus.connected,
        roomCode: acceptedRoomCode,
        players: <LocalPlayer>[guest],
        message: 'تم الدخول. انتظر الداعي لبدء اللعبة.',
      ));
      _transport.send(NetworkMessage(
        type: NetworkMessageType.playerJoined,
        gameId: gameId,
        senderId: guest.id,
        payload: <String, dynamic>{
          'roomCode': acceptedRoomCode,
          'name': guest.name,
          'internet': true,
        },
      ));
    } catch (_) {
      _emit(_state.copyWith(
        status: LocalNetworkStatus.error,
        message: 'تعذر دخول الغرفة. تأكد من الرمز واتصال الإنترنت.',
      ));
    }
  }

  Future<void> _replaceTransport(NetworkTransport next) async {
    await _transportStatusSubscription?.cancel();
    await _transportMessageSubscription?.cancel();
    await _transport.dispose();
    _transport = next;
    _bindTransport();
  }

  void updateLocalPlayerName(String name) {
    final String cleaned = name.trim();
    if (cleaned.isEmpty || _localPlayerId == 'system') return;

    final List<LocalPlayer> updated = _state.players.map((LocalPlayer player) {
      return player.id == _localPlayerId
          ? player.copyWith(name: cleaned)
          : player;
    }).toList(growable: false);
    _emit(_state.copyWith(players: updated));

    _sendAndPublish(NetworkMessage(
      type: NetworkMessageType.hello,
      gameId: gameId,
      senderId: _localPlayerId,
      payload: <String, dynamic>{'name': cleaned},
    ));

    if (_state.mode == LocalNetworkMode.host) _broadcastRoster();
  }

  void markReady(String playerId, bool ready) {
    final List<LocalPlayer> updatedPlayers = _state.players
        .map((LocalPlayer player) =>
            player.id == playerId ? player.copyWith(isReady: ready) : player)
        .toList(growable: false);
    _emit(_state.copyWith(players: updatedPlayers));
    _sendAndPublish(NetworkMessage(
      type: NetworkMessageType.playerReady,
      gameId: gameId,
      senderId: playerId,
      payload: <String, dynamic>{'ready': ready},
    ));
    if (_state.mode == LocalNetworkMode.host) _broadcastRoster();
  }

  void startGame() {
    _sendAndPublish(NetworkMessage(
      type: NetworkMessageType.startGame,
      gameId: gameId,
      senderId: localPlayerId,
      payload: <String, dynamic>{'roomCode': _state.roomCode},
    ));
  }

  void sendMove(Map<String, dynamic> movePayload, {required String senderId}) {
    _sendAndPublish(NetworkMessage(
      type: NetworkMessageType.move,
      gameId: gameId,
      senderId: senderId,
      payload: movePayload,
    ));
  }

  Future<void> reconnect() async {
    final LocalNetworkState previous = _state;
    final List<String> previousNames = previous.players
        .where((LocalPlayer player) => player.id == _localPlayerId)
        .map((LocalPlayer player) => player.name)
        .toList(growable: false);
    final String previousPlayerName =
        previousNames.isEmpty ? 'لاعب' : previousNames.first;
    await _transport.close();
    if (previous.connectionKind == NetworkConnectionKind.internet) {
      if (previous.mode == LocalNetworkMode.host) {
        await createInternetRoom(playerName: previousPlayerName);
      } else if (previous.mode == LocalNetworkMode.client &&
          previous.roomCode.isNotEmpty) {
        await joinInternetRoom(
          roomCode: previous.roomCode,
          playerName: previousPlayerName,
        );
      }
      return;
    }
    if (previous.mode == LocalNetworkMode.host) {
      await createRoom(playerName: previousPlayerName);
    } else if (previous.mode == LocalNetworkMode.client &&
        previous.hostAddress.isNotEmpty) {
      await joinRoom(
        hostAddress: previous.hostAddress,
        playerName: previousPlayerName,
        port: previous.port,
        roomCode: previous.roomCode,
      );
    } else {
      _emit(_state.copyWith(
        status: LocalNetworkStatus.error,
        message: 'لا توجد بيانات اتصال سابقة.',
      ));
    }
  }

  void disconnect() {
    _sendAndPublish(NetworkMessage(
      type: NetworkMessageType.disconnect,
      gameId: gameId,
      senderId: localPlayerId,
    ));
    _transport.close();
    _emit(_state.copyWith(
      status: LocalNetworkStatus.disconnected,
      message: _state.connectionKind == NetworkConnectionKind.internet
          ? 'تم قطع اتصال الإنترنت.'
          : 'تم قطع الاتصال المحلي.',
    ));
  }

  Future<void> reset({
    NetworkConnectionKind connectionKind = NetworkConnectionKind.local,
  }) async {
    if (_state.mode != LocalNetworkMode.idle && _localPlayerId != 'system') {
      _sendAndPublish(NetworkMessage(
        type: NetworkMessageType.disconnect,
        gameId: gameId,
        senderId: _localPlayerId,
      ));
    }
    await _replaceTransport(LocalWifiTransport(gameId: gameId));
    _localPlayerId = 'system';
    _seenMessageKeys.clear();
    _seenMessageOrder.clear();
    _emit(LocalNetworkState.idle().copyWith(connectionKind: connectionKind));
  }

  void _handleIncomingMessage(NetworkMessage message) {
    if (message.gameId != gameId) return;
    final String messageKey = '${message.senderId}|${message.type.name}|'
        '${message.createdAt.microsecondsSinceEpoch}|${message.payload['action'] ?? ''}';
    if (!_seenMessageKeys.add(messageKey)) return;
    _seenMessageOrder.addLast(messageKey);
    while (_seenMessageOrder.length > 256) {
      _seenMessageKeys.remove(_seenMessageOrder.removeFirst());
    }
    _publish(message);

    if (message.type == NetworkMessageType.hello &&
        message.payload['action'] == 'room_roster') {
      _applyRoster(message.payload);
      return;
    }

    if (_state.mode == LocalNetworkMode.client &&
        message.type == NetworkMessageType.disconnect &&
        (message.senderId == 'host-connection' ||
            message.senderId == 'internet-relay')) {
      _emit(_state.copyWith(
        status: LocalNetworkStatus.disconnected,
        message: _state.connectionKind == NetworkConnectionKind.internet
            ? 'انقطع الاتصال بغرفة الإنترنت.'
            : 'انقطع الاتصال بجهاز الداعي.',
      ));
      return;
    }

    if (_state.mode != LocalNetworkMode.host) return;

    if (message.type == NetworkMessageType.playerJoined) {
      final bool alreadyExists = _state.players
          .any((LocalPlayer player) => player.id == message.senderId);
      if (!alreadyExists && _state.players.length < 12) {
        final String name = (message.payload['name'] ?? '').toString().trim();
        _emit(_state.copyWith(
          status: LocalNetworkStatus.connected,
          players: <LocalPlayer>[
            ..._state.players,
            LocalPlayer(
              id: message.senderId,
              name: name.isEmpty ? 'اللاعب ${_state.players.length + 1}' : name,
              isHost: false,
              isReady: true,
            ),
          ],
          message: 'انضم لاعب جديد — العدد ${_state.players.length + 1}.',
        ));
        _broadcastRoster();
      }
    } else if (message.type == NetworkMessageType.hello) {
      final String name = (message.payload['name'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        _emit(_state.copyWith(
          players: _state.players
              .map((LocalPlayer player) => player.id == message.senderId
                  ? player.copyWith(name: name)
                  : player)
              .toList(growable: false),
        ));
        _broadcastRoster();
      }
    } else if (message.type == NetworkMessageType.playerReady) {
      final bool ready = message.payload['ready'] == true;
      _emit(_state.copyWith(
        players: _state.players
            .map((LocalPlayer player) => player.id == message.senderId
                ? player.copyWith(isReady: ready)
                : player)
            .toList(growable: false),
      ));
      _broadcastRoster();
    } else if (message.type == NetworkMessageType.disconnect) {
      _emit(_state.copyWith(
        players: _state.players
            .where((LocalPlayer player) => player.id != message.senderId)
            .toList(growable: false),
        message: 'غادر لاعب — العدد ${_state.players.length - 1}.',
      ));
      _broadcastRoster();
    }
  }

  void _broadcastRoster() {
    if (_state.mode != LocalNetworkMode.host) return;
    _transport.send(NetworkMessage(
      type: NetworkMessageType.hello,
      gameId: gameId,
      senderId: _localPlayerId,
      payload: <String, dynamic>{
        'action': 'room_roster',
        'players': _state.players
            .map((LocalPlayer player) => player.toJson())
            .toList(growable: false),
      },
    ));
  }

  void _applyRoster(Map<String, dynamic> payload) {
    final List<dynamic> rawPlayers =
        payload['players'] as List<dynamic>? ?? <dynamic>[];
    final List<LocalPlayer> players = rawPlayers
        .whereType<Map>()
        .map((Map<dynamic, dynamic> item) => LocalPlayer.fromJson(item))
        .where((LocalPlayer player) => player.id.isNotEmpty)
        .toList(growable: false);
    if (players.isEmpty) return;
    _emit(_state.copyWith(
      status: LocalNetworkStatus.connected,
      players: players,
      message: 'تم تحديث قائمة اللاعبين — العدد ${players.length}.',
    ));
  }

  void _sendAndPublish(NetworkMessage message) {
    _transport.send(message);
    _publish(message);
  }

  void _publish(NetworkMessage message) {
    if (!_messageController.isClosed) _messageController.add(message);
  }

  void _emit(LocalNetworkState nextState) {
    _state = nextState;
    if (!_stateController.isClosed) _stateController.add(nextState);
  }

  String _buildRoomCode() {
    final int code =
        DateTime.now().millisecondsSinceEpoch.remainder(9000) + 1000;
    return code.toString();
  }

  void dispose() {
    if (identical(_activeCores[gameId], this)) _activeCores.remove(gameId);
    _transportStatusSubscription?.cancel();
    _transportMessageSubscription?.cancel();
    _transport.dispose();
    _stateController.close();
    _messageController.close();
  }
}
