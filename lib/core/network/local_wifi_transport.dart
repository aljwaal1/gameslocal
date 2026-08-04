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
  StreamSubscription<Socket>? _serverSubscription;
  Socket? _clientSocket;
  StreamSubscription<String>? _clientSubscription;
  final Map<Socket, StreamSubscription<String>> _hostClients =
      <Socket, StreamSubscription<String>>{};
  final Map<Socket, String> _socketPlayerIds = <Socket, String>{};
  bool _disposed = false;

  Stream<NetworkMessage> get messages => _messagesController.stream;
  Stream<String> get status => _statusController.stream;
  bool get isConnected => _clientSocket != null || _hostClients.isNotEmpty;
  bool get isHost => _server != null;
  int get connectedClients => _hostClients.length;

  Future<String> startHost({int port = defaultPort}) async {
    _ensureAlive();
    await close();
    _server = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      port,
      shared: true,
    );
    final String address = await _localAddress();
    _emitStatus('تم تشغيل Host على $address:$port');

    _serverSubscription = _server!.listen(
      (Socket client) {
        _attachHostClient(client);
        _emitStatus(
          'انضم جهاز من ${client.remoteAddress.address} — الاتصالات ${_hostClients.length}',
        );
      },
      onError: (Object error) {
        _emitStatus('خطأ في Host: $error');
      },
      cancelOnError: false,
    );

    return '$address:$port';
  }

  Future<void> connectToHost({
    required String host,
    int port = defaultPort,
  }) async {
    _ensureAlive();
    await close();
    _emitStatus('جاري الاتصال بـ $host:$port ...');
    final Socket socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 8),
    );
    socket.setOption(SocketOption.tcpNoDelay, true);
    _clientSocket = socket;
    _clientSubscription = _listenToSocket(socket, relayFromHostClient: false);
    _emitStatus('تم الاتصال بـ $host:$port');
  }

  void send(NetworkMessage message) {
    if (_disposed) return;
    final String line = jsonEncode(message.toJson());

    if (_server != null) {
      if (_hostClients.isEmpty) {
        _emitStatus('لا يوجد لاعب متصل حاليًا.');
        return;
      }
      for (final Socket socket in List<Socket>.from(_hostClients.keys)) {
        _write(socket, line);
      }
      return;
    }

    final Socket? socket = _clientSocket;
    if (socket == null) {
      _emitStatus('لا يوجد اتصال نشط لإرسال الرسالة.');
      return;
    }
    _write(socket, line);
  }

  void _attachHostClient(Socket socket) {
    socket.setOption(SocketOption.tcpNoDelay, true);
    _hostClients[socket] = _listenToSocket(socket, relayFromHostClient: true);
  }

  StreamSubscription<String> _listenToSocket(
    Socket socket, {
    required bool relayFromHostClient,
  }) {
    return socket
        .map<List<int>>((List<int> data) => data)
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (String line) {
            final NetworkMessage? message = _decodeLine(line);
            if (message == null) return;

            if (relayFromHostClient && message.senderId.isNotEmpty) {
              _socketPlayerIds[socket] = message.senderId;
            }
            _emitMessage(message);

            if (relayFromHostClient) {
              for (final Socket other in List<Socket>.from(_hostClients.keys)) {
                if (other != socket) _write(other, line);
              }
            }
          },
          onDone: () => _removeSocket(socket),
          onError: (Object error) {
            _emitStatus('خطأ في الاتصال: $error');
            _removeSocket(socket);
          },
          cancelOnError: true,
        );
  }

  NetworkMessage? _decodeLine(String line) {
    try {
      final Object? decoded = jsonDecode(line);
      if (decoded is Map<String, dynamic>) {
        return NetworkMessage.fromJson(decoded);
      }
      _emitStatus('وصلت رسالة غير صالحة.');
    } catch (_) {
      _emitStatus('وصلت رسالة غير صالحة.');
    }
    return null;
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
      socket.destroy();
      _emitStatus('تم قطع الاتصال بالمضيف.');
      _emitMessage(NetworkMessage(
        type: NetworkMessageType.disconnect,
        gameId: gameId,
        senderId: 'host-connection',
      ));
      return;
    }

    final String? playerId = _socketPlayerIds.remove(socket);
    final StreamSubscription<String>? subscription =
        _hostClients.remove(socket);
    subscription?.cancel();
    socket.destroy();
    _emitStatus('غادر جهاز — المتصلون الآن ${_hostClients.length}');

    if (playerId != null && playerId.isNotEmpty) {
      final NetworkMessage disconnect = NetworkMessage(
        type: NetworkMessageType.disconnect,
        gameId: gameId,
        senderId: playerId,
      );
      _emitMessage(disconnect);
      final String encoded = jsonEncode(disconnect.toJson());
      for (final Socket other in List<Socket>.from(_hostClients.keys)) {
        _write(other, encoded);
      }
    }
  }

  void _emitMessage(NetworkMessage message) {
    if (!_disposed && !_messagesController.isClosed) {
      _messagesController.add(message);
    }
  }

  void _emitStatus(String message) {
    if (!_disposed && !_statusController.isClosed) {
      _statusController.add(message);
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
          if (!address.address.startsWith('127.') &&
              !address.address.startsWith('169.254.')) {
            return address.address;
          }
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
    _socketPlayerIds.clear();

    await _serverSubscription?.cancel();
    _serverSubscription = null;
    await _server?.close();
    _server = null;
  }

  void _ensureAlive() {
    if (_disposed) throw StateError('LocalWifiTransport is disposed.');
  }

  Future<void> dispose() async {
    if (_disposed) return;
    await close();
    _disposed = true;
    if (!_messagesController.isClosed) await _messagesController.close();
    if (!_statusController.isClosed) await _statusController.close();
  }
}
