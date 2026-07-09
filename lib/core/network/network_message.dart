enum NetworkMessageType {
  hello,
  roomCreated,
  playerJoined,
  playerReady,
  startGame,
  move,
  rematch,
  disconnect,
  error,
}

class NetworkMessage {
  const NetworkMessage({
    required this.type,
    required this.gameId,
    required this.senderId,
    this.payload = const <String, dynamic>{},
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final NetworkMessageType type;
  final String gameId;
  final String senderId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type.name,
      'gameId': gameId,
      'senderId': senderId,
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory NetworkMessage.fromJson(Map<String, dynamic> json) {
    return NetworkMessage(
      type: NetworkMessageType.values.firstWhere(
        (item) => item.name == json['type'],
        orElse: () => NetworkMessageType.error,
      ),
      gameId: (json['gameId'] ?? '').toString(),
      senderId: (json['senderId'] ?? '').toString(),
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? const <String, dynamic>{}),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}
