import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'network_message.dart';
import 'network_transport.dart';

class InternetRelayTransport implements NetworkTransport {
  InternetRelayTransport({required this.gameId});

  static const String relayUrl = String.fromEnvironment(
    'INTERNET_RELAY_URL',
    defaultValue: '',
  );

  static bool get isConfigured => relayUrl.trim().isNotEmpty;

  final String gameId;
  final StreamController<NetworkMessage> _messagesController =
      StreamController<NetworkMessage>.broadcast();
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Completer<String>? _handshake;
  bool _disposed = false;

  @override
  Stream<NetworkMessage> get messages => _messagesController.stream;

  @override
  Stream<String> get status => _statusController.stream;

  Future<String> createRoom() => _connect(action: 'create');

  Future<String> joinRoom(String roomCode) => _connect(
        action: 'join',
        roomCode: _cleanRoomCode(roomCode),
      );

  Future<String> _connect({
    required String action,
    String roomCode = '',
  }) async {
    if (!isConfigured) {
      throw StateError('INTERNET_RELAY_URL is not configured');
    }
    await close();
    _emitStatus('جاري الاتصال بخادم الإنترنت...');
    final WebSocket socket = await _openSocketWithRetry();
    socket.pingInterval = const Duration(seconds: 20);
    _socket = socket;
    _handshake = Completer<String>();
    _subscription = socket.listen(
      _handleFrame,
      onDone: _handleClosed,
      onError: (Object error) {
        if (!(_handshake?.isCompleted ?? true)) {
          _handshake!.completeError(error);
        }
        _emitStatus('انقطع الاتصال بخادم الإنترنت.');
      },
      cancelOnError: true,
    );
    socket.add(jsonEncode(<String, dynamic>{
      'kind': action,
      'gameId': gameId,
      if (roomCode.isNotEmpty) 'roomCode': roomCode,
      'protocol': 1,
    }));
    return _handshake!.future.timeout(const Duration(seconds: 12));
  }

  Future<WebSocket> _openSocketWithRetry() async {
    final Stopwatch elapsed = Stopwatch()..start();
    Object? lastError;
    while (elapsed.elapsed < const Duration(seconds: 75)) {
      try {
        return await WebSocket.connect(relayUrl).timeout(
          const Duration(seconds: 12),
        );
      } catch (error) {
        lastError = error;
        _emitStatus('الخادم يستيقظ الآن، سنعيد المحاولة تلقائيًا...');
        await Future<void>.delayed(const Duration(seconds: 3));
      }
    }
    throw lastError ?? StateError('Internet relay unavailable');
  }

  void _handleFrame(dynamic frame) {
    if (frame is! String || frame.length > 65536) return;
    try {
      final Object? decoded = jsonDecode(frame);
      if (decoded is! Map) return;
      final Map<String, dynamic> envelope =
          Map<String, dynamic>.from(decoded);
      switch ((envelope['kind'] ?? '').toString()) {
        case 'ready':
          final String roomCode = _cleanRoomCode(
            (envelope['roomCode'] ?? '').toString(),
          );
          if (roomCode.isEmpty) {
            throw const FormatException('missing room code');
          }
          if (!(_handshake?.isCompleted ?? true)) {
            _handshake!.complete(roomCode);
          }
          _emitStatus('تم الاتصال بغرفة الإنترنت $roomCode');
          return;
        case 'game':
          final Object? rawMessage = envelope['message'];
          if (rawMessage is Map) {
            _messagesController.add(NetworkMessage.fromJson(
              Map<String, dynamic>.from(rawMessage),
            ));
          }
          return;
        case 'error':
          final String message =
              (envelope['message'] ?? 'تعذر الاتصال بالغرفة.').toString();
          final bool duringHandshake = !(_handshake?.isCompleted ?? true);
          if (duringHandshake) {
            _handshake!.completeError(StateError(message));
          }
          _emitStatus(message);
          if (duringHandshake) unawaited(close());
          return;
      }
    } catch (_) {
      _emitStatus('وصل رد غير صالح من خادم الإنترنت.');
    }
  }

  @override
  void send(NetworkMessage message) {
    final WebSocket? socket = _socket;
    if (_disposed || socket == null || socket.readyState != WebSocket.open) {
      _emitStatus('لا يوجد اتصال إنترنت نشط لإرسال الحركة.');
      return;
    }
    socket.add(jsonEncode(<String, dynamic>{
      'kind': 'game',
      'message': message.toJson(),
    }));
  }

  void _handleClosed() {
    if (!(_handshake?.isCompleted ?? true)) {
      _handshake!.completeError(StateError('connection closed'));
    }
    _socket = null;
    _emitStatus('انقطع الاتصال بغرفة الإنترنت.');
    if (!_disposed && !_messagesController.isClosed) {
      _messagesController.add(NetworkMessage(
        type: NetworkMessageType.disconnect,
        gameId: gameId,
        senderId: 'internet-relay',
      ));
    }
  }

  String _cleanRoomCode(String value) =>
      value.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

  void _emitStatus(String message) {
    if (!_disposed && !_statusController.isClosed) {
      _statusController.add(message);
    }
  }

  @override
  Future<void> close() async {
    final StreamSubscription<dynamic>? subscription = _subscription;
    final WebSocket? socket = _socket;
    _subscription = null;
    _socket = null;
    await subscription?.cancel();
    await socket?.close(WebSocketStatus.normalClosure);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await close();
    _disposed = true;
    if (!_messagesController.isClosed) await _messagesController.close();
    if (!_statusController.isClosed) await _statusController.close();
  }
}
