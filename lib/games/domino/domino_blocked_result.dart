class DominoBlockedResult {
  const DominoBlockedResult({
    required this.points,
    required this.bestScore,
    required this.winners,
  });

  final List<int> points;
  final int bestScore;
  final List<int> winners;
}

DominoBlockedResult calculateDominoBlockedResult(
  List<List<int>> handTileValues,
) {
  if (handTileValues.isEmpty) {
    throw ArgumentError.value(
      handTileValues,
      'handTileValues',
      'At least one player hand is required.',
    );
  }

  final points = handTileValues
      .map((hand) => hand.fold<int>(0, (sum, value) => sum + value))
      .toList(growable: false);
  final bestScore = points.reduce((a, b) => a < b ? a : b);
  final winners = <int>[
    for (var index = 0; index < points.length; index++)
      if (points[index] == bestScore) index + 1,
  ];

  return DominoBlockedResult(
    points: points,
    bestScore: bestScore,
    winners: winners,
  );
}
