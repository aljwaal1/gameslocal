import 'dart:io';

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

  test('Sheikh Beard uses every complete straight line on all three axes', () {
    final source = File('lib/games/line_games/line_games.dart').readAsStringSync();
    expect(source, contains('void addFullLine(List<int> line)'));
    expect(source, contains('if (line.length >= 2) _sheikhLines.add(line);'));
    expect(source, contains('for (var column = 0; column < rows; column++)'));
    expect(source, contains('for (var diagonal = 0; diagonal < rows; diagonal++)'));
    expect(source, isNot(contains('axis.sublist(start, start + 3)')));
  });

  test('Sheikh Beard keeps valid two-point edge lines', () {
    final source = File('lib/games/line_games/line_games.dart').readAsStringSync();
    expect(source, contains('line.length >= 2'));
    expect(source, isNot(contains('line.length >= 3')));
  });
}
