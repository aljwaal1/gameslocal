class DominoTurnOrder {
  DominoTurnOrder({required this.playerCount, this.currentPlayer = 0})
      : assert(playerCount >= 2 && playerCount <= 4),
        assert(currentPlayer >= 0 && currentPlayer < playerCount);

  final int playerCount;
  int currentPlayer;

  int next({Set<int> skipped = const <int>{}}) {
    for (var offset = 1; offset <= playerCount; offset++) {
      final candidate = (currentPlayer + offset) % playerCount;
      if (!skipped.contains(candidate)) {
        currentPlayer = candidate;
        return currentPlayer;
      }
    }
    return currentPlayer;
  }

  void reset({int startingPlayer = 0}) {
    if (startingPlayer < 0 || startingPlayer >= playerCount) {
      throw RangeError.range(startingPlayer, 0, playerCount - 1, 'startingPlayer');
    }
    currentPlayer = startingPlayer;
  }
}
