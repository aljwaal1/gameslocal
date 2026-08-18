from pathlib import Path
import re


def replace_once(path: str, old: str, new: str, label: str) -> None:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 exact match, got {count}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')


def regex_once(path: str, pattern: str, replacement: str, label: str) -> None:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 regex match, got {count}')
    p.write_text(updated, encoding='utf-8')

# XO: dedicated gameplay sounds + true fixed viewport. QR becomes a dialog instead of
# consuming vertical game space.
xo = Path('lib/games/xo/xo_game.dart')
text = xo.read_text(encoding='utf-8')
if "../../core/audio_feedback.dart" not in text:
    text = text.replace("import '../../core/app_settings.dart';\n", "import '../../core/app_settings.dart';\nimport '../../core/audio_feedback.dart';\n")
text = text.replace(
    "    setState(() => cells[index] = mark);\n",
    "    setState(() => cells[index] = mark);\n    GameFeedback.move();\n",
    1,
)
text = text.replace(
    "      setState(() => message = winner == XoCell.x ? 'فاز X' : 'فاز O');\n",
    "      setState(() => message = winner == XoCell.x ? 'فاز X' : 'فاز O');\n      GameFeedback.win();\n",
    1,
)
text = text.replace(
    "      setState(() => message = 'تعادل');\n",
    "      setState(() => message = 'تعادل');\n      GameFeedback.tap();\n",
    1,
)
marker = "  @override\n  Widget build(BuildContext context) {\n"
if marker not in text:
    raise SystemExit('XO build marker missing')
qr_method = r'''  Future<void> _showBrowserQr() async {
    if (!_iphoneUrl.startsWith('http')) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('اللعب عبر QR'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            QrImageView(data: _iphoneUrl, size: 220, backgroundColor: Colors.white),
            const SizedBox(height: 10),
            SelectableText(_iphoneUrl, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('المتصلون: ${_iphonePlayers.length}'),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')),
        ],
      ),
    );
  }

'''
text = text.replace(marker, qr_method + marker, 1)
pattern = r"  @override\n  Widget build\(BuildContext context\) \{.*?\n  \}\n\}\n\nclass _ScoreTile"
replacement = r'''  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إكس أو'),
        actions: <Widget>[
          if (isHost && isNetworkGame && _iphoneUrl.startsWith('http'))
            IconButton(
              tooltip: 'QR للمتصفح',
              onPressed: _showBrowserQr,
              icon: const Icon(Icons.qr_code_2_rounded),
            ),
          IconButton(onPressed: reset, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: resetScore, icon: const Icon(Icons.restart_alt)),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 620 || constraints.maxWidth < 350;
            final pad = compact ? 8.0 : 14.0;
            return Padding(
              padding: EdgeInsets.all(pad),
              child: Column(
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 8 : 11),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFF0F766E), Color(0xFF6D28D9)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(color: Color(0x330F172A), blurRadius: 14, offset: Offset(0, 6)),
                      ],
                    ),
                    child: Column(
                      children: <Widget>[
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 16 : 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (!isNetworkGame) ...<Widget>[
                          const SizedBox(height: 7),
                          SegmentedButton<bool>(
                            segments: const <ButtonSegment<bool>>[
                              ButtonSegment<bool>(value: false, label: Text('لاعبان'), icon: Icon(Icons.people)),
                              ButtonSegment<bool>(value: true, label: Text('روبوت'), icon: Icon(Icons.smart_toy)),
                            ],
                            selected: <bool>{playVsBot},
                            onSelectionChanged: (value) {
                              playVsBot = value.first;
                              reset();
                            },
                            style: ButtonStyle(
                              visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: compact ? 6 : 10),
                  Row(
                    children: <Widget>[
                      Expanded(child: _ScoreTile(label: 'X', value: xWins, color: const Color(0xFFE11D48))),
                      const SizedBox(width: 7),
                      Expanded(child: _ScoreTile(label: 'تعادل', value: draws, color: const Color(0xFF64748B))),
                      const SizedBox(width: 7),
                      Expanded(child: _ScoreTile(label: 'O', value: oWins, color: const Color(0xFF0EA5E9))),
                    ],
                  ),
                  SizedBox(height: compact ? 7 : 12),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                          maxHeight: constraints.maxHeight,
                        ),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: compact ? 6 : 10,
                              crossAxisSpacing: compact ? 6 : 10,
                            ),
                            itemCount: 9,
                            itemBuilder: (context, index) {
                              final cell = cells[index];
                              final winning = winLine.contains(index);
                              final value = cell == XoCell.empty ? '' : cell.name.toUpperCase();
                              return InkWell(
                                borderRadius: BorderRadius.circular(compact ? 18 : 24),
                                onTap: () => tapCell(index),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  decoration: BoxDecoration(
                                    gradient: winning
                                        ? const LinearGradient(colors: <Color>[Color(0xFFFFD166), Color(0xFFFFB703)])
                                        : const LinearGradient(colors: <Color>[Colors.white, Color(0xFFF0F7FF)]),
                                    borderRadius: BorderRadius.circular(compact ? 18 : 24),
                                    border: Border.all(
                                      color: value == 'X'
                                          ? const Color(0x55E11D48)
                                          : value == 'O'
                                              ? const Color(0x550EA5E9)
                                              : const Color(0x160F172A),
                                      width: 2,
                                    ),
                                    boxShadow: const <BoxShadow>[
                                      BoxShadow(color: Color(0x220F172A), blurRadius: 10, offset: Offset(0, 4)),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      value,
                                      style: TextStyle(
                                        fontSize: compact ? 48 : 64,
                                        fontWeight: FontWeight.w900,
                                        color: value == 'X' ? const Color(0xFFE11D48) : const Color(0xFF0284C7),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ScoreTile'''
text, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
if count != 1:
    raise SystemExit(f'XO body replacement failed: {count}')
xo.write_text(text, encoding='utf-8')

# Checkers: keep QR available but outside the playfield. Compact the status region
# and remove the long footer so the board always owns the remaining viewport.
checkers = Path('lib/games/checkers/checkers_game.dart')
text = checkers.read_text(encoding='utf-8')
marker = "  @override\n  Widget build(BuildContext context) {\n"
if marker not in text:
    raise SystemExit('Checkers build marker missing')
method = r'''  Future<void> _showBrowserQr() async {
    if (!_iphoneUrl.startsWith('http') || hasAndroidGuest) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('الضامة عبر QR'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            QrImageView(data: _iphoneUrl, size: 220, backgroundColor: Colors.white),
            const SizedBox(height: 8),
            SelectableText(_iphoneUrl, textAlign: TextAlign.center),
            Text('المتصلون: $_iphonePlayers'),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')),
        ],
      ),
    );
  }

'''
text = text.replace(marker, method + marker, 1)
text = text.replace(
    "            actions: [\n              IconButton(\n                  onPressed: requestBoardReset, icon: const Icon(Icons.refresh))\n            ],",
    "            actions: [\n              if (networkMode && localPlayerIsRed && _iphoneUrl.startsWith('http') && !hasAndroidGuest)\n                IconButton(tooltip: 'QR للمتصفح', onPressed: _showBrowserQr, icon: const Icon(Icons.qr_code_2_rounded)),\n              IconButton(onPressed: requestBoardReset, icon: const Icon(Icons.refresh))\n            ],",
    1,
)
text = re.sub(
    r"\n              if \(networkMode && localPlayerIsRed\)\n                Padding\(.*?child: _iphoneCard\(\),\n                \),",
    "",
    text,
    count=1,
    flags=re.S,
)
text = text.replace("padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),", "padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),", 1)
text = text.replace("padding: const EdgeInsets.all(14),", "padding: const EdgeInsets.all(9),", 1)
text = text.replace("fontSize: 18,", "fontSize: 16,", 1)
text = re.sub(
    r"\n              const Padding\(\n                padding: EdgeInsets.fromLTRB\(16, 0, 16, 18\),\n                child: Text\(.*?\n              \),",
    "",
    text,
    count=1,
    flags=re.S,
)
checkers.write_text(text, encoding='utf-8')

