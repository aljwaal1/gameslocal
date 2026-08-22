import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/audio_feedback.dart';
import '../../core/pregame_qr_lobby.dart';
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
    'ا',
    'ب',
    'ت',
    'ث',
    'ج',
    'ح',
    'خ',
    'د',
    'ذ',
    'ر',
    'ز',
    'س',
    'ش',
    'ص',
    'ض',
    'ط',
    'ظ',
    'ع',
    'غ',
    'ف',
    'ق',
    'ك',
    'ل',
    'م',
    'ن',
    'ه',
    'و',
    'ي',
  ];
  static const List<String> _categories = <String>[
    'اسم',
    'حيوان',
    'جماد',
    'نبات',
    'بلاد',
  ];

  final _nameController = TextEditingController();
  final Map<String, TextEditingController> _answers =
      <String, TextEditingController>{};
  final Random _random = Random();
  LocalNetworkCore? _network;
  IphoneWebBridge? _webBridge;
  StreamSubscription<NetworkMessage>? _messageSub;
  StreamSubscription<LocalNetworkState>? _stateSub;
  StreamSubscription<List<IphoneWebPlayer>>? _webPlayersSub;
  StreamSubscription<IphoneWebEvent>? _webEventSub;
  Timer? _timer;

  _Stage _stage = _Stage.profile;
  String _playerName = '';
  String _letter = '';
  String _webUrl = '';
  int _round = 0;
  int _secondsLeft = _roundSeconds;
  bool _submitted = false;
  bool _finishing = false;
  bool _showNetworkQrLobby = true;
  final Map<String, IphoneWebPlayer> _webPlayers = <String, IphoneWebPlayer>{};
  final Map<String, String> _playerNames = <String, String>{};
  final Map<String, int> _scores = <String, int>{};
  final Map<String, Map<String, String>> _roundAnswers =
      <String, Map<String, String>>{};
  Map<String, Map<String, String>> _lastAnswers =
      <String, Map<String, String>>{};
  Map<String, int> _lastPoints = <String, int>{};
  Set<String> _expectedIds = <String>{};
  final Map<String, Map<String, dynamic>> _proposals =
      <String, Map<String, dynamic>>{};

  bool get _isHost => _network?.state.mode == LocalNetworkMode.host;
  String get _myId => _network?.localPlayerId ?? 'offline';
  int get _totalPlayers =>
      (_network?.state.players.length ?? 0) + _webPlayers.length;

  @override
  void initState() {
    super.initState();
    for (final c in _categories) {
      _answers[c] = TextEditingController();
    }
    _network = LocalNetworkCore.activeFor(_gameId);
    final network = _network;
    if (network != null) {
      for (final p in network.state.players) {
        _playerNames[p.id] = p.name;
        _scores[p.id] = 0;
      }
      _messageSub = network.messages.listen(_handleNetworkMessage);
      _stateSub = network.stateStream.listen((state) {
        for (final p in state.players) {
          _playerNames[p.id] = p.name;
          _scores.putIfAbsent(p.id, () => 0);
        }
        if (mounted) setState(() {});
      });
      if (_isHost) _startWebBridge();
    }
  }


  Future<void> _startWebBridge() async {
    final bridge = IphoneWebBridge();
    _webBridge = bridge;
    _webPlayersSub = bridge.players.listen((players) {
      _webPlayers
        ..clear()
        ..addEntries(players.map((p) => MapEntry(p.id, p)));
      for (final p in players) {
        _playerNames[p.id] = p.name;
        _scores.putIfAbsent(p.id, () => 0);
      }
      if (mounted) setState(() {});
    });
    _webEventSub = bridge.events.listen(_handleWebEvent);
    try {
      final url = await bridge.start();
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
    _webEventSub?.cancel();
    _webBridge?.dispose();
    _nameController.dispose();
    for (final c in _answers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _saveName() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    _playerName = name;
    _playerNames[_myId] = name;
    _scores.putIfAbsent(_myId, () => 0);
    _network?.updateLocalPlayerName(name);
    GameFeedback.tap(GameAudioTheme.word);
    setState(() => _stage = _Stage.waiting);
  }

  void _startRound() {
    if (!_isHost || _totalPlayers < 2 || _finishing) return;
    final network = _network;
    if (network == null) return;
    final players = <Map<String, String>>[];
    for (final p in network.state.players) {
      _playerNames[p.id] = p.name;
      _scores.putIfAbsent(p.id, () => 0);
      players.add({'id': p.id, 'name': _playerNames[p.id] ?? p.name});
    }
    for (final p in _webPlayers.values) {
      players.add({'id': p.id, 'name': p.name});
    }
    final payload = <String, dynamic>{
      'action': 'categories_round_start',
      'round': _round + 1,
      'letter': _letters[_random.nextInt(_letters.length)],
      'seconds': _roundSeconds,
      'players': players,
    };
    network.sendMove(payload, senderId: _myId);
    _webBridge?.broadcast({
      'type': 'round_start',
      'round': payload['round'],
      'letter': payload['letter'],
      'seconds': _roundSeconds,
    });
    GameFeedback.move(GameAudioTheme.word);
  }

  void _handleNetworkMessage(NetworkMessage message) {
    if (!mounted || message.type != NetworkMessageType.move) return;
    final action = (message.payload['action'] ?? '').toString();
    if (action == 'categories_round_start') _receiveRoundStart(message.payload);
    if (action == 'categories_stop') _stopAndSubmit();
    if (action == 'categories_submit' && _isHost)
      _receiveSubmission(
        message.senderId,
        (message.payload['playerName'] ?? '').toString(),
        (message.payload['round'] as num?)?.toInt() ?? 0,
        message.payload['answers'],
        message.payload['endAll'] == true,
      );
    if (action == 'categories_results') _receiveResults(message.payload);
    if (action == 'categories_score_proposal') _showVoteDialog(message.payload);
    if (action == 'categories_score_vote' && _isHost)
      _registerVote(
        (message.payload['proposalId'] ?? '').toString(),
        message.senderId,
        message.payload['approve'] == true,
      );
    if (action == 'categories_score_applied') _receiveResults(message.payload);
  }

  void _handleWebEvent(IphoneWebEvent event) {
    if (!_isHost) return;
    if (event.type == 'submit') {
      _receiveSubmission(
        event.playerId,
        event.playerName,
        (event.data['round'] as num?)?.toInt() ?? 0,
        event.data['answers'],
        event.data['endAll'] != false,
      );
    } else if (event.type == 'score_vote') {
      _registerVote(
        (event.data['proposalId'] ?? '').toString(),
        event.playerId,
        event.data['approve'] == true,
      );
    }
  }

  void _receiveRoundStart(Map<String, dynamic> payload) {
    _timer?.cancel();
    final expected = <String>{};
    for (final item in (payload['players'] as List<dynamic>? ?? const [])) {
      if (item is Map) {
        final id = (item['id'] ?? '').toString();
        if (id.isNotEmpty) {
          expected.add(id);
          _playerNames[id] = (item['name'] ?? 'لاعب').toString();
          _scores.putIfAbsent(id, () => 0);
        }
      }
    }
    for (final c in _answers.values) {
      c.clear();
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
    GameFeedback.move(GameAudioTheme.word);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        _submitAnswers(endAll: true);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _submitAnswers({bool endAll = true}) {
    if (_submitted || _stage != _Stage.playing) return;
    final values = {for (final c in _categories) c: _answers[c]!.text.trim()};
    setState(() => _submitted = true);
    GameFeedback.tap(GameAudioTheme.word);
    _network?.sendMove({
      'action': 'categories_submit',
      'round': _round,
      'playerName': _playerName,
      'answers': values,
      'endAll': endAll,
    }, senderId: _myId);
    if (_isHost) _receiveSubmission(_myId, _playerName, _round, values, endAll);
  }

  void _stopAndSubmit() {
    if (_stage == _Stage.playing && !_submitted) _submitAnswers(endAll: false);
  }

  void _receiveSubmission(
    String playerId,
    String playerName,
    int round,
    dynamic rawAnswers,
    bool endAll,
  ) {
    if (round != _round || _stage != _Stage.playing) return;
    final raw = rawAnswers is Map ? rawAnswers : <dynamic, dynamic>{};
    _roundAnswers[playerId] = {
      for (final c in _categories) c: (raw[c] ?? '').toString(),
    };
    if (playerName.trim().isNotEmpty)
      _playerNames[playerId] = playerName.trim();
    if (endAll && !_finishing) {
      _finishing = true;
      _timer?.cancel();
      _network?.sendMove({'action': 'categories_stop'}, senderId: _myId);
      _webBridge?.broadcast({'type': 'round_stop'});
      Future<void>.delayed(const Duration(milliseconds: 900), _finishRound);
    } else if (_expectedIds.isNotEmpty &&
        _expectedIds.every(_roundAnswers.containsKey)) {
      _finishRound();
    }
    if (mounted) setState(() {});
  }

  String _normalize(String v) => v
      .trim()
      .replaceAll(RegExp(r'[إأآٱ]'), 'ا')
      .replaceAll(RegExp(r'[ًٌٍَُِّْـ]'), '')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'\s+'), '')
      .toLowerCase();

  bool _isValid(String answer, String category) {
    final normalized = _normalize(answer);
    const shortWordsByCategory = <String, Set<String>>{
      'اسم': <String>{'مي'},
      'حيوان': <String>{'دب', 'قط', 'بط'},
      'جماد': <String>{'زر'},
      'نبات': <String>{'رز', 'بن'},
      'بلاد': <String>{},
    };
    final acceptedTwoLetterWord =
        shortWordsByCategory[category]?.contains(normalized) ?? false;
    final validLength = normalized.length >= 3 || acceptedTwoLetterWord;
    return validLength && normalized.startsWith(_normalize(_letter));
  }

  int _pointsFor(String id, String c) {
    final a = _roundAnswers[id]?[c] ?? '';
    if (!_isValid(a, c)) return 0;
    final n = _normalize(a);
    final d = _expectedIds
        .where((o) => _normalize(_roundAnswers[o]?[c] ?? '') == n)
        .length;
    return d > 1 ? 5 : 10;
  }

  void _finishRound() {
    if (!_isHost || _stage != _Stage.playing) return;
    _timer?.cancel();
    _finishing = true;
    for (final id in _expectedIds) {
      _roundAnswers.putIfAbsent(id, () => {for (final c in _categories) c: ''});
    }
    final points = <String, int>{};
    for (final id in _expectedIds) {
      var total = 0;
      for (final c in _categories) {
        total += _pointsFor(id, c);
      }
      points[id] = total;
      _scores[id] = (_scores[id] ?? 0) + total;
    }
    final payload = <String, dynamic>{
      'action': 'categories_results',
      'round': _round,
      'letter': _letter,
      'points': points,
      'scores': _scores,
      'names': _playerNames,
      'answers': _roundAnswers,
    };
    _network?.sendMove(payload, senderId: _myId);
    _webBridge?.broadcast({...payload, 'type': 'results'});
    _receiveResults(payload);
  }

  void _receiveResults(Map<String, dynamic> payload) {
    _timer?.cancel();
    final points = <String, int>{}, scores = <String, int>{};
    final names = <String, String>{};
    final answers = <String, Map<String, String>>{};
    ((payload['points'] as Map?) ?? <dynamic, dynamic>{}).forEach(
      (k, v) => points[k.toString()] = (v as num?)?.toInt() ?? 0,
    );
    ((payload['scores'] as Map?) ?? <dynamic, dynamic>{}).forEach(
      (k, v) => scores[k.toString()] = (v as num?)?.toInt() ?? 0,
    );
    ((payload['names'] as Map?) ?? <dynamic, dynamic>{}).forEach(
      (k, v) => names[k.toString()] = v.toString(),
    );
    ((payload['answers'] as Map?) ?? <dynamic, dynamic>{}).forEach((id, value) {
      final item = value is Map ? value : <dynamic, dynamic>{};
      answers[id.toString()] = {
        for (final c in _categories) c: (item[c] ?? '').toString(),
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
    final List<int> totals = scores.values.toList(growable: false);
    final int myTotal = scores[_myId] ?? 0;
    final int bestTotal =
        totals.isEmpty ? 0 : totals.reduce((int a, int b) => a > b ? a : b);
    final bool allTied = totals.isEmpty || totals.every((score) => score == bestTotal);
    if (allTied) {
      GameFeedback.tap(GameAudioTheme.word);
    } else if (myTotal == bestTotal) {
      GameFeedback.win(GameAudioTheme.word);
    } else {
      GameFeedback.lose(GameAudioTheme.word);
    }
  }

  Future<void> _proposeScoreEdit(String playerId) async {
    if (!_isHost) return;
    final controller = TextEditingController(
      text: '${_lastPoints[playerId] ?? 0}',
    );
    final value = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('تعديل نقاط ${_playerNames[playerId] ?? 'لاعب'}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'نقاط الجولة الجديدة'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, int.tryParse(controller.text)),
            child: const Text('إرسال للتصويت'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    final id = 'p-${DateTime.now().microsecondsSinceEpoch}';
    final proposal = {
      'proposalId': id,
      'playerId': playerId,
      'playerName': _playerNames[playerId] ?? 'لاعب',
      'oldPoints': _lastPoints[playerId] ?? 0,
      'newPoints': value,
      'approvals': <String>{},
      'voters': <String>{},
    };
    _proposals[id] = proposal;
    final msg = <String, dynamic>{
      'action': 'categories_score_proposal',
      ...proposal,
    };
    msg.remove('approvals');
    _network?.sendMove(msg, senderId: _myId);
    _webBridge?.broadcast({'type': 'score_proposal', ...msg});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('تم إرسال طلب التعديل ويحتاج موافقة صريحة من لاعبين مختلفين'),
      ),
    );
  }

  Future<void> _showVoteDialog(Map<String, dynamic> p) async {
    final id = (p['proposalId'] ?? '').toString();
    if (id.isEmpty) return;
    final approve = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('طلب تعديل نقاط'),
        content: Text(
          'تعديل نقاط ${p['playerName']} من ${p['oldPoints']} إلى ${p['newPoints']}؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('رفض'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('موافقة'),
          ),
        ],
      ),
    );
    if (_isHost) {
      _registerVote(id, _myId, approve == true);
    } else {
      _network?.sendMove({
        'action': 'categories_score_vote',
        'proposalId': id,
        'approve': approve == true,
      }, senderId: _myId);
    }
  }

  void _registerVote(String proposalId, String voterId, bool approve) {
    final p = _proposals[proposalId];
    if (p == null) return;
    final voters = p['voters'] as Set<String>;
    if (!voters.add(voterId)) return;
    if (!approve) return;
    final approvals = p['approvals'] as Set<String>;
    approvals.add(voterId);
    if (approvals.length < 2) return;
    final playerId = p['playerId'].toString(),
        old = (p['oldPoints'] as num).toInt(),
        next = (p['newPoints'] as num).toInt();
    _lastPoints[playerId] = next;
    _scores[playerId] = (_scores[playerId] ?? 0) - old + next;
    _proposals.remove(proposalId);
    final payload = {
      'action': 'categories_score_applied',
      'round': _round,
      'letter': _letter,
      'points': _lastPoints,
      'scores': _scores,
      'names': _playerNames,
      'answers': _lastAnswers,
    };
    _network?.sendMove(payload, senderId: _myId);
    _webBridge?.broadcast({
      'type': 'score_applied',
      'proposalId': proposalId,
      ...payload,
    });
    _receiveResults(payload);
  }

  Future<void> _showWebQrDialog() async {
    if (!_webUrl.startsWith('http')) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('اللعب عبر QR'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            QrImageView(data: _webUrl, size: (MediaQuery.sizeOf(context).shortestSide * .80).clamp(280.0, 360.0).toDouble(), backgroundColor: Colors.white),
            const SizedBox(height: 8),
            SelectableText(_webUrl, textAlign: TextAlign.center),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_network == null)
      return const Scaffold(body: Center(child: Text('أنشئ غرفة أولًا.')));
    if (_isHost &&
        _stage == _Stage.waiting &&
        _showNetworkQrLobby) {
      return PregameQrLobby(
        title: 'اسم حيوان جماد • دعوة لاعبين',
        url: _webUrl,
        connectedPlayers: (_network?.state.players
                    .where((player) => !player.isHost)
                    .length ??
                0) +
            _webPlayers.length,
        accent: const Color(0xFF8B5CF6),
        onStart: () {
          GameFeedback.tap(GameAudioTheme.word);
          setState(() => _showNetworkQrLobby = false);
        },
      );
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

  Widget _profile() => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.edit_note_rounded, size: 74, color: Color(0xFF6D28D9)),
                const SizedBox(height: 12),
                const Text('اكتب اسمك', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                TextField(
                  controller: _nameController,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: 'اسم اللاعب'),
                ),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: _saveName, child: const Text('دخول اللعبة'))),
              ],
            ),
          ),
        ),
      );

  Widget _waiting() => LayoutBuilder(
        builder: (context, constraints) {
          final androidPlayers = _network!.state.players;
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: <Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: <Color>[Color(0xFF6D28D9), Color(0xFF0EA5E9)]),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    children: <Widget>[
                      Text('اللاعبون: $_totalPlayers', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      if (_isHost && _webUrl.startsWith('http'))
                        FilledButton.icon(
                          onPressed: _showWebQrDialog,
                          icon: const Icon(Icons.qr_code_2_rounded),
                          label: const Text('إظهار QR'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: 380,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: <Widget>[
                          for (final p in androidPlayers)
                            Chip(avatar: Icon(p.isHost ? Icons.star : Icons.android, size: 18), label: Text(_playerNames[p.id] ?? p.name)),
                          for (final p in _webPlayers.values)
                            Chip(avatar: const Icon(Icons.public, size: 18), label: Text(p.name)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_isHost)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _totalPlayers >= 2 ? _startRound : null,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(_totalPlayers >= 2 ? 'ابدأ الحرف' : 'بانتظار لاعب آخر'),
                    ),
                  )
                else
                  Text(
                    'بانتظار ${_network?.hostPlayerName ?? 'الداعي'}...',
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          );
        },
      );

  Widget _playing() => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 600;
          return Padding(
            padding: EdgeInsets.fromLTRB(10, compact ? 6 : 10, 10, 8),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(child: _info('الجولة', '$_round')),
                    const SizedBox(width: 6),
                    Expanded(child: _info('الحرف', _letter)),
                    const SizedBox(width: 6),
                    Expanded(child: _info('الوقت', '$_secondsLeft')),
                  ],
                ),
                SizedBox(height: compact ? 5 : 8),
                for (final c in _categories)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: TextField(
                        controller: _answers[c],
                        enabled: !_submitted,
                        textInputAction: c == _categories.last ? TextInputAction.done : TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: c,
                          hintText: '$c يبدأ بحرف $_letter',
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 5),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submitted ? null : () {
                      GameFeedback.tap(GameAudioTheme.word);
                      _submitAnswers(endAll: true);
                    },
                    icon: const Icon(Icons.flag),
                    label: Text(_submitted ? 'تم التسليم' : 'إنهاء الجولة للجميع'),
                  ),
                ),
              ],
            ),
          );
        },
      );

  Widget _results() {
    final ids = _scores.keys.toList()
      ..sort((a, b) => (_scores[b] ?? 0).compareTo(_scores[a] ?? 0));
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 700;
    final tableTextStyle = TextStyle(
      fontSize: compact ? 9.2 : 12.5,
      fontWeight: FontWeight.w600,
    );
    final headingTextStyle = TextStyle(
      fontSize: compact ? 8.8 : 12,
      fontWeight: FontWeight.w900,
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 14, vertical: 8),
      child: Column(
      children: [
        Text(
          'نتائج حرف $_letter',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 21 : 27,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.all(compact ? 2 : 6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: DataTable(
                    horizontalMargin: compact ? 4 : 10,
                    columnSpacing: compact ? 7 : 16,
                    dataRowMinHeight: compact ? 34 : 44,
                    dataRowMaxHeight: compact ? 40 : 52,
                    headingRowHeight: compact ? 32 : 42,
                    headingRowColor:
                        WidgetStateProperty.all(const Color(0xFFEDE4FF)),
                    border: TableBorder.all(color: const Color(0xFFD6C8EE)),
                    columns: [
                      DataColumn(
                        label: Text('اللاعب', style: headingTextStyle),
                      ),
                      ..._categories.map(
                        (category) => DataColumn(
                          label: Text(category, style: headingTextStyle),
                        ),
                      ),
                      DataColumn(
                        label: Text('الجولة', style: headingTextStyle),
                      ),
                      DataColumn(
                        label: Text('المجموع', style: headingTextStyle),
                      ),
                      if (_isHost)
                        DataColumn(
                          label: Text('تعديل', style: headingTextStyle),
                        ),
                    ],
                    rows: ids.map((id) {
                      return DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: compact ? 54 : 100,
                              child: Text(
                                _playerNames[id] ?? 'لاعب',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: tableTextStyle.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          ..._categories.map(
                            (category) => DataCell(
                              SizedBox(
                                width: compact ? 40 : 78,
                                child: Text(
                                  _lastAnswers[id]?[category]?.isNotEmpty ==
                                          true
                                      ? _lastAnswers[id]![category]!
                                      : '—',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: tableTextStyle,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${_lastPoints[id] ?? 0}',
                              style: tableTextStyle.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${_scores[id] ?? 0}',
                              style: tableTextStyle.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (_isHost)
                            DataCell(
                              IconButton(
                                constraints: const BoxConstraints(
                                  minWidth: 26,
                                  minHeight: 26,
                                ),
                                padding: EdgeInsets.zero,
                                iconSize: compact ? 15 : 20,
                                tooltip: 'طلب تعديل النقاط',
                                onPressed: () => _proposeScoreEdit(id),
                                icon: const Icon(Icons.edit),
                              ),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ),
        ),
        if (_isHost) ...[
          const SizedBox(height: 6),
          const Card(
            color: Color(0xFFFFF4D8),
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                'تعديل النقاط يُرسل للتصويت ويحتاج موافقة لاعبين مختلفين.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (_isHost)
          FilledButton.icon(
            onPressed: _totalPlayers >= 2 ? _startRound : null,
            icon: const Icon(Icons.refresh),
            label: const Text('حرف جديد'),
          )
        else
          Text(
            'بانتظار ${_network?.hostPlayerName ?? 'الداعي'} للحرف التالي',
            textAlign: TextAlign.center,
          ),
      ],
      ),
    );
  }

  Widget _info(String label, String value) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEDE4FF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(label),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
}
