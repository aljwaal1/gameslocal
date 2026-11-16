import 'dart:async';

import 'network_message.dart';

abstract interface class NetworkTransport {
  Stream<NetworkMessage> get messages;
  Stream<String> get status;

  void send(NetworkMessage message);
  Future<void> close();
  Future<void> dispose();
}