# Line games: QR is an app-bar action/dialog, never a block inside gameplay.
line = Path('lib/games/line_games/line_games.dart')
text = line.read_text(encoding='utf-8')
marker = "  @override\n  Widget build(BuildContext context) {\n"
if marker not in text:
    raise SystemExit('Line game build marker missing')
method = r'''  Future<void> _showBrowserQr() async {
    if (!_webUrl.startsWith('http')) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('اللعب عبر QR'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            QrImageView(data: _webUrl, size: 220, backgroundColor: Colors.white),
            const SizedBox(height: 8),
            SelectableText(_webUrl, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            const Text('افتح الرابط من iPhone أو Android على نفس الشبكة.'),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')),
        ],
      ),
    );
  }

'''
text = text.replace(marker, method + marker, 1)
text = text.replace(
    "    return Scaffold(\n      appBar: AppBar(title: Text(title)),",
    "    return Scaffold(\n      appBar: AppBar(\n        title: Text(title),\n        actions: <Widget>[\n          if (_isHost && _webUrl.startsWith('http'))\n            IconButton(tooltip: 'QR للمتصفح', onPressed: _showBrowserQr, icon: const Icon(Icons.qr_code_2_rounded)),\n        ],\n      ),",
    1,
)
text = re.sub(
    r"\n          if \(_isHost && _webUrl.isNotEmpty\)\n            Card\(.*?\n            \),\n          Padding\(",
    "\n          Padding(",
    text,
    count=1,
    flags=re.S,
)
text = text.replace("padding: const EdgeInsets.all(8),", "padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),", 1)
text = text.replace("fontSize: 25,", "fontSize: 23,", 1)
line.write_text(text, encoding='utf-8')

# Chess: no scrolling already; reclaim vertical space, make board richer, and preserve
# readable pieces on small phones.
chess = Path('lib/games/chess/chess_game.dart')
text = chess.read_text(encoding='utf-8')
text = text.replace("padding: const EdgeInsets.all(16),", "padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),", 1)
text = text.replace("fontSize: 22,", "fontSize: 18,", 1)
text = text.replace("? const Color(0xFF769656)\n                                  : const Color(0xFFEEEED2)", "? const Color(0xFF1F5D50)\n                                  : const Color(0xFFF0E5C9)", 1)
text = text.replace("color: Colors.orange.shade800, width: 3", "color: const Color(0xFFFFB703), width: 3", 1)
text = text.replace("style: const TextStyle(\n                                        fontSize: 34, color: Colors.black)", "style: const TextStyle(\n                                        fontSize: 32, color: Color(0xFF0F172A))", 1)
text = re.sub(
    r"\n        const Padding\(\n            padding: EdgeInsets.all\(12\),\n            child:\n                Text\('شطرنج قانوني:.*?\)\),",
    "",
    text,
    count=1,
    flags=re.S,
)
chess.write_text(text, encoding='utf-8')

# Name/animal/object: add explicit game sounds and turn the playing stage into a
# fixed viewport with five flexible input rows. Profile/waiting/results cannot scroll.
name = Path('lib/games/name_animal_object/name_animal_object_game.dart')
text = name.read_text(encoding='utf-8')
if "../../core/audio_feedback.dart" not in text:
    text = text.replace("import '../../core/network/local_network_core.dart';\n", "import '../../core/audio_feedback.dart';\nimport '../../core/network/local_network_core.dart';\n")
