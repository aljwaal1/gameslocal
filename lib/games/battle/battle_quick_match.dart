class BattleQuickMatchChoice {
  const BattleQuickMatchChoice({
    required this.characterIndex,
    required this.botLevel,
  });

  final int characterIndex;
  final String botLevel;
}

const List<String> battleBotLevels = ['سهل', 'متوسط', 'صعب'];

BattleQuickMatchChoice buildBattleQuickMatchChoice({
  required int currentCharacter,
  required String currentBotLevel,
  required int characterRoll,
  required int levelRoll,
  required int characterCount,
}) {
  assert(characterCount > 0);

  var nextCharacter = characterRoll % characterCount;
  final nextBotLevel = battleBotLevels[levelRoll % battleBotLevels.length];

  if (nextCharacter == currentCharacter && nextBotLevel == currentBotLevel) {
    nextCharacter = (nextCharacter + 1) % characterCount;
  }

  return BattleQuickMatchChoice(
    characterIndex: nextCharacter,
    botLevel: nextBotLevel,
  );
}
