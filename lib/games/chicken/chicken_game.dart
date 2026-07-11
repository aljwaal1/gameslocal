import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/audio_feedback.dart';
import 'chicken_achievements.dart';
import 'chicken_achievements_screen.dart';

class ChickenGameScreen extends StatefulWidget {
  const ChickenGameScreen({super.key});

  @override
  State<ChickenGameScreen> createState() => _ChickenGameScreenState();
}

class _ChickenGameScreenState extends State<ChickenGameScreen> {
  static const int _roundSeconds = 30;
  static const int _maxRemainingSeconds = 45;
  static const String _bestScoreKey = 'chicken_best_score';
  static const String _totalCoinsKey = 'chicken_total_coins';
  static const String _backgroundKey = 'chicken_selected_background';
  static const String _unlockedBackgroundsKey = 'chicken_unlocked_backgrounds';

  final Random _random = Random();
  Timer? _timer;
  Timer? _effectTimer;

  int score = 0;
  int bestScore = 0;
  int remainingSeconds = _roundSeconds;
  int elapsedSeconds = 0;
  int chickenIndex = 0;
  int hits = 0;
  int attempts = 0;
  int combo = 0;
  int bestCombo = 0;
  int starSeconds = 0;
  int coins = 0;
  int totalCoins = 0;
  String selectedBackgroundId = 'farm';
  Set<String> unlockedBackgroundIds = {'farm'};
  bool isPlaying = false;
  bool isFinished = false;
  bool showFeathers = false;
  List<ChickenAchievement> newAchievements = const [];
  ChickenAchievementProgress? achievementProgress;
  _ChickenKind currentChicken = _ChickenKind.white;

  final List<Alignment> positions = const [
    Alignment(-0.85, -0.65),
    Alignment(0.0, -0.55),
    Alignment(0.75, -0.35),
    Alignment(-0.55, 0.05),
    Alignment(0.45, 0.2),
    Alignment(-0.1, 0.62),
    Alignment(0.85, 0.67),
    Alignment(-0.75, 0.42),
    Alignment(0.18, -0.08),
    Alignment(-0.88, -0.05),
  ];

