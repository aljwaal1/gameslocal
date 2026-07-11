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

  String _pieceCountLabel(int count) {
    if (count == 1) return 'حجر واحد';
    if (count == 2) return 'حجرين';
    if (count >= 3 && count <= 10) return '$count أحجار';
    return '$count حجرًا';
  }

  String _remainingPieceCountLabel(int count) {
    if (count == 0) return 'لا أحجار';
    if (count == 1) return 'حجر واحد';
    if (count == 2) return 'حجران';
    if (count >= 3 && count <= 10) return '$count أحجار';
    return '$count حجرًا';
  }

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
      'الأحجار المتبقية: الأحمر ${_remainingPieceCountLabel(normalizedRedPieces)} • '
      'الأسود ${_remainingPieceCountLabel(normalizedBlackPieces)}';

  String get capturedText =>
      'الأسر: الأحمر ${_pieceCountLabel(capturedByRed)} • '
      'الأسود ${_pieceCountLabel(capturedByBlack)}';

  String get winnerCaptureText {
    switch (winner) {
      case CheckersWinner.red:
        return 'أسر الأحمر ${_pieceCountLabel(capturedByRed)} من أحجار الأسود';
      case CheckersWinner.black:
        return 'أسر الأسود ${_pieceCountLabel(capturedByBlack)} من أحجار الأحمر';
      case CheckersWinner.draw:
        return 'إجمالي الأسر ${_pieceCountLabel(capturedByRed + capturedByBlack)}';
      case null:
        return '';
    }
  }

  String get captureAdvantageText {
    final difference = (capturedByRed - capturedByBlack).abs();
    if (difference == 0) return 'تعادل في عدد الأحجار المأسورة';
    final leader = capturedByRed > capturedByBlack ? 'الأحمر' : 'الأسود';
    return 'أفضلية الأسر لصالح $leader بفارق ${_pieceCountLabel(difference)}';
  }

  String get piecesAdvantageText {
    final difference = (normalizedRedPieces - normalizedBlackPieces).abs();
    if (difference == 0) return 'تعادل في عدد الأحجار';
    final leader =
        normalizedRedPieces > normalizedBlackPieces ? 'الأحمر' : 'الأسود';
    return 'أفضلية $leader بفارق ${_pieceCountLabel(difference)}';
  }

  String get resultText {
    if (!isFinished) return '';
    final normalizedReason = reason?.trim();
    final result = normalizedReason == null || normalizedReason.isEmpty
        ? winnerText
        : '$winnerText — $normalizedReason';
    return [
      result,
      piecesText,
      capturedText,
      captureAdvantageText,
      piecesAdvantageText,
    ].join('\n');
  }
}

class CheckersMatchEvaluator {
  const CheckersMatchEvaluator._();

  static int _normalizePieces(int pieces) =>
      pieces.clamp(0, CheckersMatchStatus.startingPiecesPerSide) as int;

  static CheckersMatchStatus evaluate({
    required int redPieces,
    required int blackPieces,
    required bool redHasMove,
    required bool blackHasMove,
  }) {
    final normalizedRedPieces = _normalizePieces(redPieces);
    final normalizedBlackPieces = _normalizePieces(blackPieces);

    if (normalizedRedPieces == 0 && normalizedBlackPieces == 0) {
      return const CheckersMatchStatus(
        redPieces: 0,
        blackPieces: 0,
        redHasMove: false,
        blackHasMove: false,
        winner: CheckersWinner.draw,
        reason: 'انتهت أحجار الطرفين',
      );
    }

    if (normalizedRedPieces == 0) {
      return CheckersMatchStatus(
        redPieces: 0,
        blackPieces: normalizedBlackPieces,
        redHasMove: false,
        blackHasMove: blackHasMove,
        winner: CheckersWinner.black,
        reason: 'انتهت أحجار الأحمر',
      );
    }

    if (normalizedBlackPieces == 0) {
      return CheckersMatchStatus(
        redPieces: normalizedRedPieces,
        blackPieces: 0,
        redHasMove: redHasMove,
        blackHasMove: false,
        winner: CheckersWinner.red,
        reason: 'انتهت أحجار الأسود',
      );
    }

    if (!redHasMove && !blackHasMove) {
      final winner = normalizedRedPieces == normalizedBlackPieces
          ? CheckersWinner.draw
          : normalizedRedPieces > normalizedBlackPieces
              ? CheckersWinner.red
              : CheckersWinner.black;
      return CheckersMatchStatus(
        redPieces: normalizedRedPieces,
        blackPieces: normalizedBlackPieces,
        redHasMove: false,
        blackHasMove: false,
        winner: winner,
        reason: winner == CheckersWinner.draw
            ? 'لا توجد حركة للطرفين وتساوى عدد الأحجار'
            : 'لا توجد حركة للطرفين وحُسمت بعدد الأحجار',
      );
    }

    if (!redHasMove) {
      return CheckersMatchStatus(
        redPieces: normalizedRedPieces,
        blackPieces: normalizedBlackPieces,
        redHasMove: false,
        blackHasMove: blackHasMove,
        winner: CheckersWinner.black,
        reason: 'لا توجد حركة للأحمر',
      );
    }

    if (!blackHasMove) {
      return CheckersMatchStatus(
        redPieces: normalizedRedPieces,
        blackPieces: normalizedBlackPieces,
        redHasMove: redHasMove,
        blackHasMove: false,
        winner: CheckersWinner.red,
        reason: 'لا توجد حركة للأسود',
      );
    }

    return CheckersMatchStatus(
      redPieces: normalizedRedPieces,
      blackPieces: normalizedBlackPieces,
      redHasMove: redHasMove,
      blackHasMove: blackHasMove,
    );
  }
}
