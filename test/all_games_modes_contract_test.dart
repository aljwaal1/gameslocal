import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all nine games are exposed through the LAN room flow', () {
    final home = File('lib/main.dart').readAsStringSync();
    final lan = File('lib/lan/screens/lan_home_screen.dart').readAsStringSync();
    const ids = <String>[
      'football_penalties',
      'xo',
      'checkers',
      'domino',
      'chess',
      'cards',
      'name_animal_object',
      'sheikh_beard',
      'dots_boxes',
    ];
    for (final id in ids) {
      expect(home, contains("'$id'"), reason: '$id missing from home');
      expect(lan, contains("id: '$id'"), reason: '$id missing from LAN');
    }
    expect(home, contains("'chess',"));
    expect(
      home,
      contains('ChessGameScreen(networkCore: networkCore)'),
    );
  });

  test('robot games consume the shared three-level difficulty', () {
    const files = <String>[
      'lib/games/football/world_class_penalty_game_v2.dart',
      'lib/games/xo/xo_game.dart',
      'lib/games/checkers/checkers_game.dart',
      'lib/games/domino/domino_game.dart',
      'lib/games/cards/cards_game.dart',
      'lib/games/chess/chess_game.dart',
      'lib/games/line_games/line_games.dart',
    ];
    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        contains('settings.botDifficultyFor'),
        reason: '$path ignores the selected robot level',
      );
    }
  });

  test('LAN core ignores duplicate transported messages', () {
    final source =
        File('lib/core/network/local_network_core.dart').readAsStringSync();
    expect(source, contains('_seenMessageKeys'));
    expect(source, contains('if (!_seenMessageKeys.add(messageKey)) return;'));
    expect(source, contains('_seenMessageOrder.length > 256'));
  });

  test('name game receives its room directly instead of relying on globals', () {
    final source = File(
      'lib/games/name_animal_object/name_animal_object_game.dart',
    ).readAsStringSync();
    expect(source, contains('final LocalNetworkCore? networkCore;'));
    expect(
      source,
      contains('widget.networkCore ?? LocalNetworkCore.activeFor(_gameId)'),
    );
  });
}
