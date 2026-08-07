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
      final StreamSubscription<String>? subscription = _clientSubscription;
      _clientSubscription = null;
      _clientSocket = null;
      if (subscription != null) {
        unawaited(subscription.cancel());
      }
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
    final StreamSubscription<String>? subscription = _hostClients.remove(socket);
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
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
      final List<_AddressCandidate> candidates = <_AddressCandidate>[];

      for (final NetworkInterface interface in interfaces) {
        for (final InternetAddress address in interface.addresses) {
          final String value = address.address;
          if (value.startsWith('127.') || value.startsWith('169.254.')) {
            continue;
          }
          candidates.add(
            _AddressCandidate(
              address: value,
              score: _scoreAddress(interface.name, value),
            ),
          );
        }
      }

      if (candidates.isNotEmpty) {
        candidates.sort(
          (_AddressCandidate a, _AddressCandidate b) => b.score.compareTo(a.score),
        );
        return candidates.first.address;
      }
    } catch (_) {}
    return '0.0.0.0';
  }

  int _scoreAddress(String interfaceName, String address) {
    final String name = interfaceName.toLowerCase();
    int score = 0;

    if (name.contains('wlan') || name.contains('wifi') || name.startsWith('wl')) {
      score += 100;
    } else if (name.contains('hotspot') || name.contains('ap')) {
      score += 90;
    } else if (name.startsWith('eth') || name.startsWith('en')) {
      score += 60;
    }

    if (name.contains('tun') ||
        name.contains('tap') ||
        name.contains('vpn') ||
        name.contains('ppp')) {
      score -= 120;
    }

    if (address.startsWith('192.168.')) {
      score += 60;
    } else if (address.startsWith('10.')) {
      score += 50;
    } else if (_isPrivate172(address)) {
      score += 45;
    }

    return score;
  }

  bool _isPrivate172(String address) {
    if (!address.startsWith('172.')) return false;
    final List<String> parts = address.split('.');
    if (parts.length < 2) return false;
    final int? second = int.tryParse(parts[1]);
    return second != null && second >= 16 && second <= 31;
  }

  Future<void> close() async {
    final StreamSubscription<String>? clientSubscription = _clientSubscription;
    final Socket? clientSocket = _clientSocket;
    _clientSubscription = null;
    _clientSocket = null;

    if (clientSubscription != null) {
      await clientSubscription.cancel();
    }
    clientSocket?.destroy();

    final List<StreamSubscription<String>> hostSubscriptions =
        List<StreamSubscription<String>>.from(_hostClients.values);
    final List<Socket> hostSockets = List<Socket>.from(_hostClients.keys);
    _hostClients.clear();
    _socketPlayerIds.clear();

    for (final StreamSubscription<String> subscription in hostSubscriptions) {
      await subscription.cancel();
    }
    for (final Socket socket in hostSockets) {
      socket.destroy();
    }

    final StreamSubscription<Socket>? serverSubscription = _serverSubscription;
    final ServerSocket? server = _server;
    _serverSubscription = null;
    _server = null;

    if (serverSubscription != null) {
      await serverSubscription.cancel();
    }
    await server?.close();
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

class _AddressCandidate {
  const _AddressCandidate({required this.address, required this.score});

  final String address;
  final int score;
}
