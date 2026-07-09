import 'dart:async';

import 'local_wifi_transport.dart';
import 'network_message.dart';

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

  LocalPlayer copyWith({String? id, String? name, bool? isHost, bool? isReady}) {
    return LocalPlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      isHost: isHost ?? this.isHost,
      isReady: isReady ?? this.isReady,
    );
  }
}

enum LocalNetworkMode { idle, host, client }

enum LocalNetworkStatus { idle, preparing, ready, connected, disconnected, error }

class LocalNetworkState {
  const LocalNetworkState({
    required this.mode,
    required this.status,
    required this.players,
    this.roomCode = '',
    this.hostAddress = '',
    this.port = LocalWifiTransport.defaultPort,
    this.message = 'غير متصل',
  });

  final LocalNetworkMode mode;
  final LocalNetworkStatus status;
  final List<LocalPlayer> players;
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
    String? roomCode,
    String? hostAddress,
    int? port,
    String? message,
  }) {
    return LocalNetworkState(
      mode: mode ?? this.mode,
      status: status ?? this.status,
      players: players ?? this.players,
      roomCode: roomCode ?? this.roomCode,
      hostAddress: hostAddress ?? this.hostAddress,
      port: port ?? this.port,
      message: message ?? this.message,
    );
  }
}

class LocalNetworkCore {
  LocalNetworkCore({required this.gameId}) {
    _transportStatusSubscription = _transport.status.listen((statusMessage) {
      _emit(_state.copyWith(message: statusMessage));
    });

    _transportMessageSubscription = _transport.messages.listen(_handleIncomingMessage);
  }

  final String gameId;
  final StreamController<LocalNetworkState> _stateController = StreamController<LocalNetworkState>.broadcast();
  final StreamController<NetworkMessage> _messageController = StreamController<NetworkMessage>.broadcast();
  late final LocalWifiTransport _transport = LocalWifiTransport(gameId: gameId);
  StreamSubscription<String>? _transportStatusSubscription;
  StreamSubscription<NetworkMessage>? _transportMessageSubscription;

  LocalNetworkState _state = LocalNetworkState.idle();

  LocalNetworkState get state => _state;
  Stream<LocalNetworkState> get stateStream => _stateController.stream;
  Stream<NetworkMessage> get messages => _messageController.stream;

  Future<void> createRoom() async {
    _emit(_state.copyWith(
      mode: LocalNetworkMode.host,
      status: LocalNetworkStatus.preparing,
      players: const <LocalPlayer>[],
      message: 'جاري تشغيل المضيف على Wi-Fi / Hotspot...',
    ));

    try {
      final String endpoint = await _transport.startHost();
      final List<String> endpointParts = endpoint.split(':');
      final String hostAddress = endpointParts.isNotEmpty ? endpointParts.first : '';
      final int port = endpointParts.length > 1 ? int.tryParse(endpointParts.last) ?? LocalWifiTransport.defaultPort : LocalWifiTransport.defaultPort;
      final String roomCode = _buildRoomCode();
      final LocalPlayer host = LocalPlayer(
        id: 'host-$roomCode',
        name: 'اللاعب 1',
        isHost: true,
        isReady: true,
      );

      _emit(LocalNetworkState(
        mode: LocalNetworkMode.host,
        status: LocalNetworkStatus.ready,
        roomCode: roomCode,
        hostAddress: hostAddress,
        port: port,
        players: <LocalPlayer>[host],
        message: 'الغرفة تعمل الآن. أدخل IP في جهاز اللاعب الثاني للانضمام.',
      ));

      _publish(NetworkMessage(
        type: NetworkMessageType.roomCreated,
        gameId: gameId,
        senderId: host.id,
        payload: <String, dynamic>{'roomCode': roomCode, 'hostAddress': hostAddress, 'port': port},
      ));
    } catch (error) {
      _emit(_state.copyWith(
        status: LocalNetworkStatus.error,
        message: 'تعذر تشغيل الغرفة. تأكد أن الجهاز على Wi-Fi أو Hotspot ثم جرّب مرة أخرى.',
      ));
    }
  }

