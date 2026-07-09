class LanMessage {
  const LanMessage({
    required this.type,
    required this.senderId,
    required this.roomCode,
    this.gameId = '',
    this.payload = const {},
    this.timestamp = 0,
  });

  final LanMessageType type;
  final String senderId;
  final String roomCode;
  final String gameId;
  final Map<String, dynamic> payload;
  final int timestamp;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'senderId': senderId,
        'roomCode': roomCode,
        'gameId': gameId,
        'payload': payload,
        'timestamp': timestamp == 0 ? DateTime.now().millisecondsSinceEpoch : timestamp,
      };

  factory LanMessage.fromJson(Map<String, dynamic> json) {
    return LanMessage(
      type: LanMessageType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => LanMessageType.unknown,
      ),
      senderId: '${json['senderId'] ?? ''}',
      roomCode: '${json['roomCode'] ?? ''}',
      gameId: '${json['gameId'] ?? ''}',
      payload: json['payload'] is Map ? Map<String, dynamic>.from(json['payload'] as Map) : const {},
      timestamp: int.tryParse('${json['timestamp'] ?? 0}') ?? 0,
    );
  }
}

enum LanMessageType {
  unknown,
  roomAnnouncement,
  joinRequest,
  joinAccepted,
  joinRejected,
  playerList,
  startGame,
  gameMove,
  gameState,
  spectatorJoin,
  leave,
  heartbeat,
}
