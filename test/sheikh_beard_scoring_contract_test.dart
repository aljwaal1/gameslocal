import 'dart:io';

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
