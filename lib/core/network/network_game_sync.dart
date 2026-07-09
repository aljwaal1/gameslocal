/// طبقة مساعدة صغيرة فوق Network Core لتوحيد شكل حركات الألعاب.
///
/// الهدف منها أن ترسل كل لعبة حركة موحدة تحتوي على:
/// - رقم تسلسلي للحركة.
/// - اسم اللاعب الذي أرسلها.
/// - بيانات الحركة الخاصة باللعبة نفسها.
///
/// هذه الطبقة لا تستبدل LocalNetworkCore، بل تجعل ربط الألعاب القادمة
/// مثل الدومينو وإكس أو أسهل لأن الرسائل سيكون لها نفس الشكل.
class NetworkGameMove {
  const NetworkGameMove({
    required this.sequence,
    required this.playerId,
    required this.action,
    this.payload = const <String, dynamic>{},
  });

  final int sequence;
  final String playerId;
  final String action;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sequence': sequence,
      'playerId': playerId,
      'action': action,
      'payload': payload,
    };
  }

  factory NetworkGameMove.fromJson(Map<String, dynamic> json) {
    return NetworkGameMove(
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      playerId: (json['playerId'] ?? '').toString(),
      action: (json['action'] ?? '').toString(),
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? const <String, dynamic>{}),
    );
  }
}

class NetworkGameSync {
  NetworkGameSync();

  int _lastSequence = 0;

  int get lastSequence => _lastSequence;

  NetworkGameMove buildMove({
    required String playerId,
    required String action,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) {
    _lastSequence += 1;
    return NetworkGameMove(
      sequence: _lastSequence,
      playerId: playerId,
      action: action,
      payload: payload,
    );
  }

  /// يقبل الحركة القادمة إذا كانت أحدث من آخر حركة معروفة.
  /// هذا يمنع تكرار نفس الحركة عند إعادة إرسال الرسائل لاحقًا.
  bool acceptIncoming(NetworkGameMove move) {
    if (move.sequence <= _lastSequence) return false;
    _lastSequence = move.sequence;
    return true;
  }

  void reset() {
    _lastSequence = 0;
  }
}
