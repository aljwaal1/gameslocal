int selectDominoStartingPlayer(List<List<(int, int)>> hands) {
  if (hands.isEmpty) {
    throw ArgumentError.value(hands, 'hands', 'At least one hand is required');
  }
  if (hands.any((hand) => hand.isEmpty)) {
    throw ArgumentError.value(hands, 'hands', 'Each player must have at least one tile');
  }

  int? bestDoublePlayer;
  var bestDouble = -1;
  var bestFallbackPlayer = 0;
  var bestFallbackScore = -1;
  var bestFallbackHighPip = -1;

  for (var player = 0; player < hands.length; player++) {
    for (final tile in hands[player]) {
      final a = tile.$1;
      final b = tile.$2;
      if (a < 0 || a > 6 || b < 0 || b > 6) {
        throw ArgumentError.value(
          tile,
          'hands',
          'Tile pips must be between 0 and 6',
        );
      }

      if (a == b && a > bestDouble) {
        bestDouble = a;
        bestDoublePlayer = player;
      }

      final score = a + b;
      final highPip = a > b ? a : b;
      if (score > bestFallbackScore ||
          (score == bestFallbackScore && highPip > bestFallbackHighPip)) {
        bestFallbackScore = score;
        bestFallbackHighPip = highPip;
        bestFallbackPlayer = player;
      }
    }
  }

  return bestDoublePlayer ?? bestFallbackPlayer;
}
