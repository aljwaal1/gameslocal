import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

const int _maxFrameBytes = 65536;
const int _maxPlayersPerRoom = 12;
const Duration _roomLifetime = Duration(hours: 6);
const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

final Map<String, _Room> _rooms = <String, _Room>{};
final Random _random = Random.secure();

Future<void> main() async {
  final int port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final HttpServer server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  server.autoCompress = true;
  Timer.periodic(const Duration(minutes: 10), (_) => _removeExpiredRooms());
  await for (final HttpRequest request in server) {
    if (request.uri.path == '/health') {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(<String, dynamic>{
          'ok': true,
          'rooms': _rooms.length,
          'protocol': 1,
        }));
      await request.response.close();
      continue;
    }
    if (request.uri.path == '/ws' &&
        WebSocketTransformer.isUpgradeRequest(request)) {
      final WebSocket socket = await WebSocketTransformer.upgrade(request);
      socket.pingInterval = const Duration(seconds: 20);
      _attach(socket);
      continue;
    }
    request.response
      ..statusCode = HttpStatus.notFound
      ..write('Not found');
    await request.response.close();
  }
}

void _attach(WebSocket socket) {
  _Room? room;
  String playerId = '';
  int windowStarted = DateTime.now().millisecondsSinceEpoch;
  int windowFrames = 0;

  socket.listen(
    (dynamic frame) {
      if (frame is! String || utf8.encode(frame).length > _maxFrameBytes) {
        _error(socket, 'رسالة غير صالحة.');
        return;
      }
      final int now = DateTime.now().millisecondsSinceEpoch;
      if (now - windowStarted >= 1000) {
        windowStarted = now;
        windowFrames = 0;
      }
      windowFrames += 1;
      if (windowFrames > 60) {
        _error(socket, 'عدد الرسائل كبير جدًا.');
        unawaited(socket.close(WebSocketStatus.policyViolation));
        return;
      }

      Map<String, dynamic> envelope;
      try {
        final Object? decoded = jsonDecode(frame);
        if (decoded is! Map) throw const FormatException();
        envelope = Map<String, dynamic>.from(decoded);
      } catch (_) {
        _error(socket, 'رسالة غير صالحة.');
        return;
      }

      final String kind = (envelope['kind'] ?? '').toString();
      if (room == null) {
        final String gameId = _cleanGameId(envelope['gameId']);
        if (gameId.isEmpty || envelope['protocol'] != 1) {
          _error(socket, 'إصدار الاتصال أو اللعبة غير صالح.');
          return;
        }
        if (kind == 'create') {
          final String code = _newRoomCode();
          room = _Room(code: code, gameId: gameId, host: socket);
          _rooms[code] = room!;
          socket.add(jsonEncode(<String, dynamic>{
            'kind': 'ready',
            'roomCode': code,
            'role': 'host',
          }));
          return;
        }
        if (kind == 'join') {
          final String code = _cleanRoomCode(envelope['roomCode']);
          final _Room? found = _rooms[code];
          if (found == null || found.gameId != gameId) {
            _error(socket, 'الغرفة غير موجودة أو انتهت.');
            return;
          }
          if (found.sockets.length >= _maxPlayersPerRoom) {
            _error(socket, 'الغرفة ممتلئة.');
            return;
          }
          room = found..sockets.add(socket);
          found.touch();
          socket.add(jsonEncode(<String, dynamic>{
            'kind': 'ready',
            'roomCode': code,
            'role': 'guest',
          }));
          return;
        }
        _error(socket, 'يجب إنشاء غرفة أو الانضمام أولًا.');
        return;
      }

      if (kind != 'game') return;
      final Object? rawMessage = envelope['message'];
      if (rawMessage is! Map) return;
      final Map<String, dynamic> message = Map<String, dynamic>.from(rawMessage);
      if ((message['gameId'] ?? '').toString() != room!.gameId) return;
      final String sender = (message['senderId'] ?? '').toString();
      if (sender.isEmpty || sender.length > 80) return;
      if (playerId.isEmpty) {
        playerId = sender;
      } else if (playerId != sender) {
        _error(socket, 'هوية اللاعب غير صالحة.');
        return;
      }
      final String messageType = (message['type'] ?? '').toString();
      final Object? rawPayload = message['payload'];
      final Map<String, dynamic> payload = rawPayload is Map
          ? Map<String, dynamic>.from(rawPayload)
          : const <String, dynamic>{};
      if ((messageType == 'startGame' ||
              (messageType == 'hello' &&
                  payload['action'] == 'room_roster')) &&
          !identical(room!.host, socket)) {
        _error(socket, 'هذا الإجراء متاح للداعي فقط.');
        return;
      }
      room!.touch();
      final String outgoing = jsonEncode(<String, dynamic>{
        'kind': 'game',
        'message': message,
      });
      for (final WebSocket peer in List<WebSocket>.from(room!.sockets)) {
        if (!identical(peer, socket) && peer.readyState == WebSocket.open) {
          peer.add(outgoing);
        }
      }
    },
    onDone: () => _leave(room, socket, playerId),
    onError: (_) => _leave(room, socket, playerId),
    cancelOnError: true,
  );
}

