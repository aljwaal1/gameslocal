import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/lan_room.dart';

class LanDiscoveryService {
  LanDiscoveryService({this.discoveryPort = 45455});

  final int discoveryPort;
  RawDatagramSocket? _socket;
  Timer? _timer;
  final StreamController<LanRoom> _rooms = StreamController<LanRoom>.broadcast();

  Stream<LanRoom> get rooms => _rooms.stream;

  Future<void> startAdvertising(LanRoom room) async {
    _socket ??= await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _socket!.broadcastEnabled = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      final data = utf8.encode(jsonEncode(room.toJson()));
      _socket?.send(data, InternetAddress('255.255.255.255'), discoveryPort);
    });
  }

  Future<void> startListening() async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, discoveryPort, reuseAddress: true, reusePort: true);
    _socket!.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = _socket!.receive();
      if (datagram == null) return;
      try {
        final text = utf8.decode(datagram.data);
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          _rooms.add(LanRoom.fromJson(Map<String, dynamic>.from(decoded)));
        }
      } catch (_) {}
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _socket?.close();
    _socket = null;
  }
}
