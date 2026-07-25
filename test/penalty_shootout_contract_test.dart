import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('penalty shootout keeps robot, LAN, and allowed-team contract', () {
    final source = File(
      'lib/games/football/penalty_shootout_game.dart',
    ).readAsStringSync();

    expect(source, contains('class PenaltyShootoutGameScreen'));
    expect(source, contains('LocalNetworkCore? networkCore'));
    expect(source, contains("'action': 'penaltyShot'"));
    expect(source, contains('_robotShot()'));
    expect(source, contains("FootballTeam('jordan'"));
    expect(source, contains("FootballTeam('brazil'"));
    expect(source, contains("FootballTeam('spain'"));
    expect(source, contains("FootballTeam('colombia'"));

    expect(source, isNot(contains("FootballTeam('argentina'")));
    expect(source, isNot(contains("FootballTeam('england'")));
    expect(source, isNot(contains("FootballTeam('usa'")));
  });
}
