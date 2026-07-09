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

  /// مفتاح ثابت للحركة، يستخدم لمنع تطبيق نفس الحركة مرتين.
  ///
  /// وجود playerId داخل المفتاح مهم لأن كل لاعب قد يبدأ التسلسل من 1.
  String get uniqueKey => '$playerId:$sequence:$action';

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

  int _outgoingSequence = 0;
  final Set<String> _acceptedMoveKeys = <String>{};

  /// آخر رقم تسلسلي تم إنشاؤه محليًا لهذا الجهاز.
  int get lastSequence => _outgoingSequence;

  NetworkGameMove buildMove({
    required String playerId,
    required String action,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) {
    _outgoingSequence += 1;
    final NetworkGameMove move = NetworkGameMove(
      sequence: _outgoingSequence,
      playerId: playerId,
      action: action,
      payload: payload,
    );

    // نسجل الحركة المحلية أيضًا حتى لا يتم تطبيقها مرة ثانية إذا رجعت من الشبكة.
    _acceptedMoveKeys.add(move.uniqueKey);
    return move;
  }

  /// يقبل الحركة القادمة إذا لم يتم تطبيقها سابقًا.
  ///
  /// لا نقارن الرقم التسلسلي العام فقط، لأن كل جهاز يملك عدّادًا مستقلًا.
  /// لذلك نعتمد على playerId + sequence + action كمفتاح تكرار آمن.
  bool acceptIncoming(NetworkGameMove move) {
    if (move.playerId.trim().isEmpty || move.action.trim().isEmpty) {
      return false;
    }

    return _acceptedMoveKeys.add(move.uniqueKey);
  }

  void reset() {
    _outgoingSequence = 0;
    _acceptedMoveKeys.clear();
  }
}
