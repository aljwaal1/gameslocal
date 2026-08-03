import 'dart:async';
import 'dart:convert';
import 'dart:io';

class DiscoveredRoom {
  const DiscoveredRoom({
    required this.gameId,
    required this.host,
    required this.port,
    required this.roomCode,
    required this.name,
  });

  final String gameId;
  final String host;
  final int port;
  final String roomCode;
  final String name;
}

class LocalRoomDiscovery {
  static const int discoveryPort = 40443;
  static const String _probe = 'GAMESLOCAL_DISCOVER_V1';

  RawDatagramSocket? _hostSocket;
  StreamSubscription<RawSocketEvent>? _hostSubscription;

  Future<void> startAdvertising({
    required String gameId,
    required String host,
    required int port,
    required String roomCode,
    String name = 'غرفة ألعاب محلية',
  }) async {
    await stopAdvertising();
    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
      reusePort: true,
    );
    _hostSocket = socket;
    _hostSubscription = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null) return;
      final text = utf8.decode(datagram.data, allowMalformed: true);
      if (text != _probe) return;
      final payload = jsonEncode(<String, dynamic>{
        'type': 'GAMESLOCAL_ROOM_V1',
        'gameId': gameId,
        'host': host,
        'port': port,
        'roomCode': roomCode,
        'name': name,
      });
      socket.send(utf8.encode(payload), datagram.address, datagram.port);
    });
  }

  Future<List<DiscoveredRoom>> discover({
    required String gameId,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
      reuseAddress: true,
    );
    socket.broadcastEnabled = true;
    final rooms = <String, DiscoveredRoom>{};
    final completer = Completer<List<DiscoveredRoom>>();

    late final StreamSubscription<RawSocketEvent> subscription;
    subscription = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null) return;
      try {
        final decoded = jsonDecode(utf8.decode(datagram.data));
        if (decoded is! Map || decoded['type'] != 'GAMESLOCAL_ROOM_V1') return;
        if ((decoded['gameId'] ?? '').toString() != gameId) return;
        final host = (decoded['host'] ?? datagram.address.address).toString();
        final port = (decoded['port'] as num?)?.toInt() ?? 40444;
        final room = DiscoveredRoom(
          gameId: gameId,
          host: host,
          port: port,
          roomCode: (decoded['roomCode'] ?? '').toString(),
          name: (decoded['name'] ?? 'غرفة متاحة').toString(),
        );
        rooms['$host:$port'] = room;
      } catch (_) {}
    });

    socket.send(
      utf8.encode(_probe),
      InternetAddress('255.255.255.255'),
      discoveryPort,
    );

    Timer(timeout, () async {
      await subscription.cancel();
      socket.close();
      if (!completer.isCompleted) completer.complete(rooms.values.toList());
    });
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
