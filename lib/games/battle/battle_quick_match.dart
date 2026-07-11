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
  if (characterCount <= 0) {
    throw ArgumentError.value(
      characterCount,
      'characterCount',
      'يجب أن يتوفر اختيار واحد على الأقل للشخصيات',
    );
  }
  if (characterRoll < 0) {
    throw ArgumentError.value(
      characterRoll,
      'characterRoll',
      'يجب ألا تكون قرعة الشخصية سالبة',
    );
  }
  if (levelRoll < 0) {
    throw ArgumentError.value(
      levelRoll,
      'levelRoll',
      'يجب ألا تكون قرعة مستوى الروبوت سالبة',
    );
  }

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
