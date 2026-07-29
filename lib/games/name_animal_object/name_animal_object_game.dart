import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class NameAnimalObjectGameScreen extends StatefulWidget {
  const NameAnimalObjectGameScreen({super.key});

  @override
  State<NameAnimalObjectGameScreen> createState() =>
      _NameAnimalObjectGameScreenState();
}

class _NameAnimalObjectGameScreenState
    extends State<NameAnimalObjectGameScreen> {
  static const List<String> _letters = <String>[
    'ا', 'ب', 'ت', 'ث', 'ج', 'ح', 'خ', 'د', 'ذ', 'ر', 'ز', 'س', 'ش',
    'ص', 'ض', 'ط', 'ظ', 'ع', 'غ', 'ف', 'ق', 'ك', 'ل', 'م', 'ن', 'ه',
    'و', 'ي',
  ];

  static const List<String> _categories = <String>[
    'اسم',
    'حيوان',
    'جماد',
    'نبات',
    'بلاد',
  ];

  final Random _random = Random();
  final TextEditingController _playerNameController = TextEditingController();
  final Map<String, TextEditingController> _answerControllers =
      <String, TextEditingController>{};

  final List<String> _players = <String>[];
  final Map<String, int> _scores = <String, int>{};
  final Map<String, Map<String, String>> _roundAnswers =
      <String, Map<String, String>>{};
  final List<_RoundResult> _history = <_RoundResult>[];

  Timer? _timer;
  int _secondsLeft = 60;
  int _round = 0;
  int _currentPlayerIndex = 0;
  String _letter = 'ا';
  _GameStage _stage = _GameStage.setup;

  @override
  void initState() {
    super.initState();
    for (final category in _categories) {
      _answerControllers[category] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _playerNameController.dispose();
    for (final controller in _answerControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addPlayer() {
    final name = _playerNameController.text.trim();
    if (name.isEmpty || _players.contains(name)) return;
    setState(() {
      _players.add(name);
      _scores[name] = 0;
      _playerNameController.clear();
    });
  }

  void _removePlayer(String player) {
    setState(() {
      _players.remove(player);
      _scores.remove(player);
    });
  }

  void _startGame() {
    if (_players.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف لاعبين على الأقل لبدء اللعبة.')),
      );
      return;
    }
    _startRound();
  }

  void _startRound() {
    _timer?.cancel();
    setState(() {
      _round += 1;
      _currentPlayerIndex = 0;
      _roundAnswers.clear();
      _letter = _letters[_random.nextInt(_letters.length)];
      _stage = _GameStage.playing;
      _clearAnswers();
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        _submitCurrentPlayer(autoSubmit: true);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  void _clearAnswers() {
    for (final controller in _answerControllers.values) {
      controller.clear();
    }
  }

  void _submitCurrentPlayer({bool autoSubmit = false}) {
    _timer?.cancel();
    final player = _players[_currentPlayerIndex];
    final answers = <String, String>{
      for (final category in _categories)
        category: _answerControllers[category]!.text.trim(),
    };
    _roundAnswers[player] = answers;

    if (_currentPlayerIndex < _players.length - 1) {
      setState(() {
        _currentPlayerIndex += 1;
        _clearAnswers();
      });
      _startTimer();
      if (autoSubmit && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('انتهى وقت $player، انتقل الدور للاعب التالي.')),
        );
      }
      return;
    }

    _finishRound();
  }

  String _normalize(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[إأآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .toLowerCase();
  }

  bool _startsWithLetter(String answer) {
    if (answer.trim().isEmpty) return false;
    return _normalize(answer).startsWith(_normalize(_letter));
  }

  void _finishRound() {
    final roundPoints = <String, int>{};

    for (final player in _players) {
      int total = 0;
      for (final category in _categories) {
        final answer = _roundAnswers[player]?[category] ?? '';
        if (!_startsWithLetter(answer)) continue;

        final normalized = _normalize(answer);
        int matchingPlayers = 0;
        for (final other in _players) {
          final otherAnswer = _roundAnswers[other]?[category] ?? '';
          if (_normalize(otherAnswer) == normalized && normalized.isNotEmpty) {
            matchingPlayers += 1;
          }
        }
        total += matchingPlayers > 1 ? 5 : 10;
      }
      roundPoints[player] = total;
      _scores[player] = (_scores[player] ?? 0) + total;
    }

    setState(() {
      _history.insert(
        0,
        _RoundResult(
          number: _round,
          letter: _letter,
          points: Map<String, int>.from(roundPoints),
        ),
      );
      _stage = _GameStage.result;
    });
  }

  void _resetGame() {
    _timer?.cancel();
    setState(() {
      _round = 0;
      _currentPlayerIndex = 0;
      _history.clear();
      _roundAnswers.clear();
      for (final player in _players) {
        _scores[player] = 0;
      }
      _stage = _GameStage.setup;
      _clearAnswers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اسم • حيوان • جماد'),
        actions: [
          if (_stage != _GameStage.setup)
            IconButton(
              tooltip: 'إعادة اللعبة',
              onPressed: _resetGame,
              icon: const Icon(Icons.restart_alt),
            ),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: switch (_stage) {
            _GameStage.setup => _buildSetup(),
            _GameStage.playing => _buildPlaying(),
            _GameStage.result => _buildResult(),
          },
        ),
      ),
    );
  }

  Widget _buildSetup() {
    return ListView(
      key: const ValueKey('setup'),
      padding: const EdgeInsets.all(18),
      children: [
        const Icon(Icons.edit_note, size: 78, color: Color(0xFF7B2CBF)),
        const SizedBox(height: 8),
        const Text(
          'أضف أسماء اللاعبين',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'كل لاعب يكتب إجابة تبدأ بالحرف المختار. الإجابة المنفردة 10 نقاط، والمكررة 5 نقاط.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _playerNameController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addPlayer(),
                decoration: const InputDecoration(
                  labelText: 'اسم اللاعب',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_add_alt_1),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: _addPlayer,
              child: const Text('إضافة'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._players.map(
          (player) => Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('${_players.indexOf(player) + 1}')),
              title: Text(player),
              trailing: IconButton(
                onPressed: () => _removePlayer(player),
                icon: const Icon(Icons.close),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _startGame,
          icon: const Icon(Icons.play_arrow),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Text('ابدأ اللعبة'),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaying() {
    final player = _players[_currentPlayerIndex];
    return ListView(
      key: ValueKey('playing-$_round-$_currentPlayerIndex'),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: _InfoCard(label: 'الجولة', value: '$_round')),
            const SizedBox(width: 8),
            Expanded(child: _InfoCard(label: 'الدور', value: player)),
            const SizedBox(width: 8),
            Expanded(
              child: _InfoCard(
                label: 'الوقت',
                value: '$_secondsLeft',
                danger: _secondsLeft <= 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1F6F63), Color(0xFF7B2CBF)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              const Text('الحرف المطلوب', style: TextStyle(color: Colors.white70)),
              Text(
                _letter,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ..._categories.map(
          (category) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: _answerControllers[category],
              decoration: InputDecoration(
                labelText: category,
                hintText: '$category يبدأ بحرف $_letter',
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: _submitCurrentPlayer,
          icon: const Icon(Icons.check_circle_outline),
          label: Text(
            _currentPlayerIndex == _players.length - 1
                ? 'إنهاء الجولة وحساب النقاط'
                : 'تثبيت الإجابات وتمرير الجهاز',
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final ranking = _players.toList()
      ..sort((a, b) => (_scores[b] ?? 0).compareTo(_scores[a] ?? 0));
    final currentRound = _history.first;

    return ListView(
      key: ValueKey('result-$_round'),
      padding: const EdgeInsets.all(16),
      children: [
        const Icon(Icons.emoji_events, size: 70, color: Color(0xFFFF9F1C)),
        Text(
          'نتيجة الجولة $_round — حرف $_letter',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 14),
        ...ranking.asMap().entries.map((entry) {
          final player = entry.value;
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('${entry.key + 1}')),
              title: Text(player),
              subtitle: Text('+${currentRound.points[player] ?? 0} هذه الجولة'),
              trailing: Text(
                '${_scores[player] ?? 0}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _startRound,
          icon: const Icon(Icons.refresh),
          label: const Text('جولة جديدة'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _resetGame,
          icon: const Icon(Icons.home_outlined),
          label: const Text('العودة لإعداد اللاعبين'),
        ),
        if (_history.length > 1) ...[
          const SizedBox(height: 18),
          const Text('سجل الجولات', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._history.skip(1).map(
                (result) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.history),
                  title: Text('الجولة ${result.number} — حرف ${result.letter}'),
                  subtitle: Text(
                    result.points.entries
                        .map((entry) => '${entry.key}: ${entry.value}')
                        .join(' • '),
                  ),
                ),
              ),
        ],
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.label,
    required this.value,
    this.danger = false,
  });

  final String label;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.red : const Color(0xFF1F6F63);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

enum _GameStage { setup, playing, result }

class _RoundResult {
  const _RoundResult({
    required this.number,
    required this.letter,
    required this.points,
  });

  final int number;
  final String letter;
  final Map<String, int> points;
}
