from pathlib import Path
import re

# Responsive home grid (idempotent).
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
if old_grid in main:
    main = main.replace(old_grid, new_grid)
main_path.write_text(main, encoding='utf-8')

# Responsive play header.
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
if old_header in text:
    text = text.replace(old_header, new_header)

pattern = re.compile(r"  Widget _results\(\) \{.*?\n  Widget _info\(", re.DOTALL)
replacement = r'''  Widget _results() {
    final ids = _scores.keys.toList()
      ..sort((a, b) => (_scores[b] ?? 0).compareTo(_scores[a] ?? 0));
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 700;
    final tableTextStyle = TextStyle(
      fontSize: compact ? 11 : 13,
      fontWeight: FontWeight.w600,
    );
    final headingTextStyle = TextStyle(
      fontSize: compact ? 10.5 : 12.5,
      fontWeight: FontWeight.w900,
    );

    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 14,
        vertical: 10,
      ),
      children: [
        Text(
          'نتائج حرف $_letter',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 22 : 27,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                horizontalMargin: compact ? 7 : 14,
                columnSpacing: compact ? 12 : 22,
                dataRowMinHeight: compact ? 40 : 46,
                dataRowMaxHeight: compact ? 48 : 56,
                headingRowHeight: compact ? 38 : 44,
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
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: compact ? 82 : 130,
                          ),
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
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: compact ? 48 : 65,
                              maxWidth: compact ? 76 : 110,
                            ),
                            child: Text(
                              _lastAnswers[id]?[category]?.isNotEmpty == true
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
                              minWidth: 34,
                              minHeight: 34,
                            ),
                            padding: EdgeInsets.zero,
                            iconSize: compact ? 18 : 21,
                            tooltip: 'طلب تعديل النقاط',
                            onPressed: () => _proposeScoreEdit(id),
                            icon: const Icon(Icons.edit),
                          ),
                        ),
                    ],
                  );
                }).toList(),
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
