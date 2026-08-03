from pathlib import Path

path = Path('lib/games/line_games/line_games.dart')
text = path.read_text(encoding='utf-8')

text = text.replace('const rows = 7;', 'const rows = 8;')
text = text.replace("final y = 80.0 + row * 85;", "final y = 65.0 + row * 78;")
text = text.replace("final startX = 350.0 - (count - 1) * 43;", "final startX = 350.0 - (count - 1) * 38;")
text = text.replace("_points.add(Offset(startX + column * 86, y));", "_points.add(Offset(startX + column * 76, y));")

old_diagonal = '''
      for (var diagonal = 0; diagonal < rows; diagonal++) {
        final line = <int>[];
        for (var row = diagonal; row < rows; row++) {
          final column = row - diagonal;
          line.add(rowStarts[row] + column);
        }
        if (line.length >= 3) _sheikhLines.add(line);
      }
'''
text = text.replace(old_diagonal, '')

old_claim = '''  int _claimCompletedSheikhLines(int ownerIndex, String playerId) {
    var gained = 0;
    for (final line in _sheikhLines) {
      if (!line.every((pointIndex) => _pointOwners[pointIndex] == ownerIndex)) {
        continue;
      }
      final key = line.join('-');
      if (_claimedSheikhLines.containsKey(key)) continue;
      _claimedSheikhLines[key] = playerId;
      gained++;
    }
    return gained;
  }
'''

new_claim = '''  int _claimCompletedSheikhLines(int ownerIndex, String playerId) {
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
      gained += line.length;
    }
    return gained;
  }
'''

if old_claim not in text:
    raise SystemExit('Sheikh claim function not found')
text = text.replace(old_claim, new_claim)

path.write_text(text, encoding='utf-8')
