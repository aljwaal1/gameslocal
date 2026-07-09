import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../models/lan_message.dart';
import '../models/lan_player.dart';
import '../models/lan_room.dart';
import 'message_protocol.dart';

class LanHostService {
  LanHostService({this.port = 45454});

  final int port;
  ServerSocket? _server;
  final List<Socket> _clients = [];
  final StreamController<LanMessage> _messages = StreamController<LanMessage>.broadcast();

  LanRoom? room;

  Stream<LanMessage> get messages => _messages.stream;
  bool get isRunning => _server != null;

  Future<LanRoom> startHost({
    required String gameId,
    required String hostName,
    int maxPlayers = 2,
  }) async {
    final code = _makeCode();
    room = LanRoom(
      id: 'room-$code',
      code: code,
      gameId: gameId,
      hostName: hostName,
      port: port,
      players: [LanPlayer(id: 'host', name: hostName, role: LanPlayerRole.host)],
    );

    _server = await ServerSocket.bind(InternetAddress.anyIPv4, port, shared: true);
    _server!.listen(_handleClient, onError: (_) {});
    return room!;
  }

  void _handleClient(Socket socket) {
    _clients.add(socket);
    socket.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen(
      (line) {
        final message = LanMessageProtocol.decode(line);
        if (message != null) {
          _messages.add(message);
          broadcast(message);
        }
      },
      onDone: () => _clients.remove(socket),
      onError: (_) => _clients.remove(socket),
      cancelOnError: true,
    );
  }

  void broadcast(LanMessage message) {
    final raw = LanMessageProtocol.encode(message);
    for (final client in List<Socket>.from(_clients)) {
      try {
        client.write(raw);
      } catch (_) {
        _clients.remove(client);
      }
    }
  }

  Future<void> stop() async {
    for (final client in _clients) {
      client.destroy();
    }
    _clients.clear();
    await _server?.close();
    _server = null;
    room = null;
  }

  String _makeCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
