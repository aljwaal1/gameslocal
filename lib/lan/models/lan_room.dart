import 'lan_player.dart';

class LanRoom {
  const LanRoom({
    required this.id,
    required this.code,
    required this.gameId,
    required this.hostName,
    required this.port,
    required this.players,
    this.status = LanRoomStatus.waiting,
  });

  final String id;
  final String code;
  final String gameId;
  final String hostName;
  final int port;
  final List<LanPlayer> players;
  final LanRoomStatus status;

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'gameId': gameId,
        'hostName': hostName,
        'port': port,
        'players': players.map((player) => player.toJson()).toList(),
        'status': status.name,
      };

  factory LanRoom.fromJson(Map<String, dynamic> json) {
    final rawPlayers = json['players'];
    return LanRoom(
      id: '${json['id'] ?? ''}',
      code: '${json['code'] ?? ''}',
      gameId: '${json['gameId'] ?? ''}',
      hostName: '${json['hostName'] ?? ''}',
      port: int.tryParse('${json['port'] ?? 0}') ?? 0,
      players: rawPlayers is List
          ? rawPlayers.whereType<Map>().map((item) => LanPlayer.fromJson(Map<String, dynamic>.from(item))).toList()
          : const [],
      status: LanRoomStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => LanRoomStatus.waiting,
      ),
    );
  }
}

enum LanRoomStatus { waiting, playing, finished }