void _leave(_Room? room, WebSocket socket, String playerId) {
  if (room == null || !room.sockets.remove(socket)) return;
  if (identical(room.host, socket)) {
    _rooms.remove(room.code);
    for (final WebSocket peer in room.sockets) {
      _error(peer, 'أغلق الداعي الغرفة.');
      unawaited(peer.close(WebSocketStatus.goingAway));
    }
    room.sockets.clear();
    return;
  }
  if (playerId.isNotEmpty) {
    final String outgoing = jsonEncode(<String, dynamic>{
      'kind': 'game',
      'message': <String, dynamic>{
        'type': 'disconnect',
        'gameId': room.gameId,
        'senderId': playerId,
        'payload': const <String, dynamic>{},
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      },
    });
    for (final WebSocket peer in room.sockets) {
      if (peer.readyState == WebSocket.open) peer.add(outgoing);
    }
  }
}

void _error(WebSocket socket, String message) {
  if (socket.readyState == WebSocket.open) {
    socket.add(jsonEncode(<String, dynamic>{
      'kind': 'error',
      'message': message,
    }));
  }
}

String _newRoomCode() {
  for (int attempt = 0; attempt < 100; attempt++) {
    final String code = List<String>.generate(
      6,
      (_) => _alphabet[_random.nextInt(_alphabet.length)],
    ).join();
    if (!_rooms.containsKey(code)) return code;
  }
  throw StateError('Unable to allocate room code');
}

String _cleanRoomCode(Object? value) => value
    .toString()
    .toUpperCase()
    .replaceAll(RegExp('[^A-Z0-9]'), '');

String _cleanGameId(Object? value) {
  if (value == null) return '';
  final String result = value.toString().replaceAll(RegExp('[^a-z0-9_]'), '');
  return result.length <= 48 ? result : '';
}

void _removeExpiredRooms() {
  final DateTime cutoff = DateTime.now().subtract(_roomLifetime);
  final List<_Room> expired = _rooms.values
      .where((_Room room) => room.updatedAt.isBefore(cutoff))
      .toList(growable: false);
  for (final _Room room in expired) {
    _rooms.remove(room.code);
    for (final WebSocket socket in room.sockets) {
      _error(socket, 'انتهت مدة الغرفة.');
      unawaited(socket.close(WebSocketStatus.goingAway));
    }
  }
}

class _Room {
  _Room({required this.code, required this.gameId, required this.host})
      : sockets = <WebSocket>{host};

  final String code;
  final String gameId;
  final WebSocket host;
  final Set<WebSocket> sockets;
  DateTime updatedAt = DateTime.now();

  void touch() => updatedAt = DateTime.now();
}
