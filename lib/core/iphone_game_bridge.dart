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

  static const int _maxPlayers = 12;
  static const int _maxMessageCharacters = 32768;

  final String html;
  final int port;
  HttpServer? _server;
  bool _disposed = false;
  final Map<String, IphoneWebPlayer> _players = <String, IphoneWebPlayer>{};
  final Map<String, WebSocket> _sockets = <String, WebSocket>{};

  final StreamController<List<IphoneWebPlayer>> players =
      StreamController<List<IphoneWebPlayer>>.broadcast();
  final StreamController<IphoneWebEvent> events =
      StreamController<IphoneWebEvent>.broadcast();

  Future<String> start() async {
    if (_disposed) {
      throw StateError('IphoneGameBridge has already been disposed.');
    }

    await _server?.close(force: true);
    _server = null;

    try {
      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        port,
        shared: true,
      );
    } on SocketException {
      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        0,
        shared: true,
      );
    }

    _server!.listen(
      _handleRequest,
      onError: (_) {},
      cancelOnError: false,
    );

    final int actualPort = _server!.port;
    final List<NetworkInterface> interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final NetworkInterface interface in interfaces) {
      for (final InternetAddress address in interface.addresses) {
        if (!address.address.startsWith('169.254.') &&
            !address.address.startsWith('127.')) {
          return 'http://${address.address}:$actualPort';
        }
      }
    }
    return 'http://0.0.0.0:$actualPort';
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (_disposed) {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      await request.response.close();
      return;
    }

    if (request.uri.path == '/ws' &&
        WebSocketTransformer.isUpgradeRequest(request)) {
      try {
        _attachSocket(await WebSocketTransformer.upgrade(request));
      } catch (_) {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
      }
      return;
    }

    if (request.uri.path != '/' && request.uri.path != '/index.html') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    request.response.headers.contentType = ContentType.html;
    request.response.headers.set('Cache-Control', 'no-store');
    request.response.write(html);
    await request.response.close();
  }

  void _attachSocket(WebSocket socket) {
    String? playerId;
    socket.listen(
      (dynamic raw) {
        if (_disposed) return;
        final String rawText = raw.toString();
        if (rawText.length > _maxMessageCharacters) return;

        try {
          final Object? decoded = jsonDecode(rawText);
          if (decoded is! Map) return;
          final Map<String, dynamic> message = decoded.map<String, dynamic>(
            (dynamic key, dynamic value) =>
                MapEntry<String, dynamic>(key.toString(), value),
          );
          final String type = (message['type'] ?? '').toString();

          if (type == 'join') {
            if (playerId != null) {
              final IphoneWebPlayer? existing = _players[playerId];
              if (existing != null) {
                socket.add(jsonEncode(<String, dynamic>{
                  'type': 'joined',
                  'id': existing.id,
                  'name': existing.name,
                }));
              }
              return;
            }
            if (_players.length >= _maxPlayers) {
              socket.add(jsonEncode(<String, dynamic>{
                'type': 'error',
                'message': 'الغرفة ممتلئة',
              }));
              unawaited(socket.close(WebSocketStatus.policyViolation));
              return;
            }

            final String rawName = (message['name'] ?? '').toString().trim();
            final String name = rawName.isEmpty
                ? 'لاعب آيفون'
                : (rawName.length > 32 ? rawName.substring(0, 32) : rawName);
            playerId = 'web-${DateTime.now().microsecondsSinceEpoch}';
            final IphoneWebPlayer player = IphoneWebPlayer(
              id: playerId!,
              name: name,
            );
            _players[player.id] = player;
            _sockets[player.id] = socket;
            socket.add(jsonEncode(<String, dynamic>{
              'type': 'joined',
              'id': player.id,
              'name': player.name,
            }));
            _emitPlayers();
            return;
          }

          if (playerId != null && !_disposed && !events.isClosed) {
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
      cancelOnError: true,
    );
  }

  void _emitPlayers() {
    if (_disposed || players.isClosed) return;
    players.add(List<IphoneWebPlayer>.unmodifiable(_players.values));
  }

  void _remove(String? id) {
    if (id == null) return;
    _players.remove(id);
    _sockets.remove(id);
    _emitPlayers();
  }

  void broadcast(Map<String, dynamic> message) {
    if (_disposed) return;
    final String encoded = jsonEncode(message);
    for (final MapEntry<String, WebSocket> entry
        in List<MapEntry<String, WebSocket>>.from(_sockets.entries)) {
      try {
        entry.value.add(encoded);
      } catch (_) {
        _remove(entry.key);
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    final HttpServer? server = _server;
    _server = null;
    await server?.close(force: true);

    final List<WebSocket> sockets = List<WebSocket>.from(_sockets.values);
    _sockets.clear();
    _players.clear();
    for (final WebSocket socket in sockets) {
      try {
        await socket.close(WebSocketStatus.goingAway);
      } catch (_) {}
    }

    if (!players.isClosed) await players.close();
    if (!events.isClosed) await events.close();
  }
}