  Future<void> joinRoom({required String hostAddress, int port = LocalWifiTransport.defaultPort, String roomCode = ''}) async {
    final String cleanedHost = hostAddress.trim();
    if (cleanedHost.isEmpty) {
      _emit(_state.copyWith(status: LocalNetworkStatus.error, message: 'أدخل IP جهاز اللاعب الأول للانضمام.'));
      return;
    }

    _emit(_state.copyWith(
      mode: LocalNetworkMode.client,
      status: LocalNetworkStatus.preparing,
      hostAddress: cleanedHost,
      port: port,
      message: 'جاري الاتصال بالغرفة عبر Wi-Fi / Hotspot...',
    ));

    try {
      await _transport.connectToHost(host: cleanedHost, port: port);
      final LocalPlayer guest = LocalPlayer(
        id: 'client-${roomCode.isEmpty ? cleanedHost : roomCode}',
        name: 'اللاعب 2',
        isHost: false,
        isReady: true,
      );

      _emit(LocalNetworkState(
        mode: LocalNetworkMode.client,
        status: LocalNetworkStatus.connected,
        roomCode: roomCode,
        hostAddress: cleanedHost,
        port: port,
        players: <LocalPlayer>[guest],
        message: 'تم الاتصال بالغرفة. انتظر اللاعب الأول لبدء اللعبة.',
      ));

      _transport.send(NetworkMessage(
        type: NetworkMessageType.playerJoined,
        gameId: gameId,
        senderId: guest.id,
        payload: <String, dynamic>{'roomCode': roomCode, 'hostAddress': cleanedHost, 'port': port},
      ));
    } catch (error) {
      _emit(_state.copyWith(
        status: LocalNetworkStatus.error,
        message: 'فشل الاتصال. تأكد أن الجهازين على نفس Wi-Fi / Hotspot وأن IP صحيح.',
      ));
    }
  }

  void markReady(String playerId, bool ready) {
    final List<LocalPlayer> updatedPlayers = _state.players
        .map((player) => player.id == playerId ? player.copyWith(isReady: ready) : player)
        .toList(growable: false);

    _emit(_state.copyWith(players: updatedPlayers, message: 'تم تحديث جاهزية اللاعب.'));
    _sendAndPublish(NetworkMessage(
      type: NetworkMessageType.playerReady,
      gameId: gameId,
      senderId: playerId,
      payload: <String, dynamic>{'ready': ready},
    ));
  }

  void startGame() {
    final String senderId = _state.players.isEmpty ? 'system' : _state.players.first.id;
    _sendAndPublish(NetworkMessage(
      type: NetworkMessageType.startGame,
      gameId: gameId,
      senderId: senderId,
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

  void disconnect() {
    _sendAndPublish(NetworkMessage(
      type: NetworkMessageType.disconnect,
      gameId: gameId,
      senderId: 'system',
    ));
    _transport.close();
    _emit(_state.copyWith(status: LocalNetworkStatus.disconnected, message: 'تم قطع الاتصال المحلي.'));
  }

  void _handleIncomingMessage(NetworkMessage message) {
    if (message.gameId != gameId) return;
    _publish(message);

    if (message.type == NetworkMessageType.playerJoined && _state.mode == LocalNetworkMode.host) {
      final bool alreadyExists = _state.players.any((player) => player.id == message.senderId);
      if (!alreadyExists) {
        _emit(_state.copyWith(
          status: LocalNetworkStatus.connected,
          players: <LocalPlayer>[
            ..._state.players,
            LocalPlayer(id: message.senderId, name: 'اللاعب 2', isHost: false, isReady: true),
          ],
          message: 'تم انضمام اللاعب الثاني. يمكن للاعب الأول بدء اللعبة الآن.',
        ));
      }
    }
  }

  void _sendAndPublish(NetworkMessage message) {
    _transport.send(message);
    _publish(message);
  }

  void _publish(NetworkMessage message) {
    if (!_messageController.isClosed) {
      _messageController.add(message);
    }
  }

  void _emit(LocalNetworkState nextState) {
    _state = nextState;
    if (!_stateController.isClosed) {
      _stateController.add(nextState);
    }
  }

  String _buildRoomCode() {
    final int code = DateTime.now().millisecondsSinceEpoch.remainder(9000) + 1000;
    return code.toString();
  }

  void dispose() {
    _transportStatusSubscription?.cancel();
    _transportMessageSubscription?.cancel();
    _transport.dispose();
    _stateController.close();
    _messageController.close();
  }
}
