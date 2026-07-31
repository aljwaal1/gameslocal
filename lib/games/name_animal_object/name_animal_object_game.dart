import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/network/local_network_core.dart';
import '../../core/network/network_message.dart';

class NameAnimalObjectGameScreen extends StatefulWidget {
  const NameAnimalObjectGameScreen({super.key});

  @override
  State<NameAnimalObjectGameScreen> createState() =>
      _NameAnimalObjectGameScreenState();
}

enum _Stage { profile, waiting, playing, results }

class _NameAnimalObjectGameScreenState
    extends State<NameAnimalObjectGameScreen> {
  static const String _gameId = 'name_animal_object';
  static const int _minimumPlayers = 2;
  static const int _roundSeconds = 60;
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

  final TextEditingController _nameController = TextEditingController();
  final Map<String, TextEditingController> _answers =
      <String, TextEditingController>{};
  final Random _random = Random();

  LocalNetworkCore? _network;
  StreamSubscription<NetworkMessage>? _messageSubscription;
  StreamSubscription<LocalNetworkState>? _stateSubscription;
  Timer? _timer;

  _Stage _stage = _Stage.profile;
  int _round = 0;
  int _secondsLeft = _roundSeconds;
  String _letter = '';
  String _playerName = '';
  bool _submitted = false;
  bool _finishing = false;
  Set<String> _expectedPlayerIds = <String>{};
  final Map<String, Map<String, String>> _roundAnswers =
      <String, Map<String, String>>{};
  Map<String, Map<String, String>> _lastRoundAnswers =
      <String, Map<String, String>>{};
  final Map<String, String> _playerNames = <String, String>{};
  final Map<String, int> _scores = <String, int>{};
  Map<String, int> _lastRoundPoints = <String, int>{};

  bool get _isHost => _network?.state.mode == LocalNetworkMode.host;
  String get _myId => _network?.localPlayerId ?? 'offline';

  @override
  void initState() {
    super.initState();
    for (final String category in _categories) {
      _answers[category] = TextEditingController();
    }
    _network = LocalNetworkCore.activeFor(_gameId);
    final LocalNetworkCore? network = _network;
    if (network != null) {
      _messageSubscription = network.messages.listen(_handleMessage);
      _stateSubscription = network.stateStream.listen((_) {
        if (mounted) setState(() {});
      });
      for (final LocalPlayer player in network.state.players) {
        _playerNames[player.id] = player.name;
        _scores[player.id] = 0;
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageSubscription?.cancel();
    _stateSubscription?.cancel();
    _nameController.dispose();
    for (final TextEditingController controller in _answers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _saveName() {
    final String name = _nameController.text.trim();
    if (name.isEmpty) return;
    _playerName = name;
    _playerNames[_myId] = name;
    _scores.putIfAbsent(_myId, () => 0);
    _network?.updateLocalPlayerName(name);
    setState(() => _stage = _Stage.waiting);
  }

  void _startRound() {
    if (!_isHost || _finishing) return;
    final LocalNetworkCore? network = _network;
    if (network == null) return;
    final List<LocalPlayer> players = network.state.players;
    if (players.length < _minimumPlayers) return;

    for (final LocalPlayer player in players) {
      _playerNames[player.id] = player.name;
      _scores.putIfAbsent(player.id, () => 0);
    }

    final List<Map<String, String>> playerData = players
        .map((LocalPlayer player) => <String, String>{
              'id': player.id,
              'name': _playerNames[player.id] ?? player.name,
            })
        .toList(growable: false);

    network.sendMove(<String, dynamic>{
      'action': 'categories_round_start',
      'round': _round + 1,
      'letter': _letters[_random.nextInt(_letters.length)],
      'seconds': _roundSeconds,
      'players': playerData,
    }, senderId: _myId);
  }

  void _handleMessage(NetworkMessage message) {
    if (!mounted || message.type != NetworkMessageType.move) return;
    final String action = (message.payload['action'] ?? '').toString();
    switch (action) {
      case 'categories_round_start':
        _receiveRoundStart(message.payload);
        break;
      case 'categories_submit':
        if (_isHost) _receiveSubmission(message);
        break;
      case 'categories_results':
        _receiveResults(message.payload);
        break;
    }
  }

  void _receiveRoundStart(Map<String, dynamic> payload) {
    _timer?.cancel();
    final List<dynamic> players =
        payload['players'] as List<dynamic>? ?? <dynamic>[];
    final Set<String> expected = <String>{};
    for (final dynamic item in players) {
      if (item is! Map) continue;
      final String id = (item['id'] ?? '').toString();
      final String name = (item['name'] ?? '').toString();
      if (id.isEmpty) continue;
      expected.add(id);
      _playerNames[id] = name.isEmpty ? 'لاعب' : name;
      _scores.putIfAbsent(id, () => 0);
    }
    for (final TextEditingController controller in _answers.values) {
      controller.clear();
    }
    setState(() {
      _round = (payload['round'] as num?)?.toInt() ?? _round + 1;
      _letter = (payload['letter'] ?? '').toString();
      _secondsLeft =
          (payload['seconds'] as num?)?.toInt() ?? _roundSeconds;
      _expectedPlayerIds = expected;
      _roundAnswers.clear();
      _submitted = false;
      _finishing = false;
      _stage = _Stage.playing;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        if (!_submitted) _submitAnswers();
        if (_isHost) {
          Future<void>.delayed(const Duration(seconds: 2), () {
            if (mounted && _stage == _Stage.playing) _finishRound();
          });
        }
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  void _submitAnswers() {
    if (_submitted || _stage != _Stage.playing) return;
    final Map<String, String> values = <String, String>{
      for (final String category in _categories)
        category: _answers[category]!.text.trim(),
    };
    setState(() => _submitted = true);
    _network?.sendMove(<String, dynamic>{
      'action': 'categories_submit',
      'round': _round,
      'playerName': _playerName,
      'answers': values,
    }, senderId: _myId);
  }

  void _receiveSubmission(NetworkMessage message) {
    if ((message.payload['round'] as num?)?.toInt() != _round) return;
    final Map<dynamic, dynamic> raw =
        message.payload['answers'] as Map<dynamic, dynamic>? ??
            <dynamic, dynamic>{};
    _roundAnswers[message.senderId] = <String, String>{
      for (final String category in _categories)
        category: (raw[category] ?? '').toString(),
    };
    final String name =
        (message.payload['playerName'] ?? '').toString().trim();
    if (name.isNotEmpty) _playerNames[message.senderId] = name;

    if (_expectedPlayerIds.isNotEmpty &&
        _expectedPlayerIds.every(_roundAnswers.containsKey)) {
      _finishRound();
    } else if (mounted) {
      setState(() {});
    }
  }

  String _normalize(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[إأآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .toLowerCase();
  }

  bool _isValid(String answer) {
    return answer.trim().isNotEmpty &&
        _normalize(answer).startsWith(_normalize(_letter));
  }

  int _answerPoints(String playerId, String category) {
    final String answer = _roundAnswers[playerId]?[category] ?? '';
    if (!_isValid(answer)) return 0;
    final String normalized = _normalize(answer);
    final int duplicates = _expectedPlayerIds.where((String otherId) {
      return _normalize(_roundAnswers[otherId]?[category] ?? '') == normalized;
    }).length;
    return duplicates > 1 ? 5 : 10;
  }

  void _finishRound() {
    if (!_isHost || _stage != _Stage.playing || _finishing) return;
    _finishing = true;
    _timer?.cancel();

    for (final String id in _expectedPlayerIds) {
      _roundAnswers.putIfAbsent(
        id,
        () => <String, String>{for (final String c in _categories) c: ''},
      );
    }

    final Map<String, int> points = <String, int>{};
    for (final String id in _expectedPlayerIds) {
      int total = 0;
      for (final String category in _categories) {
        total += _answerPoints(id, category);
      }
      points[id] = total;
      _scores[id] = (_scores[id] ?? 0) + total;
    }

    _network?.sendMove(<String, dynamic>{
      'action': 'categories_results',
      'round': _round,
      'letter': _letter,
      'points': points,
      'scores': _scores,
      'names': _playerNames,
      'answers': _roundAnswers,
    }, senderId: _myId);
  }

  void _receiveResults(Map<String, dynamic> payload) {
    _timer?.cancel();
    final Map<dynamic, dynamic> rawPoints =
        payload['points'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{};
    final Map<dynamic, dynamic> rawScores =
        payload['scores'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{};
    final Map<dynamic, dynamic> rawNames =
        payload['names'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{};
    final Map<dynamic, dynamic> rawAnswers =
        payload['answers'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{};

    final Map<String, int> points = <String, int>{};
    final Map<String, int> scores = <String, int>{};
    final Map<String, String> names = <String, String>{};
    final Map<String, Map<String, String>> answers =
        <String, Map<String, String>>{};

    rawPoints.forEach((dynamic key, dynamic value) {
      points[key.toString()] = (value as num?)?.toInt() ?? 0;
    });
    rawScores.forEach((dynamic key, dynamic value) {
      scores[key.toString()] = (value as num?)?.toInt() ?? 0;
    });
    rawNames.forEach((dynamic key, dynamic value) {
      names[key.toString()] = value.toString();
    });
    rawAnswers.forEach((dynamic playerId, dynamic value) {
      final Map<dynamic, dynamic> playerRaw =
          value is Map ? value : <dynamic, dynamic>{};
      answers[playerId.toString()] = <String, String>{
        for (final String category in _categories)
          category: (playerRaw[category] ?? '').toString(),
      };
    });

    setState(() {
      _lastRoundPoints = points;
      _lastRoundAnswers = answers;
      _scores
        ..clear()
        ..addAll(scores);
      _playerNames.addAll(names);
      _finishing = false;
      _stage = _Stage.results;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_network == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('اسم • حيوان • جماد')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'هذه اللعبة تعمل عبر الشبكة المحلية فقط. ارجع وأنشئ غرفة أو انضم إلى غرفة.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('اسم • حيوان • جماد')),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: switch (_stage) {
            _Stage.profile => _buildProfile(),
            _Stage.waiting => _buildWaiting(),
            _Stage.playing => _buildPlaying(),
            _Stage.results => _buildResults(),
          },
        ),
      ),
    );
  }

  Widget _buildProfile() {
    return ListView(
      key: const ValueKey<String>('profile'),
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        const Icon(Icons.badge_outlined, size: 82, color: Color(0xFF7B2CBF)),
        const SizedBox(height: 12),
        Text(
          _isHost
              ? 'اكتب اسمك للدخول كمضيف ولاعب'
              : 'اكتب اسمك الذي سيظهر لبقية اللاعبين',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 22),
        TextField(
          controller: _nameController,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _saveName(),
          decoration: const InputDecoration(
            labelText: 'اسم اللاعب',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _saveName,
          icon: const Icon(Icons.check),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Text('دخول اللعبة'),
          ),
        ),
      ],
    );
  }

  Widget _buildWaiting() {
    final List<LocalPlayer> players = _network!.state.players;
    final bool canStart = players.length >= _minimumPlayers;
    return ListView(
      key: const ValueKey<String>('waiting'),
      padding: const EdgeInsets.all(18),
      children: <Widget>[
        Icon(
          _isHost ? Icons.wifi_tethering : Icons.hourglass_top,
          size: 76,
          color: const Color(0xFF1F6F63),
        ),
        const SizedBox(height: 10),
        Text(
          _isHost ? 'أنت المضيف وأحد اللاعبين' : 'بانتظار المضيف',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          'اللاعبون: ${players.length}/12 — الحد الأدنى: $_minimumPlayers',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ...players.map(
          (LocalPlayer player) => Card(
            child: ListTile(
              leading: Icon(
                player.isHost ? Icons.workspace_premium : Icons.person,
              ),
              title: Text(_playerNames[player.id] ?? player.name),
              subtitle: Text(player.isHost ? 'المضيف • لاعب' : 'لاعب متصل'),
              trailing: const Icon(Icons.check_circle, color: Color(0xFF1F6F63)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_isHost)
          FilledButton.icon(
            onPressed: canStart ? _startRound : null,
            icon: const Icon(Icons.play_arrow),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Text(canStart ? 'ابدأ الجولة للجميع' : 'بانتظار لاعب آخر'),
            ),
          )
        else
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'ستبدأ شاشة الحرف تلقائيًا عندما يبدأ المضيف الجولة.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaying() {
    return ListView(
      key: ValueKey<String>('playing-$_round'),
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: _InfoCard(label: 'الجولة', value: '$_round')),
            const SizedBox(width: 8),
            Expanded(child: _InfoCard(label: 'الحرف', value: _letter)),
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
        ..._categories.map(
          (String category) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: _answers[category],
              enabled: !_submitted,
              decoration: InputDecoration(
                labelText: category,
                hintText: '$category يبدأ بحرف $_letter',
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: _submitted ? null : _submitAnswers,
          icon: Icon(_submitted ? Icons.hourglass_top : Icons.send),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Text(
              _submitted ? 'تم التسليم — بانتظار الآخرين' : 'تسليم الإجابات',
            ),
          ),
        ),
        if (_isHost) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            'سلّم ${_roundAnswers.length} من ${_expectedPlayerIds.length} لاعبين',
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildResults() {
    final List<String> ranking = _scores.keys.toList()
      ..sort((String a, String b) =>
          (_scores[b] ?? 0).compareTo(_scores[a] ?? 0));

    return ListView(
      key: ValueKey<String>('results-$_round'),
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Icon(Icons.emoji_events, size: 70, color: Color(0xFFFF9F1C)),
        Text(
          'إجابات حرف $_letter',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'الجولة $_round — ظهرت الإجابات بعد انتهاء جميع اللاعبين',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ..._categories.map((String category) => _AnswerCategoryCard(
              category: category,
              playerIds: ranking,
              names: _playerNames,
              answers: _lastRoundAnswers,
              pointsFor: (String playerId) {
                final String answer =
                    _lastRoundAnswers[playerId]?[category] ?? '';
                if (answer.trim().isEmpty ||
                    !_normalize(answer).startsWith(_normalize(_letter))) {
                  return 0;
                }
                final String normalized = _normalize(answer);
                final int duplicates = ranking.where((String otherId) {
                  return _normalize(
                        _lastRoundAnswers[otherId]?[category] ?? '',
                      ) ==
                      normalized;
                }).length;
                return duplicates > 1 ? 5 : 10;
              },
            )),
        const SizedBox(height: 12),
        const Text(
          'الترتيب العام',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        ...ranking.asMap().entries.map((MapEntry<int, String> entry) {
          final String id = entry.value;
          return Card(
            color: id == _myId ? const Color(0xFFE8F5F2) : null,
            child: ListTile(
              leading: CircleAvatar(child: Text('${entry.key + 1}')),
              title: Text(_playerNames[id] ?? 'لاعب'),
              subtitle: Text('+${_lastRoundPoints[id] ?? 0} في هذه الجولة'),
              trailing: Text(
                '${_scores[id] ?? 0}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
          );
        }),
        const SizedBox(height: 18),
        if (_isHost)
          FilledButton.icon(
            onPressed: _network!.state.players.length >= _minimumPlayers
                ? _startRound
                : null,
            icon: const Icon(Icons.refresh),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 13),
              child: Text('حرف جديد للجميع'),
            ),
          )
        else
          const Text(
            'بانتظار المضيف لبدء الحرف التالي.',
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

class _AnswerCategoryCard extends StatelessWidget {
  const _AnswerCategoryCard({
    required this.category,
    required this.playerIds,
    required this.names,
    required this.answers,
    required this.pointsFor,
  });

  final String category;
  final List<String> playerIds;
  final Map<String, String> names;
  final Map<String, Map<String, String>> answers;
  final int Function(String playerId) pointsFor;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              category,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const Divider(),
            ...playerIds.map((String id) {
              final String answer = answers[id]?[category] ?? '';
              final int points = pointsFor(id);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      flex: 2,
                      child: Text(
                        names[id] ?? 'لاعب',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        answer.trim().isEmpty ? 'بدون إجابة' : answer,
                        style: TextStyle(
                          color: points == 0 ? Colors.red.shade700 : null,
                        ),
                      ),
                    ),
                    Container(
                      width: 42,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: points == 10
                            ? const Color(0xFFE8F5E9)
                            : points == 5
                                ? const Color(0xFFFFF4D6)
                                : const Color(0xFFFFE4E6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$points',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: danger ? const Color(0xFFFFE4E6) : const Color(0xFFE8F5F2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: danger
                  ? const Color(0xFFC1121F)
                  : const Color(0xFF1F6F63),
            ),
          ),
        ],
      ),
    );
  }
}
