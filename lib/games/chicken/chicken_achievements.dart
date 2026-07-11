import 'package:shared_preferences/shared_preferences.dart';

/// Persistent achievements for the Chicken game.
///
/// The engine is intentionally independent from the UI so it can be reused by
/// the result panel and any future achievements screen.
class ChickenAchievements {
  ChickenAchievements._();

  static const String _storageKey = 'chicken_unlocked_achievements';

  static const List<ChickenAchievement> all = [
    ChickenAchievement(
      id: 'first_hit',
      title: 'بداية موفقة',
      description: 'حقق أول إصابة صحيحة.',
      emoji: '🐔',
    ),
    ChickenAchievement(
      id: 'score_500',
      title: 'صياد ماهر',
      description: 'حقق 500 نقطة في جولة واحدة.',
      emoji: '🏆',
    ),
    ChickenAchievement(
      id: 'combo_10',
      title: 'سلسلة سريعة',
      description: 'وصل إلى كومبو 10 في جولة واحدة.',
      emoji: '⚡',
    ),
    ChickenAchievement(
      id: 'accuracy_90',
      title: 'دقة ممتازة',
      description: 'أنه جولة بدقة 90% أو أكثر مع 10 إصابات على الأقل.',
      emoji: '🎯',
    ),
    ChickenAchievement(
      id: 'perfect_15',
      title: 'جولة مثالية',
      description: 'حقق 15 إصابة على الأقل بدقة 100% في جولة واحدة.',
      emoji: '💯',
    ),
    ChickenAchievement(
      id: 'coins_3',
      title: 'جامع العملات',
      description: 'اجمع 3 عملات في جولة واحدة.',
      emoji: '🪙',
    ),
  ];

  static Future<Set<String>> loadUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_storageKey) ?? const <String>[]).toSet();
  }

  /// Returns every achievement with its current locked/unlocked state.
  static Future<List<ChickenAchievementStatus>> loadStatuses() async {
    final unlocked = await loadUnlocked();
    return all
        .map(
          (achievement) => ChickenAchievementStatus(
            achievement: achievement,
            isUnlocked: unlocked.contains(achievement.id),
          ),
        )
        .toList(growable: false);
  }

  /// Compact progress information for the result panel and achievements page.
  static Future<ChickenAchievementProgress> loadProgress() async {
    final unlocked = await loadUnlocked();
    final unlockedCount = all.where((item) => unlocked.contains(item.id)).length;
    return ChickenAchievementProgress(
      unlockedCount: unlockedCount,
      totalCount: all.length,
    );
  }

  /// Evaluates the completed round, persists newly unlocked achievements, and
  /// returns only the achievements unlocked by this round.
  static Future<List<ChickenAchievement>> evaluateRound({
    required int score,
    required int hits,
    required int accuracy,
    required int bestCombo,
    required int coins,
  }) async {
    _validateRoundStats(
      score: score,
      hits: hits,
      accuracy: accuracy,
      bestCombo: bestCombo,
      coins: coins,
    );

    final prefs = await SharedPreferences.getInstance();
    final unlocked = (prefs.getStringList(_storageKey) ?? const <String>[]).toSet();
    final newlyUnlocked = <ChickenAchievement>[];

    void unlock(String id, bool condition) {
      if (!condition || unlocked.contains(id)) return;
      final achievement = all.firstWhere((item) => item.id == id);
      unlocked.add(id);
      newlyUnlocked.add(achievement);
    }

    unlock('first_hit', hits >= 1);
    unlock('score_500', score >= 500);
    unlock('combo_10', bestCombo >= 10);
    unlock('accuracy_90', hits >= 10 && accuracy >= 90);
    unlock('perfect_15', hits >= 15 && accuracy == 100);
    unlock('coins_3', coins >= 3);

    if (newlyUnlocked.isNotEmpty) {
      await prefs.setStringList(_storageKey, unlocked.toList()..sort());
    }

    return newlyUnlocked;
  }

  static void _validateRoundStats({
    required int score,
    required int hits,
    required int accuracy,
    required int bestCombo,
    required int coins,
  }) {
    if (score < 0) {
      throw ArgumentError.value(score, 'score', 'must not be negative');
    }
    if (hits < 0) {
      throw ArgumentError.value(hits, 'hits', 'must not be negative');
    }
    if (accuracy < 0 || accuracy > 100) {
      throw ArgumentError.value(accuracy, 'accuracy', 'must be between 0 and 100');
    }
    if (bestCombo < 0) {
      throw ArgumentError.value(bestCombo, 'bestCombo', 'must not be negative');
    }
    if (coins < 0) {
      throw ArgumentError.value(coins, 'coins', 'must not be negative');
    }
    if (bestCombo > hits) {
      throw ArgumentError.value(bestCombo, 'bestCombo', 'must not exceed hits');
    }
  }

  static Future<void> resetForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}

class ChickenAchievement {
  const ChickenAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
  });

  final String id;
  final String title;
  final String description;
  final String emoji;
}

class ChickenAchievementStatus {
  const ChickenAchievementStatus({
    required this.achievement,
    required this.isUnlocked,
  });

  final ChickenAchievement achievement;
  final bool isUnlocked;
}

class ChickenAchievementProgress {
  const ChickenAchievementProgress({
    required this.unlockedCount,
    required this.totalCount,
  });

  final int unlockedCount;
  final int totalCount;

  double get ratio => totalCount == 0 ? 0 : unlockedCount / totalCount;

  int get percentage => (ratio * 100).round();

  String get label => '$unlockedCount من $totalCount';
}