# profile
text = re.sub(
    r"  Widget _profile\(\) => ListView\(.*?\n      \);\n\n  Widget _waiting",
    r'''  Widget _profile() => Center(
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

  Widget _waiting''',
    text,
    count=1,
    flags=re.S,
)
# replace waiting fully
text = re.sub(
    r"  Widget _waiting\(\) => ListView\(.*?\n      \);\n\n  Widget _playing",
    r'''  Widget _waiting() => LayoutBuilder(
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
                  const Text('بانتظار المضيف...', textAlign: TextAlign.center),
              ],
            ),
          );
        },
      );

  Widget _playing''',
    text,
    count=1,
    flags=re.S,
)
# replace playing fully
text = re.sub(
    r"  Widget _playing\(\) => ListView\(.*?\n      \);\n\n  Widget _results",
    r'''  Widget _playing() => LayoutBuilder(
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
                      GameFeedback.win();
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

  Widget _results''',
    text,
    count=1,
    flags=re.S,
)
# add QR dialog method before build
build_marker = "  @override\n  Widget build(BuildContext context) {\n"
if build_marker not in text:
    raise SystemExit('Name game build marker missing')
qr = r'''  Future<void> _showWebQrDialog() async {
    if (!_webUrl.startsWith('http')) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('اللعب عبر QR'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            QrImageView(data: _webUrl, size: 220, backgroundColor: Colors.white),
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

'''
text = text.replace(build_marker, qr + build_marker, 1)
# Results: preserve table, but remove ListView in favour of fixed Column + scaled table.
text = text.replace("    return ListView(\n      padding: EdgeInsets.symmetric(\n        horizontal: compact ? 4 : 14,\n        vertical: 10,\n      ),\n      children: [", "    return Padding(\n      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 14, vertical: 8),\n      child: Column(\n      children: [", 1)
# Make the table card flexible instead of forcing vertical list growth.
text = text.replace("        Card(\n          clipBehavior: Clip.antiAlias,", "        Expanded(\n          child: Card(\n          clipBehavior: Clip.antiAlias,", 1)
# Close Expanded before host note / following result controls.
text = text.replace("          ),\n        ),\n        if (_isHost) ...[", "          ),\n        ),\n        ),\n        if (_isHost) ...[", 1)
# Close Padding + Column after existing ListView close.
results_end = "      ],\n    );\n  }\n\n  Widget _info("
if results_end not in text:
    raise SystemExit('Name results closing marker missing')
text = text.replace(results_end, "      ],\n      ),\n    );\n  }\n\n  Widget _info(", 1)
name.write_text(text, encoding='utf-8')

# Cards & Domino already use fixed Columns/Expanded. Tighten their fixed hand bands on
# small devices to prevent overflow while preserving playability.
cards = Path('lib/games/cards/cards_game.dart')
text = cards.read_text(encoding='utf-8')
text = text.replace("padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),", "padding: const EdgeInsets.fromLTRB(10, 3, 10, 7),", 1)
text = text.replace("height: 116,", "height: 104,", 1)
text = text.replace("padding: const EdgeInsets.all(12),", "padding: const EdgeInsets.all(9),", 1)
cards.write_text(text, encoding='utf-8')

domino = Path('lib/games/domino/domino_game.dart')
text = domino.read_text(encoding='utf-8')
text = text.replace("padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),", "padding: const EdgeInsets.fromLTRB(10, 3, 10, 7),", 1)
text = text.replace("height: compact ? 138 : 152,", "height: compact ? 116 : 134,", 1)
text = text.replace("padding: const EdgeInsets.all(12),", "padding: const EdgeInsets.all(9),", 1)
domino.write_text(text, encoding='utf-8')

# Contract: gameplay files must not contain a vertically/horizontally scrollable game
# body after this pass. The home library is intentionally excluded.
for file in [
    'lib/games/xo/xo_game.dart',
    'lib/games/checkers/checkers_game.dart',
    'lib/games/chess/chess_game.dart',
    'lib/games/cards/cards_game.dart',
    'lib/games/domino/domino_game.dart',
    'lib/games/line_games/line_games.dart',
    'lib/games/name_animal_object/name_animal_object_game.dart',
    'lib/games/football/photo_penalty_game_v3.dart',
]:
    s = Path(file).read_text(encoding='utf-8')
    if 'SingleChildScrollView(' in s:
        raise SystemExit(f'Forbidden scrolling widget remains in {file}')

print('fullscreen polish applied')
