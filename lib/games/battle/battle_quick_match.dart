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
  if (currentCharacter < 0 || currentCharacter >= characterCount) {
    throw ArgumentError.value(
      currentCharacter,
      'currentCharacter',
      'اختيار الشخصية الحالي خارج النطاق المتاح',
    );
  }
  if (!battleBotLevels.contains(currentBotLevel)) {
    throw ArgumentError.value(
      currentBotLevel,
      'currentBotLevel',
      'مستوى الروبوت الحالي غير معروف',
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
  var nextBotLevel = battleBotLevels[levelRoll % battleBotLevels.length];

  if (nextCharacter == currentCharacter && nextBotLevel == currentBotLevel) {
    if (characterCount > 1) {
      nextCharacter = (nextCharacter + 1) % characterCount;
    } else {
      final currentLevelIndex = battleBotLevels.indexOf(currentBotLevel);
      nextBotLevel = battleBotLevels[(currentLevelIndex + 1) % battleBotLevels.length];
    }
  }

  return BattleQuickMatchChoice(
    characterIndex: nextCharacter,
    botLevel: nextBotLevel,
  );
}
