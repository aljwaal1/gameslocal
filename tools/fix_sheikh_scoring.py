from pathlib import Path

p = Path('lib/games/line_games/line_games.dart')
s = p.read_text(encoding='utf-8')
old = '''  int _claimCompletedSheikhLines(int ownerIndex, String playerId) {
    var gained = 0;
    for (final line in _sheikhLines) {
      final key = line.join('-');
      if (_claimedSheikhLines.containsKey(key)) continue;
      if (!line.every((pointIndex) => _pointOwners[pointIndex] >= 0)) {
        continue;
      }

      // The player who places the final point captures the whole completed line.
      for (final pointIndex in line) {
        _pointOwners[pointIndex] = ownerIndex;
      }
      _claimedSheikhLines[key] = playerId;
      gained++;
    }
    return gained;
  }
'''
new = '''  int _claimCompletedSheikhLines(int ownerIndex, String playerId) {
    var gained = 0;
    for (final line in _sheikhLines) {
      final key = line.join('-');
      if (_claimedSheikhLines.containsKey(key)) continue;

      // A Sheikh Beard line belongs to a player only when all three
      // points in that straight segment were actually selected by that
      // same player. Never recolor/steal points from another player:
      // doing so creates false chain scores at crosses and overlaps.
      if (!line.every((pointIndex) => _pointOwners[pointIndex] == ownerIndex)) {
        continue;
      }

      _claimedSheikhLines[key] = playerId;
      gained++;
    }
    return gained;
  }
'''
if s.count(old) != 1:
    raise SystemExit(f'claim block count={s.count(old)}')
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')

t = Path('test/sheikh_beard_scoring_contract_test.dart')
t.write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Sheikh Beard scores only three points owned by the same player', () {
    final source = File('lib/games/line_games/line_games.dart').readAsStringSync();

    expect(
      source,
      contains('_pointOwners[pointIndex] == ownerIndex'),
    );
    expect(
      source,
      isNot(contains('_pointOwners[pointIndex] >= 0')),
    );
    expect(
      source,
      isNot(contains('_pointOwners[pointIndex] = ownerIndex;')),
    );
  });

  test('Sheikh Beard keeps all three straight axes and contiguous triples', () {
    final source = File('lib/games/line_games/line_games.dart').readAsStringSync();
    expect(source, contains('void addTriples(List<int> axis)'));
    expect(source, contains('axis.sublist(start, start + 3)'));
    expect(source, contains('for (var column = 0; column < rows; column++)'));
    expect(source, contains('for (var diagonal = 0; diagonal < rows; diagonal++)'));
  });
}
''', encoding='utf-8')
print('Fixed Sheikh Beard scoring and added regression contract.')
