import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const nativeGameFiles = <String>[
    'lib/games/xo/xo_game.dart',
    'lib/games/checkers/checkers_game.dart',
    'lib/games/chess/chess_game.dart',
    'lib/games/cards/cards_game.dart',
    'lib/games/domino/domino_game.dart',
    'lib/games/domino/domino_four_player_game.dart',
    'lib/games/line_games/line_games.dart',
    'lib/games/name_animal_object/name_animal_object_game.dart',
    'lib/games/football/photo_penalty_game_v3.dart',
  ];

  test('all active game screens stay inside one non-scrolling viewport', () {
    for (final path in nativeGameFiles) {
      final source = File(path).readAsStringSync();
      expect(
        source.contains('SingleChildScrollView('),
        isFalse,
        reason: '$path must not introduce vertical or horizontal scrolling',
      );
      expect(
        source.contains('ListView('),
        isFalse,
        reason: '$path must fit the active game into one screen',
      );
    }
  });

  test('every active native game is connected to the shared audio engine', () {
    for (final path in nativeGameFiles) {
      final source = File(path).readAsStringSync();
      expect(
        source.contains('audio_feedback.dart'),
        isTrue,
        reason: '$path must use the shared sound system',
      );
      expect(
        source.contains('GameFeedback.'),
        isTrue,
        reason: '$path must emit at least one gameplay sound event',
      );
    }
  });

  test('browser game clients lock the viewport and expose browser audio', () {
    const browserFiles = <String>[
      'lib/games/xo/xo_iphone_bridge.dart',
      'lib/games/checkers/checkers_iphone_web.dart',
      'lib/games/name_animal_object/iphone_web_bridge.dart',
      'lib/games/line_games/line_games.dart',
    ];

    for (final path in browserFiles) {
      final source = File(path).readAsStringSync();
      expect(
        source.contains('AudioContext') || source.contains('webkitAudioContext'),
        isTrue,
        reason: '$path must provide sound to QR/browser players',
      );
    }

    for (final path in browserFiles.take(3)) {
      final source = File(path).readAsStringSync();
      expect(
        source.contains('overflow:hidden'),
        isTrue,
        reason: '$path must not rely on page scrolling during play',
      );
    }
  });
}
