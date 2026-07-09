import 'dart:async';

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
    this.message = 'غير متصل',
  });

  final LocalNetworkMode mode;
  final LocalNetworkStatus status;
  final List<LocalPlayer> players;
  final String roomCode;
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
    String? message,
  }) {
    return LocalNetworkState(
      mode: mode ?? this.mode,
      status: status ?? this.status,
      players: players ?? this.players,
      roomCode: roomCode ?? this.roomCode,
      message: message ?? this.message,
    );
  }
}

class LocalNetworkCore {
  LocalNetworkCore({required this.gameId});

  final String gameId;
  final StreamController<LocalNetworkState> _stateController = StreamController<LocalNetworkState>.broadcast();
  final StreamController<NetworkMessage> _messageController = StreamController<NetworkMessage>.broadcast();

  LocalNetworkState _state = LocalNetworkState.idle();

  LocalNetworkState get state => _state;
  Stream<LocalNetworkState> get stateStream => _stateController.stream;
  Stream<NetworkMessage> get messages => _messageController.stream;

  Future<void> createRoom() async {
    _emit(_state.copyWith(
      mode: LocalNetworkMode.host,
      status: LocalNetworkStatus.preparing,
      players: const <LocalPlayer>[],
      message: 'جاري تجهيز غرفة Wi-Fi المحلية...',
    ));

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
      players: <LocalPlayer>[host],
      message: 'الغرفة جاهزة محليًا. الربط الفعلي بالـ Wi-Fi سيكون في الخطوة التالية.',
    ));

    _messageController.add(NetworkMessage(
      type: NetworkMessageType.roomCreated,
      gameId: gameId,
      senderId: host.id,
      payload: <String, dynamic>{'roomCode': roomCode},
    ));
  }

  Future<void> joinRoom({required String roomCode}) async {
    final LocalPlayer guest = LocalPlayer(
      id: 'client-$roomCode',
      name: 'اللاعب 2',
      isHost: false,
      isReady: true,
    );

    _emit(LocalNetworkState(
      mode: LocalNetworkMode.client,
      status: LocalNetworkStatus.connected,
      roomCode: roomCode,
      players: <LocalPlayer>[guest],
      message: 'تم تجهيز الانضمام محليًا. مزامنة الشبكة الفعلية في الخطوة التالية.',
    ));

    _messageController.add(NetworkMessage(
      type: NetworkMessageType.playerJoined,
      gameId: gameId,
      senderId: guest.id,
      payload: <String, dynamic>{'roomCode': roomCode},
    ));
  }

  void markReady(String playerId, bool ready) {
    final List<LocalPlayer> updatedPlayers = _state.players
        .map((player) => player.id == playerId ? player.copyWith(isReady: ready) : player)
        .toList(growable: false);

    _emit(_state.copyWith(players: updatedPlayers, message: 'تم تحديث جاهزية اللاعب.'));
    _messageController.add(NetworkMessage(
      type: NetworkMessageType.playerReady,
      gameId: gameId,
      senderId: playerId,
      payload: <String, dynamic>{'ready': ready},
    ));
  }

  void sendMove(Map<String, dynamic> movePayload, {required String senderId}) {
    _messageController.add(NetworkMessage(
      type: NetworkMessageType.move,
      gameId: gameId,
      senderId: senderId,
      payload: movePayload,
    ));
  }

  void disconnect() {
    _emit(_state.copyWith(status: LocalNetworkStatus.disconnected, message: 'تم قطع الاتصال المحلي.'));
    _messageController.add(NetworkMessage(
      type: NetworkMessageType.disconnect,
      gameId: gameId,
      senderId: 'system',
    ));
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
    _stateController.close();
    _messageController.close();
  }
}