  int get level => isPlaying ? (elapsedSeconds ~/ 5) + 1 : 1;
  int get moveDurationMs => max(105, 310 - (level * 28));
  int get accuracy => attempts == 0 ? 0 : ((hits / attempts) * 100).round();
  int get starMultiplier => starSeconds > 0 ? 2 : 1;
  int get comboMultiplier => combo >= 6 ? 3 : combo >= 3 ? 2 : 1;
  _ChickenBackground get selectedBackground => _ChickenBackground.all.firstWhere(
        (background) => background.id == selectedBackgroundId,
        orElse: () => _ChickenBackground.all.first,
      );

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _effectTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final progress = await ChickenAchievements.loadProgress();
    if (!mounted) return;
    setState(() {
      bestScore = prefs.getInt(_bestScoreKey) ?? 0;
      totalCoins = prefs.getInt(_totalCoinsKey) ?? 0;
      selectedBackgroundId = prefs.getString(_backgroundKey) ?? 'farm';
      unlockedBackgroundIds = {'farm', ...?prefs.getStringList(_unlockedBackgroundsKey)};
      if (!unlockedBackgroundIds.contains(selectedBackgroundId)) selectedBackgroundId = 'farm';
      achievementProgress = progress;
    });
  }

  Future<void> _saveBestScore(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bestScoreKey, value);
  }

  Future<void> _saveTotalCoins(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_totalCoinsKey, value);
  }

  Future<void> _saveStore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_totalCoinsKey, totalCoins);
    await prefs.setString(_backgroundKey, selectedBackgroundId);
    await prefs.setStringList(_unlockedBackgroundsKey, unlockedBackgroundIds.toList()..sort());
  }

  Future<void> _openStore() async {
    if (isPlaying) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أنهِ الجولة أولًا قبل فتح المتجر')));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('متجر المزرعة • $totalCoins 🪙', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._ChickenBackground.all.map((background) {
                final owned = unlockedBackgroundIds.contains(background.id);
                final selected = selectedBackgroundId == background.id;
                return Card(child: ListTile(
                  leading: Text(background.emoji, style: const TextStyle(fontSize: 30)),
                  title: Text(background.title),
                  subtitle: Text(owned ? (selected ? 'مستخدمة الآن' : 'مملوكة') : '${background.price} عملة'),
                  trailing: selected ? const Icon(Icons.check_circle, color: Colors.green) : FilledButton(
                    onPressed: !owned && totalCoins < background.price ? null : () async {
                      setState(() {
                        if (!owned) { totalCoins -= background.price; unlockedBackgroundIds.add(background.id); }
                        selectedBackgroundId = background.id;
                      });
                      setSheetState(() {});
                      await _saveStore();
                    },
                    child: Text(owned ? 'اختيار' : 'شراء'),
                  ),
                ));
              }),
            ]),
          ),
        ),
      ),
    );
  }

  void _startGame() {
    _timer?.cancel();
    _effectTimer?.cancel();
    setState(() {
      score = 0;
      remainingSeconds = _roundSeconds;
      elapsedSeconds = 0;
      chickenIndex = _random.nextInt(positions.length);
      currentChicken = _randomChicken();
      hits = 0;
      attempts = 0;
      combo = 0;
      bestCombo = 0;
      starSeconds = 0;
      coins = 0;
      showFeathers = false;
      newAchievements = const [];
      isPlaying = true;
      isFinished = false;
    });
    GameFeedback.tap();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        remainingSeconds--;
        elapsedSeconds++;
        if (starSeconds > 0) starSeconds--;
      });
      if (remainingSeconds <= 0) _finishGame(timer);
    });
  }

  Future<void> _finishGame(Timer timer) async {
    timer.cancel();
    if (!mounted) return;
    setState(() {
      isPlaying = false;
      isFinished = true;
      if (score > bestScore) {
        bestScore = score;
        _saveBestScore(bestScore);
      }
      combo = 0;
      showFeathers = false;
    });
    GameFeedback.win();

    final unlocked = await ChickenAchievements.evaluateRound(
      score: score,
      hits: hits,
      accuracy: accuracy,
      bestCombo: bestCombo,
      coins: coins,
    );
    final progress = await ChickenAchievements.loadProgress();
    if (!mounted) return;
    setState(() {
      newAchievements = unlocked;
      achievementProgress = progress;
    });
    if (unlocked.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('🏆 إنجاز جديد: ${unlocked.map((item) => item.title).join('، ')}'),
          action: SnackBarAction(label: 'عرض', onPressed: _openAchievements),
        ),
      );
    }
  }

  void _openAchievements() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const ChickenAchievementsScreen()))
        .then((_) => _loadSavedData());
  }

  void _hitChicken() {
    if (!isPlaying) {
      _startGame();
      return;
    }
    if (currentChicken.timeBonus > 0) return _collectTimeBonus();
    if (currentChicken.scoreBoost > 1) return _collectStarBonus();
    if (currentChicken.coinValue > 0) return _collectCoin();

    final isWrong = currentChicken.isPenalty;
    final urgentBonus = remainingSeconds <= 10 ? 5 : 0;
    final earned = isWrong
        ? currentChicken.points
        : (currentChicken.points + urgentBonus) * comboMultiplier * starMultiplier;
    _effectTimer?.cancel();
    setState(() {
      attempts++;
      if (isWrong) {
        score = max(0, score + earned);
        combo = 0;
      } else {
        hits++;
        combo++;
        bestCombo = max(bestCombo, combo);
        score += earned;
      }
      showFeathers = true;
      _moveTarget();
    });
    isWrong ? GameFeedback.error() : GameFeedback.move();
    _hideEffect();
  }

  void _collectTimeBonus() {
    setState(() {
      remainingSeconds = min(_maxRemainingSeconds, remainingSeconds + currentChicken.timeBonus);
      showFeathers = true;
      _moveTarget();
    });
    GameFeedback.move();
    _hideEffect();
  }

  void _collectStarBonus() {
    setState(() {
      starSeconds = 5;
      showFeathers = true;
      _moveTarget();
    });
    GameFeedback.win();
    _hideEffect();
  }

  void _collectCoin() {
    setState(() {
      coins += currentChicken.coinValue;
      totalCoins += currentChicken.coinValue;
      showFeathers = true;
      _moveTarget();
    });
    _saveTotalCoins(totalCoins);
    GameFeedback.move();
    _hideEffect();
  }

  void _hideEffect() {
    _effectTimer?.cancel();
    _effectTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => showFeathers = false);
    });
  }

  void _moveTarget() {
    chickenIndex = _nextChickenIndex();
    currentChicken = _randomChicken();
  }

  void _missTap() {
    if (!isPlaying) return;
    setState(() {
      attempts++;
      combo = 0;
    });
    GameFeedback.error();
  }

  int _nextChickenIndex() {
    int next = _random.nextInt(positions.length);
    while (next == chickenIndex) {
      next = _random.nextInt(positions.length);
    }
    return next;
  }

  _ChickenKind _randomChicken() {
    final roll = _random.nextInt(100);
    if (level >= 3 && roll < 12) return _ChickenKind.red;
    if (roll >= 94) return _ChickenKind.gold;
    if (level >= 2 && roll >= 88) return _ChickenKind.clock;
    if (level >= 3 && roll >= 84) return _ChickenKind.star;
    if (level >= 2 && roll >= 80) return _ChickenKind.coin;
    if (level >= 4 && roll >= 74) return _ChickenKind.black;
    if (level >= 2 && roll >= 48) return _ChickenKind.brown;
    return _ChickenKind.white;
  }

  void _resetGame() {
    _timer?.cancel();
    _effectTimer?.cancel();
    setState(() {
      score = 0;
      remainingSeconds = _roundSeconds;
      elapsedSeconds = 0;
      chickenIndex = 0;
      currentChicken = _ChickenKind.white;
      hits = 0;
      attempts = 0;
      combo = 0;
      bestCombo = 0;
      starSeconds = 0;
      coins = 0;
      newAchievements = const [];
      showFeathers = false;
      isPlaying = false;
      isFinished = false;
    });
  }

  String get _message {
    if (isFinished) return 'انتهى الوقت! النتيجة $score والدقة $accuracy%';
    if (!isPlaying) return 'اضغط على الدجاجة أو زر البدء لبدء الجولة';
    if (currentChicken.isPenalty) return 'انتبه! الدجاجة الحمراء تخصم نقاطًا';
    if (currentChicken.timeBonus > 0) return 'مكافأة وقت: +5 ثوانٍ';
    if (currentChicken.scoreBoost > 1) return 'نجمة نادرة: مضاعفة النقاط 5 ثوانٍ';
    if (currentChicken.coinValue > 0) return 'عملة نادرة: اجمعها ليبقى رصيدك محفوظًا';
    if (starSeconds > 0) return 'النجمة فعالة: النقاط ×2 لمدة $starSeconds ث';
    if (remainingSeconds <= 10) return 'الوقت قليل! كل إصابة تعطي نقاطًا إضافية';
    if (combo >= 6) return 'كومبو قوي ×3';
    if (combo >= 3) return 'كومبو ×2';
    return 'المستوى $level — اضغط على الدجاجة الصحيحة';
  }

  String get _targetLabel {
    if (currentChicken.timeBonus > 0) return '+${currentChicken.timeBonus}ث';
    if (currentChicken.scoreBoost > 1) return '×${currentChicken.scoreBoost}';
    if (currentChicken.coinValue > 0) return '+${currentChicken.coinValue}🪙';
    return '${currentChicken.points > 0 ? '+' : ''}${currentChicken.points}';
  }

  Color get _timerColor {
    if (remainingSeconds <= 10) return const Color(0xFFE63946);
    if (remainingSeconds <= 20) return const Color(0xFFFF9F1C);
    return const Color(0xFF2A9D8F);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لعبة الدجاجة'),
        centerTitle: true,
        actions: [
          IconButton(tooltip: 'المتجر • $totalCoins عملة', onPressed: _openStore, icon: const Icon(Icons.storefront_outlined)),
          IconButton(tooltip: 'الإنجازات', onPressed: _openAchievements, icon: const Icon(Icons.emoji_events_outlined)),
          IconButton(tooltip: 'إعادة', onPressed: _resetGame, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(children: [
              Expanded(child: _InfoBox(label: 'النقاط', value: '$score')),
              const SizedBox(width: 8),
              Expanded(child: _InfoBox(label: 'الوقت', value: '$remainingSeconds ث', valueColor: _timerColor)),
              const SizedBox(width: 8),
              Expanded(child: _InfoBox(label: 'الأفضل', value: '$bestScore')),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Row(children: [
              Expanded(child: _InfoBox(label: 'المستوى', value: '$level')),
              const SizedBox(width: 8),
              Expanded(child: _InfoBox(label: 'كومبو', value: combo > 0 ? '×$comboMultiplier / $combo' : '0')),
              const SizedBox(width: 8),
              Expanded(child: _InfoBox(label: 'الدقة', value: '$accuracy%')),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: currentChicken.softColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: currentChicken.color.withOpacity(0.55)),
              ),
              child: Text(_message, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4D3B00))),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _missTap,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: selectedBackground.colors),
                    ),
                    child: Stack(children: [
                      Positioned(left: 18, bottom: 20, child: Text(selectedBackground.leftEmoji, style: const TextStyle(fontSize: 46))),
                      Positioned(right: 28, bottom: 34, child: Text(selectedBackground.rightEmoji, style: const TextStyle(fontSize: 54))),
                      Positioned(left: 38, top: 25, child: Text(selectedBackground.skyEmoji, style: const TextStyle(fontSize: 38))),
                      Positioned(right: 40, top: 54, child: Text(selectedBackground.lightEmoji, style: const TextStyle(fontSize: 42))),
                      AnimatedAlign(
                        duration: Duration(milliseconds: moveDurationMs),
                        curve: Curves.easeOutBack,
                        alignment: positions[chickenIndex],
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _hitChicken,
                          child: Stack(alignment: Alignment.center, children: [
                            if (showFeathers) const Text('🪶✨🪶', style: TextStyle(fontSize: 28)),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: isPlaying ? currentChicken.size : 104,
                              height: isPlaying ? currentChicken.size : 104,
                              decoration: BoxDecoration(
                                color: isFinished ? Colors.white.withOpacity(0.94) : currentChicken.softColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: currentChicken.color, width: currentChicken == _ChickenKind.gold ? 5 : 3),
                                boxShadow: [BoxShadow(color: currentChicken.color.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
                              ),
                              child: Center(child: Text(isFinished ? '🏁' : currentChicken.emoji, style: const TextStyle(fontSize: 56))),
                            ),
                            if (isPlaying)
                              Positioned(
                                bottom: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(12)),
                                  child: Text(_targetLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                          ]),
                        ),
                      ),
                      if (isFinished)
                        _ResultPanel(
                          score: score,
                          bestScore: bestScore,
                          hits: hits,
                          accuracy: accuracy,
                          bestCombo: bestCombo,
                          coins: coins,
                          totalCoins: totalCoins,
                          newAchievements: newAchievements,
                          progress: achievementProgress,
                          onAchievements: _openAchievements,
                        ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 12,
                        child: ElevatedButton.icon(
                          onPressed: _startGame,
                          icon: Icon(isPlaying ? Icons.restart_alt : Icons.play_arrow),
                          label: Text(isPlaying ? 'بدء جولة جديدة' : 'ابدأ اللعب'),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChickenBackground {
  const _ChickenBackground({required this.id, required this.title, required this.price, required this.emoji, required this.colors, required this.leftEmoji, required this.rightEmoji, required this.skyEmoji, required this.lightEmoji});
  final String id;
  final String title;
  final int price;
  final String emoji;
  final List<Color> colors;
  final String leftEmoji;
  final String rightEmoji;
  final String skyEmoji;
  final String lightEmoji;

  static const all = <_ChickenBackground>[
    _ChickenBackground(id: 'farm', title: 'المزرعة الخضراء', price: 0, emoji: '🌾', colors: [Color(0xFF8ED1FC), Color(0xFFB7E4A7), Color(0xFF6AB04C)], leftEmoji: '🌾', rightEmoji: '🌳', skyEmoji: '☁️', lightEmoji: '☀️'),
    _ChickenBackground(id: 'desert', title: 'مزرعة الصحراء', price: 8, emoji: '🏜️', colors: [Color(0xFF87CEEB), Color(0xFFFFD89B), Color(0xFFD98C3F)], leftEmoji: '🌵', rightEmoji: '🏜️', skyEmoji: '☁️', lightEmoji: '☀️'),
    _ChickenBackground(id: 'night', title: 'المزرعة الليلية', price: 15, emoji: '🌙', colors: [Color(0xFF14213D), Color(0xFF264653), Color(0xFF2A5D50)], leftEmoji: '🌾', rightEmoji: '🌲', skyEmoji: '⭐', lightEmoji: '🌙'),
  ];
}

class _ChickenKind {
  const _ChickenKind({
    required this.emoji,
    required this.points,
    required this.color,
    required this.softColor,
    required this.size,
    this.isPenalty = false,
    this.timeBonus = 0,
    this.scoreBoost = 1,
    this.coinValue = 0,
  });

  final String emoji;
  final int points;
  final Color color;
  final Color softColor;
  final double size;
  final bool isPenalty;
  final int timeBonus;
  final int scoreBoost;
  final int coinValue;

  static const white = _ChickenKind(emoji: '🐔', points: 10, color: Color(0xFFFFD166), softColor: Color(0xFFFFF7D6), size: 88);
  static const brown = _ChickenKind(emoji: '🐔', points: 20, color: Color(0xFFB5651D), softColor: Color(0xFFFFE0B2), size: 82);
  static const black = _ChickenKind(emoji: '🐔', points: 35, color: Color(0xFF2D3436), softColor: Color(0xFFDDE1E4), size: 76);
  static const gold = _ChickenKind(emoji: '🐥', points: 100, color: Color(0xFFFFB703), softColor: Color(0xFFFFF0A3), size: 72);
  static const coin = _ChickenKind(emoji: '🪙', points: 0, color: Color(0xFFE09F00), softColor: Color(0xFFFFF1B8), size: 68, coinValue: 1);
  static const star = _ChickenKind(emoji: '⭐', points: 0, color: Color(0xFF7B2CBF), softColor: Color(0xFFF0DFFF), size: 70, scoreBoost: 2);
  static const clock = _ChickenKind(emoji: '⏱️', points: 0, color: Color(0xFF118AB2), softColor: Color(0xFFD8F3FF), size: 72, timeBonus: 5);
  static const red = _ChickenKind(emoji: '🐔', points: -30, color: Color(0xFFE63946), softColor: Color(0xFFFFD6D9), size: 80, isPenalty: true);
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.score,
    required this.bestScore,
    required this.hits,
    required this.accuracy,
    required this.bestCombo,
    required this.coins,
    required this.totalCoins,
    required this.newAchievements,
    required this.progress,
    required this.onAchievements,
  });

  final int score;
  final int bestScore;
  final int hits;
  final int accuracy;
  final int bestCombo;
  final int coins;
  final int totalCoins;
  final List<ChickenAchievement> newAchievements;
  final ChickenAchievementProgress? progress;
  final VoidCallback onAchievements;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.30),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.fromLTRB(24, 24, 24, 76),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 8))]),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('نتيجة الجولة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                  _MiniStat(label: 'النقاط', value: '$score'),
                  _MiniStat(label: 'الأفضل', value: '$bestScore'),
                  _MiniStat(label: 'الإصابات', value: '$hits'),
                  _MiniStat(label: 'الدقة', value: '$accuracy%'),
                  _MiniStat(label: 'أفضل كومبو', value: '$bestCombo'),
                  _MiniStat(label: 'عملات الجولة', value: '$coins'),
                  _MiniStat(label: 'إجمالي العملات', value: '$totalCoins'),
                ]),
                if (newAchievements.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('🏆 إنجاز جديد: ${newAchievements.map((item) => item.title).join('، ')}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF9A6700))),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onAchievements,
                  icon: const Icon(Icons.emoji_events_outlined),
                  label: Text(progress == null ? 'عرض الإنجازات' : 'الإنجازات ${progress!.label}'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(color: const Color(0xFFF6F7FB), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))]),
      child: Column(children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: valueColor)),
      ]),
    );
  }
}
