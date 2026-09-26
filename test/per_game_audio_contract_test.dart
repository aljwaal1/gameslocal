import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('audio engine exposes a distinct theme for every production game', () {
    final source = File('lib/core/audio_feedback.dart').readAsStringSync();
    for (final theme in <String>[
      'football',
      'xo',
      'checkers',
      'domino',
      'chess',
      'cards',
      'word',
      'beard',
      'dots',
    ]) {
      expect(source, contains('GameAudioTheme.$theme'));
    }
    expect(source, contains("final cacheKey = '\${theme.name}:\${sound.name}';"));
    expect(source, contains('signatureFrequency'));
    expect(source, contains('GameSound.lose'));
    expect(source, contains('static Future<void> lose'));
  });

  test('competitive games use distinct win and loss cues', () {
    for (final path in <String>[
      'lib/games/football/world_class_penalty_game_v2.dart',
      'lib/games/xo/xo_game.dart',
      'lib/games/checkers/checkers_game.dart',
      'lib/games/domino/domino_game.dart',
      'lib/games/cards/cards_game.dart',
      'lib/games/name_animal_object/name_animal_object_game.dart',
      'lib/games/line_games/line_games.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('GameFeedback.win'), reason: path);
      expect(source, contains('GameFeedback.lose'), reason: path);
    }
  });

  test('LAN rooms use real player names instead of a host placeholder', () {
    final network =
        File('lib/core/network/local_network_core.dart').readAsStringSync();
    final room = File('lib/core/game_room.dart').readAsStringSync();
    expect(network, contains('required String playerName'));
    expect(network, contains('name: cleanedPlayerName'));
    expect(room, contains("labelText: 'اسمك داخل الغرفة'"));
    expect(room, contains('playerName: _playerNameController.text'));

    for (final path in <String>[
      'lib/core/network/local_network_core.dart',
      'lib/core/game_room.dart',
      'lib/games/cards/cards_game.dart',
      'lib/games/domino/domino_game.dart',
      'lib/games/name_animal_object/name_animal_object_game.dart',
    ]) {
      expect(File(path).readAsStringSync(), isNot(contains('المضيف')),
          reason: path);
    }
  });

  test('every production game selects its own audio identity', () {
    final expectations = <String, String>{
      'lib/games/football/world_class_penalty_game_v2.dart': 'GameAudioTheme.football',
      'lib/games/xo/xo_game.dart': 'GameAudioTheme.xo',
      'lib/games/checkers/checkers_game.dart': 'GameAudioTheme.checkers',
      'lib/games/domino/domino_game.dart': 'GameAudioTheme.domino',
      'lib/games/chess/chess_game.dart': 'GameAudioTheme.chess',
      'lib/games/cards/cards_game.dart': 'GameAudioTheme.cards',
      'lib/games/name_animal_object/name_animal_object_game.dart': 'GameAudioTheme.word',
      'lib/games/line_games/line_games.dart': 'GameAudioTheme.beard',
    };

    expectations.forEach((path, theme) {
      expect(File(path).readAsStringSync(), contains(theme), reason: path);
    });

    final lineGames = File('lib/games/line_games/line_games.dart').readAsStringSync();
    expect(lineGames, contains('GameAudioTheme.dots'));
  });

  test('the beard game uses its new public Arabic name everywhere', () {
    for (final path in <String>[
      'lib/main.dart',
      'lib/lan/screens/lan_home_screen.dart',
      'lib/games/line_games/line_games.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('لعبة اللحية'), reason: path);
      expect(source, isNot(contains('لحية الشيخ')), reason: path);
    }
  });
}
