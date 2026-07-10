enum CheckersWinner { red, black, draw }

class CheckersMatchStatus {
  const CheckersMatchStatus({
    required this.redPieces,
    required this.blackPieces,
    required this.redHasMove,
    required this.blackHasMove,
    this.winner,
    this.reason,
  });

  final int redPieces;
  final int blackPieces;
  final bool redHasMove;
  final bool blackHasMove;
  final CheckersWinner? winner;
  final String? reason;

  bool get isFinished => winner != null;

  String get winnerText {
    switch (winner) {
      case CheckersWinner.red:
        return 'فاز الأحمر';
      case CheckersWinner.black:
        return 'فاز الأسود';
      case CheckersWinner.draw:
        return 'تعادل';
      case null:
        return '';
    }
  }

  String get piecesText => 'الأحجار: الأحمر $redPieces • الأسود $blackPieces';

  String get piecesAdvantageText {
    final difference = (redPieces - blackPieces).abs();
    if (difference == 0) return 'تعادل في عدد الأحجار';
    final leader = redPieces > blackPieces ? 'الأحمر' : 'الأسود';
    return 'أفضلية $leader بفارق $difference';
  }

  String get resultText {
    if (!isFinished) return '';
    final result = reason == null || reason!.isEmpty
        ? winnerText
        : '$winnerText — $reason';
    return '$result • $piecesText • $piecesAdvantageText';
  }
}

class CheckersMatchEvaluator {
  const CheckersMatchEvaluator._();

  static CheckersMatchStatus evaluate({
    required int redPieces,
    required int blackPieces,
    required bool redHasMove,
    required bool blackHasMove,
  }) {
    if (redPieces <= 0 && blackPieces <= 0) {
      return const CheckersMatchStatus(
        redPieces: 0,
        blackPieces: 0,
        redHasMove: false,
        blackHasMove: false,
        winner: CheckersWinner.draw,
        reason: 'انتهت أحجار الطرفين',
      );
    }

    if (redPieces <= 0) {
      return CheckersMatchStatus(
        redPieces: 0,
        blackPieces: blackPieces,
        redHasMove: false,
        blackHasMove: blackHasMove,
        winner: CheckersWinner.black,
        reason: 'انتهت أحجار الأحمر',
      );
    }

    if (blackPieces <= 0) {
      return CheckersMatchStatus(
        redPieces: redPieces,
        blackPieces: 0,
        redHasMove: redHasMove,
        blackHasMove: false,
        winner: CheckersWinner.red,
        reason: 'انتهت أحجار الأسود',
      );
    }

    if (!redHasMove && !blackHasMove) {
      return CheckersMatchStatus(
        redPieces: redPieces,
        blackPieces: blackPieces,
        redHasMove: false,
        blackHasMove: false,
        winner: CheckersWinner.draw,
        reason: 'لا توجد حركة للطرفين',
      );
    }

    if (!redHasMove) {
      return CheckersMatchStatus(
        redPieces: redPieces,
        blackPieces: blackPieces,
        redHasMove: false,
        blackHasMove: blackHasMove,
        winner: CheckersWinner.black,
        reason: 'لا توجد حركة للأحمر',
      );
    }

    if (!blackHasMove) {
      return CheckersMatchStatus(
        redPieces: redPieces,
        blackPieces: blackPieces,
        redHasMove: redHasMove,
        blackHasMove: false,
        winner: CheckersWinner.red,
        reason: 'لا توجد حركة للأسود',
      );
    }

    return CheckersMatchStatus(
      redPieces: redPieces,
      blackPieces: blackPieces,
      redHasMove: redHasMove,
      blackHasMove: blackHasMove,
    );
  }
}
