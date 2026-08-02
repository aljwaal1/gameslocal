import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'network_message.dart';

class LocalWifiTransport {
  LocalWifiTransport({required this.gameId});

  static const int defaultPort = 40444;

  final String gameId;
  final StreamController<NetworkMessage> _messagesController =
      StreamController<NetworkMessage>.broadcast();
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  ServerSocket? _server;
  Socket? _clientSocket;
  StreamSubscription<String>? _clientSubscription;
  final Map<Socket, StreamSubscription<String>> _hostClients =
      <Socket, StreamSubscription<String>>{};

  Stream<NetworkMessage> get messages => _messagesController.stream;
  Stream<String> get status => _statusController.stream;
  bool get isConnected => _clientSocket != null || _hostClients.isNotEmpty;
  bool get isHost => _server != null;
  int get connectedClients => _hostClients.length;

  Future<String> startHost({int port = defaultPort}) async {
    await close();
    _server = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      port,
      shared: true,
    );
    final String address = await _localAddress();
    _statusController.add('تم تشغيل Host على $address:$port');

    _server!.listen((Socket client) {
      _attachHostClient(client);
      _statusController.add(
        'انضم لاعب من ${client.remoteAddress.address} — العدد ${_hostClients.length}',
      );
    }, onError: (Object error) {
      _statusController.add('خطأ في Host: $error');
    });

    return '$address:$port';
  }

  Future<void> connectToHost({
    required String host,
    int port = defaultPort,
  }) async {
    await close();
    _statusController.add('جاري الاتصال بـ $host:$port ...');
    final Socket socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 8),
    );
    _clientSocket = socket;
    _clientSubscription = _listenToSocket(socket, relayFromHostClient: false);
    _statusController.add('تم الاتصال بـ $host:$port');
  }

  void send(NetworkMessage message) {
    final String line = jsonEncode(message.toJson());

    if (_server != null) {
      if (_hostClients.isEmpty) {
        _statusController.add('لا يوجد لاعب متصل حاليًا.');
        return;
      }
      for (final Socket socket in List<Socket>.from(_hostClients.keys)) {
        _write(socket, line);
      }
      return;
    }

    final Socket? socket = _clientSocket;
    if (socket == null) {
      _statusController.add('لا يوجد اتصال نشط لإرسال الرسالة.');
      return;
    }
    _write(socket, line);
  }

  void _attachHostClient(Socket socket) {
    _hostClients[socket] = _listenToSocket(socket, relayFromHostClient: true);
  }

  StreamSubscription<String> _listenToSocket(
    Socket socket, {
    required bool relayFromHostClient,
  }) {
    return socket
        .map<List<int>>((data) => data)
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((String line) {
      _handleLine(line);
      if (relayFromHostClient) {
        for (final Socket other in List<Socket>.from(_hostClients.keys)) {
          if (other != socket) _write(other, line);
        }
      }
    }, onDone: () {
      _removeSocket(socket);
    }, onError: (Object error) {
      _statusController.add('خطأ في الاتصال: $error');
      _removeSocket(socket);
    });
  }

  void _write(Socket socket, String line) {
    try {
      socket.writeln(line);
    } catch (_) {
      _removeSocket(socket);
    }
  }

  void _removeSocket(Socket socket) {
    if (identical(socket, _clientSocket)) {
      _clientSubscription?.cancel();
      _clientSubscription = null;
      _clientSocket = null;
      _statusController.add('تم قطع الاتصال بالمضيف.');
      return;
    }

    final StreamSubscription<String>? subscription =
        _hostClients.remove(socket);
    subscription?.cancel();
    socket.destroy();
    _statusController.add('غادر لاعب — المتصلون الآن ${_hostClients.length}');
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
          if (!address.address.startsWith('127.')) return address.address;
        }
      }
    } catch (_) {}
    return '0.0.0.0';
  }

  Future<void> close() async {
    await _clientSubscription?.cancel();
    _clientSubscription = null;
    _clientSocket?.destroy();
    _clientSocket = null;

    for (final StreamSubscription<String> subscription
        in List<StreamSubscription<String>>.from(_hostClients.values)) {
      await subscription.cancel();
    }
    for (final Socket socket in List<Socket>.from(_hostClients.keys)) {
      socket.destroy();
    }
    _hostClients.clear();

    await _server?.close();
    _server = null;
  }

  Future<void> dispose() async {
    await close();
    await _messagesController.close();
    await _statusController.close();
  }
}
