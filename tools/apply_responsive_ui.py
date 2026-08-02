from pathlib import Path
import re

# Responsive home grid.
main_path = Path('lib/main.dart')
main = main_path.read_text(encoding='utf-8')
old_grid = """              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.20,
                  children: [for (final game in games) _GameCard(game: game)],
                ),
              ),
"""
new_grid = """              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final columns = width < 390
                        ? 1
                        : width < 850
                            ? 2
                            : width < 1250
                                ? 3
                                : 4;
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: columns == 1 ? 2.05 : 1.20,
                      ),
                      itemCount: games.length,
                      itemBuilder: (context, index) =>
                          _GameCard(game: games[index]),
                    );
                  },
                ),
              ),
"""
if old_grid not in main:
    raise SystemExit('Home grid block not found')
main_path.write_text(main.replace(old_grid, new_grid), encoding='utf-8')

# Responsive name-game play header and results.
path = Path('lib/games/name_animal_object/name_animal_object_game.dart')
text = path.read_text(encoding='utf-8')
old_header = """          Row(
            children: [
              Expanded(child: _info('الجولة', '$_round')),
              const SizedBox(width: 8),
              Expanded(child: _info('الحرف', _letter)),
              const SizedBox(width: 8),
              Expanded(child: _info('الوقت', '$_secondsLeft')),
            ],
          ),
"""
new_header = """          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth < 430
                  ? (constraints.maxWidth - 8) / 2
                  : (constraints.maxWidth - 16) / 3;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  SizedBox(width: itemWidth, child: _info('الجولة', '$_round')),
                  SizedBox(width: itemWidth, child: _info('الحرف', _letter)),
                  SizedBox(width: itemWidth, child: _info('الوقت', '$_secondsLeft')),
                ],
              );
            },
          ),
"""
if old_header not in text:
    raise SystemExit('Play header block not found')
text = text.replace(old_header, new_header)

pattern = re.compile(r"  Widget _results\(\) \{.*?\n  Widget _info\(", re.DOTALL)
replacement = r'''  Widget _results() {
    final ids = _scores.keys.toList()
      ..sort((a, b) => (_scores[b] ?? 0).compareTo(_scores[a] ?? 0));
    final isCompact = MediaQuery.sizeOf(context).width < 700;

    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 16,
        vertical: 12,
      ),
      children: [
        Text(
          'نتائج حرف $_letter',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isCompact ? 23 : 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        if (isCompact)
          ...ids.asMap().entries.map((entry) {
            final id = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(child: Text('${entry.key + 1}')),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _playerNames[id] ?? 'لاعب',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (_isHost)
                          IconButton.filledTonal(
                            tooltip: 'طلب تعديل النقاط',
                            onPressed: () => _proposeScoreEdit(id),
                            icon: const Icon(Icons.edit),
                          ),
                      ],
                    ),
                    const Divider(),
                    ..._categories.map(
                      (category) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 62,
                              child: Text(
                                category,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _lastAnswers[id]?[category]?.isNotEmpty == true
                                    ? _lastAnswers[id]![category]!
                                    : '—',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'نقاط الجولة: ${_lastPoints[id] ?? 0}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'المجموع: ${_scores[id] ?? 0}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          })
        else
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor:
                    WidgetStateProperty.all(const Color(0xFFEDE4FF)),
                border: TableBorder.all(color: const Color(0xFFD6C8EE)),
                columns: [
                  const DataColumn(label: Text('اللاعب')),
                  ..._categories.map((c) => DataColumn(label: Text(c))),
                  const DataColumn(label: Text('الجولة')),
                  const DataColumn(label: Text('المجموع')),
                  if (_isHost) const DataColumn(label: Text('تعديل')),
                ],
                rows: ids.map((id) => DataRow(cells: [
                  DataCell(Text(_playerNames[id] ?? 'لاعب')),
                  ..._categories.map((c) => DataCell(Text(
                    _lastAnswers[id]?[c]?.isNotEmpty == true
                        ? _lastAnswers[id]![c]!
                        : '—',
                  ))),
                  DataCell(Text('${_lastPoints[id] ?? 0}')),
                  DataCell(Text('${_scores[id] ?? 0}')),
                  if (_isHost)
                    DataCell(IconButton(
                      tooltip: 'طلب تعديل النقاط',
                      onPressed: () => _proposeScoreEdit(id),
                      icon: const Icon(Icons.edit),
                    )),
                ])).toList(),
              ),
            ),
          ),
        if (_isHost) ...[
          const SizedBox(height: 6),
          const Card(
            color: Color(0xFFFFF4D8),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'تعديل النقاط لا يُطبّق مباشرة؛ يُرسل للتصويت ويحتاج موافقة لاعبين مختلفين.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800),
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
          const Text(
            'بانتظار المضيف للحرف التالي',
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  Widget _info('''
updated, count = pattern.subn(replacement, text, count=1)
if count != 1:
    raise SystemExit('Results function not found')
path.write_text(updated, encoding='utf-8')
