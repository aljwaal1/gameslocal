import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/lan_message.dart';
import 'message_protocol.dart';

class LanClientService {
  Socket? _socket;
  final StreamController<LanMessage> _messages = StreamController<LanMessage>.broadcast();

  Stream<LanMessage> get messages => _messages.stream;
  bool get isConnected => _socket != null;

  Future<void> connect({required String host, required int port}) async {
    _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
    _socket!
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          final message = LanMessageProtocol.decode(line);
          if (message != null) _messages.add(message);
        }, onDone: disconnect, onError: (_) => disconnect(), cancelOnError: true);
  }

  void send(LanMessage message) {
    _socket?.write(LanMessageProtocol.encode(message));
  }

  void disconnect() {
    _socket?.destroy();
    _socket = null;
  }
}
