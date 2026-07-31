import 'dart:async';
import 'dart:convert';
import 'dart:io';

class DiscoveredLanRoom {
  const DiscoveredLanRoom({
    required this.gameId,
    required this.host,
    required this.port,
    required this.roomCode,
  });

  final String gameId;
  final String host;
  final int port;
  final String roomCode;
}

class LanRoomDiscovery {
  LanRoomDiscovery({required this.gameId});

  static const int discoveryPort = 40445;
  static const String _requestType = 'gameslocal_discover';
  static const String _responseType = 'gameslocal_room';

  final String gameId;
  RawDatagramSocket? _hostSocket;
  StreamSubscription<RawSocketEvent>? _hostSubscription;
  String _roomCode = '';
  int _gamePort = 40444;

  Future<void> startAdvertising({
    required String roomCode,
    required int gamePort,
  }) async {
    await stopAdvertising();
    _roomCode = roomCode;
    _gamePort = gamePort;
    final RawDatagramSocket socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
      reusePort: true,
    );
    socket.broadcastEnabled = true;
    _hostSocket = socket;
    _hostSubscription = socket.listen((RawSocketEvent event) {
      if (event != RawSocketEvent.read) return;
      Datagram? datagram;
      while ((datagram = socket.receive()) != null) {
        final Datagram packet = datagram!;
        try {
          final Object? decoded = jsonDecode(utf8.decode(packet.data));
          if (decoded is! Map) continue;
          if (decoded['type'] != _requestType) continue;
          if ((decoded['gameId'] ?? '').toString() != gameId) continue;
          final List<int> response = utf8.encode(jsonEncode(<String, dynamic>{
            'type': _responseType,
            'gameId': gameId,
            'roomCode': _roomCode,
            'port': _gamePort,
          }));
          socket.send(response, packet.address, packet.port);
        } catch (_) {}
      }
    });
  }

  Future<DiscoveredLanRoom?> discover({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final RawDatagramSocket socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
      reuseAddress: true,
    );
    socket.broadcastEnabled = true;
    final Completer<DiscoveredLanRoom?> completer =
        Completer<DiscoveredLanRoom?>();
    StreamSubscription<RawSocketEvent>? subscription;
    Timer? timer;

    Future<void> finish(DiscoveredLanRoom? room) async {
      if (completer.isCompleted) return;
      completer.complete(room);
      timer?.cancel();
      await subscription?.cancel();
      socket.close();
    }

    subscription = socket.listen((RawSocketEvent event) {
      if (event != RawSocketEvent.read) return;
      Datagram? datagram;
      while ((datagram = socket.receive()) != null) {
        final Datagram packet = datagram!;
        try {
          final Object? decoded = jsonDecode(utf8.decode(packet.data));
          if (decoded is! Map) continue;
          if (decoded['type'] != _responseType) continue;
          if ((decoded['gameId'] ?? '').toString() != gameId) continue;
          final int port = (decoded['port'] as num?)?.toInt() ?? 40444;
          finish(DiscoveredLanRoom(
            gameId: gameId,
            host: packet.address.address,
            port: port,
            roomCode: (decoded['roomCode'] ?? '').toString(),
          ));
          return;
        } catch (_) {}
      }
    });

    final List<int> request = utf8.encode(jsonEncode(<String, dynamic>{
      'type': _requestType,
      'gameId': gameId,
    }));
    socket.send(request, InternetAddress('255.255.255.255'), discoveryPort);
    timer = Timer(timeout, () => finish(null));
    return completer.future;
  }

  Future<void> stopAdvertising() async {
    await _hostSubscription?.cancel();
    _hostSubscription = null;
    _hostSocket?.close();
    _hostSocket = null;
  }

  Future<void> dispose() => stopAdvertising();
}
