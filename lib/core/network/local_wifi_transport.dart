import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'network_message.dart';

class LocalWifiTransport {
  LocalWifiTransport({required this.gameId});

  static const int defaultPort = 40444;

  final String gameId;
  final StreamController<NetworkMessage> _messagesController = StreamController<NetworkMessage>.broadcast();
  final StreamController<String> _statusController = StreamController<String>.broadcast();

  ServerSocket? _server;
  Socket? _socket;
  StreamSubscription<String>? _socketSubscription;

  Stream<NetworkMessage> get messages => _messagesController.stream;
  Stream<String> get status => _statusController.stream;
  bool get isConnected => _socket != null;

  Future<String> startHost({int port = defaultPort}) async {
    await close();
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, port, shared: true);
    final String address = await _localAddress();
    _statusController.add('تم تشغيل Host على $address:$port');

    _server!.listen((Socket client) {
      _attachSocket(client);
      _statusController.add('انضم لاعب من ${client.remoteAddress.address}');
    }, onError: (Object error) {
      _statusController.add('خطأ في Host: $error');
    });

    return '$address:$port';
  }

  Future<void> connectToHost({required String host, int port = defaultPort}) async {
    await close();
    _statusController.add('جاري الاتصال بـ $host:$port ...');
    final Socket socket = await Socket.connect(host, port, timeout: const Duration(seconds: 8));
    _attachSocket(socket);
    _statusController.add('تم الاتصال بـ $host:$port');
  }

  void send(NetworkMessage message) {
    final Socket? socket = _socket;
    if (socket == null) {
      _statusController.add('لا يوجد اتصال نشط لإرسال الرسالة.');
      return;
    }

    socket.writeln(jsonEncode(message.toJson()));
  }

  void _attachSocket(Socket socket) {
    _socketSubscription?.cancel();
    _socket = socket;
    _socketSubscription = socket
        .map<List<int>>((data) => data)
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleLine, onDone: () {
      _statusController.add('تم قطع اتصال اللاعب الآخر.');
      _socket = null;
    }, onError: (Object error) {
      _statusController.add('خطأ في الاتصال: $error');
      _socket = null;
    });
  }

  void _handleLine(String line) {
    try {
      final Object? decoded = jsonDecode(line);
      if (decoded is Map<String, dynamic>) {
        _messagesController.add(NetworkMessage.fromJson(decoded));
      }
    } catch (_) {
      _statusController.add('وصلت رسالة غير صالحة.');
    }
  }

  Future<String> _localAddress() async {
    try {
      final List<NetworkInterface> interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (final NetworkInterface interface in interfaces) {
        for (final InternetAddress address in interface.addresses) {
          final String value = address.address;
          if (!value.startsWith('127.')) {
            return value;
          }
        }
      }
    } catch (_) {
      // بعض أجهزة أندرويد قد تمنع قراءة تفاصيل الشبكة، ويبقى إدخال IP يدويًا متاحًا.
    }

    return '0.0.0.0';
  }

  Future<void> close() async {
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket?.destroy();
    _socket = null;
    await _server?.close();
    _server = null;
  }

  Future<void> dispose() async {
    await close();
    await _messagesController.close();
    await _statusController.close();
  }
}
