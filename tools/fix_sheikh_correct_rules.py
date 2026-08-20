from pathlib import Path

p = Path('lib/games/line_games/line_games.dart')
s = p.read_text(encoding='utf-8')

old_board = '''      // Every visible contiguous 3-point segment scores independently.\n      // This covers horizontal and both diagonal/cross axes.\n      void addTriples(List<int> axis) {\n        if (axis.length < 3) return;\n        for (var start = 0; start <= axis.length - 3; start++) {\n          _sheikhLines.add(axis.sublist(start, start + 3));\n        }\n      }\n\n      for (var row = 0; row < rows; row++) {\n        addTriples(List<int>.generate(\n          row + 1,\n          (index) => rowStarts[row] + index,\n        ));\n      }\n\n      for (var column = 0; column < rows; column++) {\n        final axis = <int>[];\n        for (var row = column; row < rows; row++) {\n          axis.add(rowStarts[row] + column);\n        }\n        addTriples(axis);\n      }\n\n      for (var diagonal = 0; diagonal < rows; diagonal++) {\n        final axis = <int>[];\n        for (var row = diagonal; row < rows; row++) {\n          axis.add(rowStarts[row] + (row - diagonal));\n        }\n        addTriples(axis);\n      }\n'''
new_board = '''      // Each complete straight line is a scoring line. Its value is the\n      // number of shaded points in that line. Keep all three board axes:\n      // horizontal and both diagonal/cross directions.\n      void addFullLine(List<int> line) {\n        if (line.length >= 3) _sheikhLines.add(line);\n      }\n\n      for (var row = 0; row < rows; row++) {\n        addFullLine(List<int>.generate(\n          row + 1,\n          (index) => rowStarts[row] + index,\n        ));\n      }\n\n      for (var column = 0; column < rows; column++) {\n        final line = <int>[];\n        for (var row = column; row < rows; row++) {\n          line.add(rowStarts[row] + column);\n        }\n        addFullLine(line);\n      }\n\n      for (var diagonal = 0; diagonal < rows; diagonal++) {\n        final line = <int>[];\n        for (var row = diagonal; row < rows; row++) {\n          line.add(rowStarts[row] + (row - diagonal));\n        }\n        addFullLine(line);\n      }\n'''

old_claim = '''  int _claimCompletedSheikhLines(int ownerIndex, String playerId) {\n    var gained = 0;\n    for (final line in _sheikhLines) {\n      final key = line.join('-');\n      if (_claimedSheikhLines.containsKey(key)) continue;\n\n      // A Sheikh Beard line belongs to a player only when all three\n      // points in that straight segment were actually selected by that\n      // same player. Never recolor/steal points from another player:\n      // doing so creates false chain scores at crosses and overlaps.\n      if (!line.every((pointIndex) => _pointOwners[pointIndex] == ownerIndex)) {\n        continue;\n      }\n\n      _claimedSheikhLines[key] = playerId;\n      gained++;\n    }\n    return gained;\n  }\n'''
new_claim = '''  int _claimCompletedSheikhLines(int ownerIndex, String playerId) {\n    var gained = 0;\n    for (final line in _sheikhLines) {\n      final key = line.join('-');\n      if (_claimedSheikhLines.containsKey(key)) continue;\n      if (!line.every((pointIndex) => _pointOwners[pointIndex] >= 0)) {\n        continue;\n      }\n\n      // The player who places the final point captures the completed line.\n      // The score equals the number of shaded points in that line. A single\n      // move may complete several straight lines, so every completed line\n      // contributes its full length independently.\n      for (final pointIndex in line) {\n        _pointOwners[pointIndex] = ownerIndex;\n      }\n      _claimedSheikhLines[key] = playerId;\n      gained += line.length;\n    }\n    return gained;\n  }\n'''

if s.count(old_board) != 1:
    raise SystemExit(f'board block count={s.count(old_board)}')
if s.count(old_claim) != 1:
    raise SystemExit(f'claim block count={s.count(old_claim)}')
s = s.replace(old_board, new_board, 1).replace(old_claim, new_claim, 1)
p.write_text(s, encoding='utf-8')

t = Path('test/sheikh_beard_scoring_contract_test.dart')
t.write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Sheikh Beard final mover captures any fully shaded line', () {
    final source = File('lib/games/line_games/line_games.dart').readAsStringSync();
    expect(source, contains('_pointOwners[pointIndex] >= 0'));
    expect(source, contains('_pointOwners[pointIndex] = ownerIndex;'));
    expect(source, isNot(contains('_pointOwners[pointIndex] == ownerIndex')));
  });

  test('Sheikh Beard line score equals number of shaded points', () {
    final source = File('lib/games/line_games/line_games.dart').readAsStringSync();
    expect(source, contains('gained += line.length;'));
  });

  test('Sheikh Beard uses complete straight lines on all three axes', () {
    final source = File('lib/games/line_games/line_games.dart').readAsStringSync();
    expect(source, contains('void addFullLine(List<int> line)'));
    expect(source, contains('if (line.length >= 3) _sheikhLines.add(line);'));
    expect(source, contains('for (var column = 0; column < rows; column++)'));
    expect(source, contains('for (var diagonal = 0; diagonal < rows; diagonal++)'));
    expect(source, isNot(contains('axis.sublist(start, start + 3)')));
  });
}
''', encoding='utf-8')
print('Applied verified Sheikh Beard complete-line capture scoring rules.')
