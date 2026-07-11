class BattleQuickMatchChoice {
  const BattleQuickMatchChoice({
    required this.characterIndex,
    required this.botLevel,
  });

  final int characterIndex;
  final String botLevel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BattleQuickMatchChoice &&
          characterIndex == other.characterIndex &&
          botLevel == other.botLevel;

  @override
  int get hashCode => Object.hash(characterIndex, botLevel);

  @override
  String toString() =>
      'BattleQuickMatchChoice(characterIndex: $characterIndex, botLevel: $botLevel)';
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

  final int nextCharacter;
  if (characterCount > 1) {
    var candidate = characterRoll % (characterCount - 1);
    if (candidate >= currentCharacter) candidate += 1;
    nextCharacter = candidate;
  } else {
    nextCharacter = 0;
  }

  final currentLevelIndex = battleBotLevels.indexOf(currentBotLevel);
  var nextLevelIndex = levelRoll % (battleBotLevels.length - 1);
  if (nextLevelIndex >= currentLevelIndex) nextLevelIndex += 1;

  return BattleQuickMatchChoice(
    characterIndex: nextCharacter,
    botLevel: battleBotLevels[nextLevelIndex],
  );
}
