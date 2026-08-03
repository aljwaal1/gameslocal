import 'dart:async';
import 'dart:convert';
import 'dart:io';

class IphoneWebPlayer {
  const IphoneWebPlayer({required this.id, required this.name});

  final String id;
  final String name;
}

class IphoneWebEvent {
  const IphoneWebEvent({
    required this.playerId,
    required this.type,
    required this.data,
  });

  final String playerId;
  final String type;
  final Map<String, dynamic> data;
}

class IphoneGameBridge {
  IphoneGameBridge({
    required this.html,
    this.port = 40448,
  });

  final String html;
  final int port;
  HttpServer? _server;
  final Map<String, IphoneWebPlayer> _players = <String, IphoneWebPlayer>{};
  final Map<String, WebSocket> _sockets = <String, WebSocket>{};

  final StreamController<List<IphoneWebPlayer>> players =
      StreamController<List<IphoneWebPlayer>>.broadcast();
  final StreamController<IphoneWebEvent> events =
      StreamController<IphoneWebEvent>.broadcast();

  Future<String> start() async {
    await _server?.close(force: true);
    _server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      port,
      shared: true,
    );
    _server!.listen(_handleRequest);

    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.address.startsWith('169.254.')) {
          return 'http://${address.address}:$port';
        }
      }
    }
    return 'http://0.0.0.0:$port';
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.uri.path == '/ws' &&
        WebSocketTransformer.isUpgradeRequest(request)) {
      _attachSocket(await WebSocketTransformer.upgrade(request));
      return;
    }
    request.response.headers.contentType = ContentType.html;
    request.response.write(html);
    await request.response.close();
  }

  void _attachSocket(WebSocket socket) {
    String? playerId;
    socket.listen(
      (dynamic raw) {
        try {
          final decoded = jsonDecode(raw.toString());
          if (decoded is! Map) return;
          final message = decoded.map<String, dynamic>(
            (dynamic key, dynamic value) =>
                MapEntry<String, dynamic>(key.toString(), value),
          );
          final type = (message['type'] ?? '').toString();
          if (type == 'join') {
            final name = (message['name'] ?? '').toString().trim();
            playerId = 'web-${DateTime.now().microsecondsSinceEpoch}';
            final player = IphoneWebPlayer(
              id: playerId!,
              name: name.isEmpty ? 'لاعب آيفون' : name,
            );
            _players[player.id] = player;
            _sockets[player.id] = socket;
            socket.add(jsonEncode(<String, dynamic>{
              'type': 'joined',
              'id': player.id,
              'name': player.name,
            }));
            players.add(List<IphoneWebPlayer>.unmodifiable(_players.values));
            return;
          }
          if (playerId != null) {
            events.add(IphoneWebEvent(
              playerId: playerId!,
              type: type,
              data: message,
            ));
          }
        } catch (_) {}
      },
      onDone: () => _remove(playerId),
      onError: (_) => _remove(playerId),
    );
  }

  void _remove(String? id) {
    if (id == null) return;
    _players.remove(id);
    _sockets.remove(id);
    players.add(List<IphoneWebPlayer>.unmodifiable(_players.values));
  }

  void broadcast(Map<String, dynamic> message) {
    final encoded = jsonEncode(message);
    for (final socket in List<WebSocket>.from(_sockets.values)) {
      try {
        socket.add(encoded);
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    for (final socket in List<WebSocket>.from(_sockets.values)) {
      await socket.close();
    }
    _sockets.clear();
    _players.clear();
    await _server?.close(force: true);
    _server = null;
    await players.close();
    await events.close();
  }
}
