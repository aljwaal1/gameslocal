import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/network/local_network_core.dart';
import '../../core/network/network_message.dart';
import 'iphone_web_bridge.dart';

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
  static const int _roundSeconds = 60;
  static const List<String> _letters = <String>[
    'ا','ب','ت','ث','ج','ح','خ','د','ذ','ر','ز','س','ش','ص','ض','ط','ظ','ع','غ','ف','ق','ك','ل','م','ن','ه','و','ي'
  ];
  static const List<String> _categories = <String>[
    'اسم','حيوان','جماد','نبات','بلاد'
  ];

  final TextEditingController _nameController = TextEditingController();
  final Map<String, TextEditingController> _answers =
      <String, TextEditingController>{};
  final Random _random = Random();

  LocalNetworkCore? _network;
  IphoneWebBridge? _webBridge;
  StreamSubscription<NetworkMessage>? _messageSub;
  StreamSubscription<LocalNetworkState>? _stateSub;
  StreamSubscription<List<IphoneWebPlayer>>? _webPlayersSub;
  StreamSubscription<IphoneWebSubmission>? _webSubmitSub;
  Timer? _timer;

  _Stage _stage = _Stage.profile;
  String _playerName = '';
  String _letter = '';
  String _webUrl = '';
  int _round = 0;
  int _secondsLeft = _roundSeconds;
  bool _submitted = false;
  bool _finishing = false;

  final Map<String, IphoneWebPlayer> _webPlayers = <String, IphoneWebPlayer>{};
  final Map<String, String> _playerNames = <String, String>{};
  final Map<String, int> _scores = <String, int>{};
  final Map<String, Map<String, String>> _roundAnswers =
      <String, Map<String, String>>{};
  Map<String, Map<String, String>> _lastAnswers =
      <String, Map<String, String>>{};
  Map<String, int> _lastPoints = <String, int>{};
  Set<String> _expectedIds = <String>{};

  bool get _isHost => _network?.state.mode == LocalNetworkMode.host;
  String get _myId => _network?.localPlayerId ?? 'offline';
  int get _totalPlayers =>
      (_network?.state.players.length ?? 0) + _webPlayers.length;

  @override
  void initState() {
    super.initState();
    for (final String category in _categories) {
      _answers[category] = TextEditingController();
    }
    _network = LocalNetworkCore.activeFor(_gameId);
    final LocalNetworkCore? network = _network;
    if (network != null) {
      for (final LocalPlayer player in network.state.players) {
        _playerNames[player.id] = player.name;
        _scores[player.id] = 0;
      }
      _messageSub = network.messages.listen(_handleNetworkMessage);
      _stateSub = network.stateStream.listen((LocalNetworkState state) {
        for (final LocalPlayer player in state.players) {
          _playerNames[player.id] = player.name;
          _scores.putIfAbsent(player.id, () => 0);
        }
        if (mounted) setState(() {});
      });
      if (_isHost) _startWebBridge();
    }
  }

  Future<void> _startWebBridge() async {
    final IphoneWebBridge bridge = IphoneWebBridge();
    _webBridge = bridge;
    _webPlayersSub = bridge.players.listen((List<IphoneWebPlayer> players) {
      _webPlayers
        ..clear()
        ..addEntries(players.map((IphoneWebPlayer p) => MapEntry(p.id, p)));
      for (final IphoneWebPlayer player in players) {
        _playerNames[player.id] = player.name;
        _scores.putIfAbsent(player.id, () => 0);
      }
      if (mounted) setState(() {});
    });
    _webSubmitSub = bridge.submissions.listen(_handleWebSubmission);
    try {
      final String url = await bridge.start();
      if (mounted) setState(() => _webUrl = url);
    } catch (_) {
      if (mounted) setState(() => _webUrl = 'تعذر تشغيل رابط الآيفون');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageSub?.cancel();
    _stateSub?.cancel();
    _webPlayersSub?.cancel();
    _webSubmitSub?.cancel();
    _webBridge?.dispose();
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
    if (!_isHost || _totalPlayers < 2 || _finishing) return;
    final LocalNetworkCore? network = _network;
    if (network == null) return;

    final List<Map<String, String>> playerData = <Map<String, String>>[];
    for (final LocalPlayer player in network.state.players) {
      _playerNames[player.id] = player.name;
      _scores.putIfAbsent(player.id, () => 0);
      playerData.add(<String, String>{
        'id': player.id,
        'name': _playerNames[player.id] ?? player.name,
      });
    }
    for (final IphoneWebPlayer player in _webPlayers.values) {
      playerData.add(<String, String>{'id': player.id, 'name': player.name});
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'action': 'categories_round_start',
      'round': _round + 1,
      'letter': _letters[_random.nextInt(_letters.length)],
      'seconds': _roundSeconds,
      'players': playerData,
    };
    network.sendMove(payload, senderId: _myId);
    _webBridge?.broadcast(<String, dynamic>{
      'type': 'round_start',
      'round': payload['round'],
      'letter': payload['letter'],
      'seconds': _roundSeconds,
    });
  }

  void _handleNetworkMessage(NetworkMessage message) {
    if (!mounted || message.type != NetworkMessageType.move) return;
    final String action = (message.payload['action'] ?? '').toString();
    if (action == 'categories_round_start') {
      _receiveRoundStart(message.payload);
    } else if (action == 'categories_submit' && _isHost) {
      _receiveSubmission(
        playerId: message.senderId,
        playerName: (message.payload['playerName'] ?? '').toString(),
        round: (message.payload['round'] as num?)?.toInt() ?? 0,
        rawAnswers: message.payload['answers'],
      );
    } else if (action == 'categories_results') {
      _receiveResults(message.payload);
    }
  }

  void _handleWebSubmission(IphoneWebSubmission submission) {
    if (!_isHost) return;
    _receiveSubmission(
      playerId: submission.playerId,
      playerName: submission.playerName,
      round: submission.round,
      rawAnswers: submission.answers,
    );
  }

  void _receiveRoundStart(Map<String, dynamic> payload) {
    _timer?.cancel();
    final List<dynamic> rawPlayers =
        payload['players'] as List<dynamic>? ?? <dynamic>[];
    final Set<String> expected = <String>{};
    for (final dynamic item in rawPlayers) {
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
      _secondsLeft = (payload['seconds'] as num?)?.toInt() ?? _roundSeconds;
      _expectedIds = expected;
      _roundAnswers.clear();
      _submitted = false;
      _finishing = false;
      _stage = _Stage.playing;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        if (!_submitted) _submitAnswers();
        if (_isHost) {
          Future<void>.delayed(const Duration(seconds: 2), _finishRound);
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

  void _receiveSubmission({
    required String playerId,
    required String playerName,
    required int round,
    required dynamic rawAnswers,
  }) {
    if (round != _round || _stage != _Stage.playing) return;
    final Map<dynamic, dynamic> raw =
        rawAnswers is Map ? rawAnswers : <dynamic, dynamic>{};
    _roundAnswers[playerId] = <String, String>{
      for (final String category in _categories)
        category: (raw[category] ?? '').toString(),
    };
    if (playerName.trim().isNotEmpty) _playerNames[playerId] = playerName.trim();
    if (_expectedIds.isNotEmpty && _expectedIds.every(_roundAnswers.containsKey)) {
      _finishRound();
    } else if (mounted) {
      setState(() {});
    }
  }

  String _normalize(String value) => value
      .trim()
      .replaceAll(RegExp(r'[إأآ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .toLowerCase();

  bool _isValid(String answer) =>
      answer.trim().isNotEmpty && _normalize(answer).startsWith(_normalize(_letter));

  int _pointsFor(String id, String category) {
    final String answer = _roundAnswers[id]?[category] ?? '';
    if (!_isValid(answer)) return 0;
    final String normalized = _normalize(answer);
    final int duplicates = _expectedIds.where((String other) {
      return _normalize(_roundAnswers[other]?[category] ?? '') == normalized;
    }).length;
    return duplicates > 1 ? 5 : 10;
  }

  void _finishRound() {
    if (!_isHost || _stage != _Stage.playing || _finishing) return;
    _finishing = true;
    _timer?.cancel();
    for (final String id in _expectedIds) {
      _roundAnswers.putIfAbsent(
        id,
        () => <String, String>{for (final String c in _categories) c: ''},
      );
    }
    final Map<String, int> points = <String, int>{};
    for (final String id in _expectedIds) {
      int total = 0;
      for (final String category in _categories) {
        total += _pointsFor(id, category);
      }
      points[id] = total;
      _scores[id] = (_scores[id] ?? 0) + total;
    }
    final Map<String, dynamic> payload = <String, dynamic>{
      'action': 'categories_results',
      'round': _round,
      'letter': _letter,
      'points': points,
      'scores': _scores,
      'names': _playerNames,
      'answers': _roundAnswers,
    };
    _network?.sendMove(payload, senderId: _myId);
    _webBridge?.broadcast(<String, dynamic>{
      'type': 'results',
      'round': _round,
      'letter': _letter,
      'scores': _scores,
      'names': _playerNames,
      'answers': _roundAnswers,
    });
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
    rawPoints.forEach((dynamic k, dynamic v) => points[k.toString()] = (v as num?)?.toInt() ?? 0);
    rawScores.forEach((dynamic k, dynamic v) => scores[k.toString()] = (v as num?)?.toInt() ?? 0);
    rawNames.forEach((dynamic k, dynamic v) => names[k.toString()] = v.toString());
    rawAnswers.forEach((dynamic id, dynamic value) {
      final Map<dynamic, dynamic> item = value is Map ? value : <dynamic, dynamic>{};
      answers[id.toString()] = <String, String>{
        for (final String c in _categories) c: (item[c] ?? '').toString(),
      };
    });
    setState(() {
      _lastPoints = points;
      _lastAnswers = answers;
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
      return const Scaffold(body: Center(child: Text('أنشئ غرفة أولًا.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('اسم • حيوان • جماد')),
      body: SafeArea(
        child: switch (_stage) {
          _Stage.profile => _profile(),
          _Stage.waiting => _waiting(),
          _Stage.playing => _playing(),
          _Stage.results => _results(),
        },
      ),
    );
  }

  Widget _profile() => ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          const Icon(Icons.edit_note, size: 88, color: Color(0xFF6F2DBD)),
          const SizedBox(height: 16),
          const Text('اكتب اسمك', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 18),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'اسم اللاعب', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _saveName, child: const Text('دخول اللعبة')),
        ],
      );

  Widget _waiting() {
    final List<LocalPlayer> nativePlayers = _network!.state.players;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (_isHost)
          Card(
            color: const Color(0xFFEDE4FF),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: <Widget>[
                const Text('رابط دخول الآيفون',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                SelectableText(_webUrl.isEmpty ? 'جاري تجهيز الرابط...' : _webUrl,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('افتح الرابط من Safari على نفس Wi‑Fi أو Hotspot ثم اختر إضافة إلى الشاشة الرئيسية.'),
              ]),
            ),
          ),
        const SizedBox(height: 8),
        Text('اللاعبون: $_totalPlayers', textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        ...nativePlayers.map((LocalPlayer p) => ListTile(
              leading: Icon(p.isHost ? Icons.star : Icons.android),
              title: Text(_playerNames[p.id] ?? p.name),
              subtitle: const Text('أندرويد'),
            )),
        ..._webPlayers.values.map((IphoneWebPlayer p) => ListTile(
              leading: const Icon(Icons.phone_iphone),
              title: Text(p.name),
              subtitle: const Text('آيفون / Safari'),
            )),
        const SizedBox(height: 12),
        if (_isHost)
          FilledButton.icon(
            onPressed: _totalPlayers >= 2 ? _startRound : null,
            icon: const Icon(Icons.play_arrow),
            label: Text(_totalPlayers >= 2 ? 'ابدأ الحرف' : 'بانتظار لاعب آخر'),
          )
        else
          const Text('بانتظار المضيف لبدء الحرف...', textAlign: TextAlign.center),
      ],
    );
  }

  Widget _playing() => ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Row(children: <Widget>[
            Expanded(child: _info('الجولة', '$_round')),
            const SizedBox(width: 8),
            Expanded(child: _info('الحرف', _letter)),
            const SizedBox(width: 8),
            Expanded(child: _info('الوقت', '$_secondsLeft')),
          ]),
          const SizedBox(height: 14),
          ..._categories.map((String c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: _answers[c],
                  enabled: !_submitted,
                  decoration: InputDecoration(
                    labelText: c,
                    hintText: '$c يبدأ بحرف $_letter',
                    border: const OutlineInputBorder(),
                  ),
                ),
              )),
          FilledButton.icon(
            onPressed: _submitted ? null : _submitAnswers,
            icon: const Icon(Icons.send),
            label: Text(_submitted ? 'تم التسليم' : 'تسليم الإجابات'),
          ),
          if (_isHost) Padding(
            padding: const EdgeInsets.all(12),
            child: Text('سلّم ${_roundAnswers.length} من ${_expectedIds.length}',
                textAlign: TextAlign.center),
          ),
        ],
      );

  Widget _results() {
    final List<String> ranking = _scores.keys.toList()
      ..sort((String a, String b) => (_scores[b] ?? 0).compareTo(_scores[a] ?? 0));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text('نتائج حرف $_letter', textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        ..._categories.map((String category) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(category, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                    ...ranking.map((String id) => ListTile(
                          dense: true,
                          title: Text(_playerNames[id] ?? 'لاعب'),
                          subtitle: Text(_lastAnswers[id]?[category]?.isNotEmpty == true
                              ? _lastAnswers[id]![category]!
                              : '—'),
                        )),
                  ],
                ),
              ),
            )),
        const SizedBox(height: 10),
        ...ranking.asMap().entries.map((MapEntry<int, String> e) => Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${e.key + 1}')),
                title: Text(_playerNames[e.value] ?? 'لاعب'),
                subtitle: Text('+${_lastPoints[e.value] ?? 0}'),
                trailing: Text('${_scores[e.value] ?? 0}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ),
            )),
        if (_isHost)
          FilledButton.icon(
            onPressed: _totalPlayers >= 2 ? _startRound : null,
            icon: const Icon(Icons.refresh),
            label: const Text('حرف جديد'),
          )
        else
          const Text('بانتظار المضيف للحرف التالي', textAlign: TextAlign.center),
      ],
    );
  }

  Widget _info(String label, String value) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEDE4FF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: <Widget>[
          Text(label),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        ]),
      );
}
