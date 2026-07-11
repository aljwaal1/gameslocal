class BattleQuickMatchChoice {
  factory BattleQuickMatchChoice({
    required int characterIndex,
    required int characterCount,
    required String botLevel,
  }) {
    if (characterCount <= 0) {
      throw ArgumentError.value(
        characterCount,
        'characterCount',
        'يجب أن يتوفر اختيار واحد على الأقل للشخصيات',
      );
    }
    if (characterIndex < 0 || characterIndex >= characterCount) {
      throw ArgumentError.value(
        characterIndex,
        'characterIndex',
        'فهرس شخصية المباراة السريعة خارج النطاق المتاح',
      );
    }
    if (!battleBotLevels.contains(botLevel)) {
      throw ArgumentError.value(
        botLevel,
        'botLevel',
        'مستوى روبوت المباراة السريعة غير معروف',
      );
    }
    return BattleQuickMatchChoice._(
      characterIndex: characterIndex,
      characterCount: characterCount,
      botLevel: botLevel,
    );
  }

  const BattleQuickMatchChoice._({
    required this.characterIndex,
    required this.characterCount,
    required this.botLevel,
  });

  final int characterIndex;
  final int characterCount;
  final String botLevel;

  bool differsFrom({
    required int characterIndex,
    required String botLevel,
  }) {
    if (characterIndex < 0 || characterIndex >= characterCount) {
      throw ArgumentError.value(
        characterIndex,
        'characterIndex',
        'فهرس الشخصية الحالية خارج النطاق المتاح للمقارنة',
      );
    }
    if (!battleBotLevels.contains(botLevel)) {
      throw ArgumentError.value(
        botLevel,
        'botLevel',
        'مستوى الروبوت الحالي غير معروف للمقارنة',
      );
    }
    return this.characterIndex != characterIndex || this.botLevel != botLevel;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BattleQuickMatchChoice &&
          characterIndex == other.characterIndex &&
          characterCount == other.characterCount &&
          botLevel == other.botLevel;

  @override
  int get hashCode => Object.hash(characterIndex, characterCount, botLevel);

  @override
  String toString() =>
      'BattleQuickMatchChoice(characterIndex: $characterIndex, characterCount: $characterCount, botLevel: $botLevel)';
}

const List<String> battleBotLevels = ['سهل', 'متوسط', 'صعب'];

int battleQuickMatchRollBound(int optionCount) {
  if (optionCount <= 0) {
    throw ArgumentError.value(
      optionCount,
      'optionCount',
      'يجب أن يتوفر خيار واحد على الأقل للقرعة',
    );
  }
  return optionCount > 1 ? optionCount - 1 : 1;
}

void _validateBattleQuickMatchRoll({
  required int roll,
  required int bound,
  required String name,
}) {
  if (roll < 0 || roll >= bound) {
    throw RangeError.range(
      roll,
      0,
      bound - 1,
      name,
      'قيمة القرعة خارج النطاق الذي تسمح به Random.nextInt',
    );
  }
}

BattleQuickMatchChoice buildBattleQuickMatchChoice({
  required int currentCharacter,
  required String currentBotLevel,
  required int characterRoll,
  required int levelRoll,
  required int characterCount,
}) {
  final characterRollBound = battleQuickMatchRollBound(characterCount);
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

  final levelRollBound = battleQuickMatchRollBound(battleBotLevels.length);
  _validateBattleQuickMatchRoll(
    roll: characterRoll,
    bound: characterRollBound,
    name: 'characterRoll',
  );
  _validateBattleQuickMatchRoll(
    roll: levelRoll,
    bound: levelRollBound,
    name: 'levelRoll',
  );

  final int nextCharacter;
  if (characterCount > 1) {
    var candidate = characterRoll;
    if (candidate >= currentCharacter) candidate += 1;
    nextCharacter = candidate;
  } else {
    nextCharacter = 0;
  }

  final currentLevelIndex = battleBotLevels.indexOf(currentBotLevel);
  var nextLevelIndex = levelRoll;
  if (nextLevelIndex >= currentLevelIndex) nextLevelIndex += 1;

  final choice = BattleQuickMatchChoice(
    characterIndex: nextCharacter,
    characterCount: characterCount,
    botLevel: battleBotLevels[nextLevelIndex],
  );
  if (!choice.differsFrom(
    characterIndex: currentCharacter,
    botLevel: currentBotLevel,
  )) {
    throw StateError('يجب أن تختلف المباراة السريعة عن الإعداد الحالي');
  }
  return choice;
}
