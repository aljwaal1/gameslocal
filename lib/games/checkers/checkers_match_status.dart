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

  static const int startingPiecesPerSide = 16;

  final int redPieces;
  final int blackPieces;
  final bool redHasMove;
  final bool blackHasMove;
  final CheckersWinner? winner;
  final String? reason;

  bool get isFinished => winner != null;

  int _normalizePieces(int pieces) {
    if (pieces < 0) return 0;
    if (pieces > startingPiecesPerSide) return startingPiecesPerSide;
    return pieces;
  }

  int get normalizedRedPieces => _normalizePieces(redPieces);

  int get normalizedBlackPieces => _normalizePieces(blackPieces);

  int _capturedPieces(int remainingPieces) =>
      startingPiecesPerSide - _normalizePieces(remainingPieces);

  int get capturedByRed => _capturedPieces(blackPieces);

  int get capturedByBlack => _capturedPieces(redPieces);

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

  String get piecesText =>
      'الأحجار: الأحمر $normalizedRedPieces • الأسود $normalizedBlackPieces';

  String get capturedText => 'الأسر: الأحمر $capturedByRed • الأسود $capturedByBlack';

  String get piecesAdvantageText {
    final difference = (normalizedRedPieces - normalizedBlackPieces).abs();
    if (difference == 0) return 'تعادل في عدد الأحجار';
    final leader =
        normalizedRedPieces > normalizedBlackPieces ? 'الأحمر' : 'الأسود';
    return 'أفضلية $leader بفارق $difference';
  }

  String get resultText {
    if (!isFinished) return '';
    final result = reason == null || reason!.isEmpty
        ? winnerText
        : '$winnerText — $reason';
    return '$result • $piecesText • $capturedText • $piecesAdvantageText';
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
