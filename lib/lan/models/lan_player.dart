class LanPlayer {
  const LanPlayer({
    required this.id,
    required this.name,
    required this.role,
    this.connected = true,
  });

  final String id;
  final String name;
  final LanPlayerRole role;
  final bool connected;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role.name,
        'connected': connected,
      };

  factory LanPlayer.fromJson(Map<String, dynamic> json) {
    return LanPlayer(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? 'Player'}',
      role: LanPlayerRole.values.firstWhere(
        (role) => role.name == json['role'],
        orElse: () => LanPlayerRole.player,
      ),
      connected: json['connected'] != false,
    );
  }
}

enum LanPlayerRole { host, player, spectator }
