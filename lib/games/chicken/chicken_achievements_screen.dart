import 'package:flutter/material.dart';

import 'chicken_achievements.dart';

class ChickenAchievementsScreen extends StatefulWidget {
  const ChickenAchievementsScreen({super.key});

  @override
  State<ChickenAchievementsScreen> createState() =>
      _ChickenAchievementsScreenState();
}

class _ChickenAchievementsScreenState
    extends State<ChickenAchievementsScreen> {
  late Future<List<ChickenAchievementStatus>> _statusesFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _statusesFuture = ChickenAchievements.loadStatuses();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _statusesFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنجازات لعبة الدجاجة'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<ChickenAchievementStatus>>(
        future: _statusesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 52),
                    const SizedBox(height: 12),
                    const Text(
                      'تعذر تحميل الإنجازات',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => setState(_reload),
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            );
          }

          final statuses = snapshot.data ?? const <ChickenAchievementStatus>[];
          final unlockedCount = statuses.where((item) => item.isUnlocked).length;
          final ratio = statuses.isEmpty ? 0.0 : unlockedCount / statuses.length;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _ProgressCard(
                  unlockedCount: unlockedCount,
                  totalCount: statuses.length,
                  ratio: ratio,
                ),
                const SizedBox(height: 16),
                ...statuses.map(
                  (status) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AchievementCard(status: status),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.unlockedCount,
    required this.totalCount,
    required this.ratio,
  });

  final int unlockedCount;
  final int totalCount;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final percentage = (ratio * 100).round();

    return Card(
      elevation: 0,
      color: const Color(0xFFFFF4D8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('🏆', style: TextStyle(fontSize: 34)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تقدم الإنجازات',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                      ),
                      Text('$unlockedCount من $totalCount — $percentage%'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 12,
                backgroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.status});

  final ChickenAchievementStatus status;

  @override
  Widget build(BuildContext context) {
    final achievement = status.achievement;
    final unlocked = status.isUnlocked;

    return Card(
      elevation: 0,
      color: unlocked ? const Color(0xFFE8F8EE) : const Color(0xFFF2F3F5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: unlocked ? const Color(0xFF57A773) : const Color(0xFFD5D8DC),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: unlocked ? Colors.white : const Color(0xFFE1E3E6),
                shape: BoxShape.circle,
              ),
              child: Text(
                unlocked ? achievement.emoji : '🔒',
                style: const TextStyle(fontSize: 30),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: unlocked ? null : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    achievement.description,
                    style: TextStyle(
                      color: unlocked ? Colors.black87 : Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    unlocked ? 'تم فتح الإنجاز' : 'لم يُفتح بعد',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: unlocked
                          ? const Color(0xFF2E7D4A)
                          : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
