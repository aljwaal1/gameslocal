import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/core/game_definition.dart';
import 'package:gameslocal/main.dart';

void main() {
  group('GameCapabilities', () {
    test('all thirteen games declare honest modes and complete instructions', () {
      final games = HomeScreen().games;

      expect(games, hasLength(13));
      expect(games.map((game) => game.id).toSet(), hasLength(13));
      for (final game in games) {
        expect(game.instructions.objective.trim(), isNotEmpty, reason: game.id);
        expect(game.instructions.controls.trim(), isNotEmpty, reason: game.id);
        expect(
          game.capabilities.hasOfflineMode ||
              game.capabilities.hasNetworkMode,
          isTrue,
          reason: '${game.id} has no playable mode',
        );
      }

      final hand51 = games.singleWhere((game) => game.id == 'hand51');
      expect(hand51.capabilities.robot, isTrue);
      expect(hand51.capabilities.hasNetworkMode, isFalse);
    });

    test('hand 51 only advertises modes it really implements', () {
      const capabilities = GameCapabilities(
        robot: true,
        sameDevice: false,
        lan: false,
        internet: false,
        browser: false,
      );

      expect(capabilities.robot, isTrue);
      expect(capabilities.sameDevice, isFalse);
      expect(capabilities.lan, isFalse);
      expect(capabilities.internet, isFalse);
      expect(capabilities.browser, isFalse);
      expect(capabilities.hasNetworkMode, isFalse);
    });

    test('air hockey exposes all implemented multiplayer modes', () {
      const capabilities = GameCapabilities(
        robot: true,
        sameDevice: true,
        lan: true,
        internet: true,
        browser: false,
      );

      expect(capabilities.hasNetworkMode, isTrue);
      expect(capabilities.hasOfflineMode, isTrue);
    });

    test('instructions reject empty objective and gesture', () {
      expect(
        () => GameInstructions(objective: '', controls: 'اسحب'),
        throwsArgumentError,
      );
      expect(
        () => GameInstructions(objective: 'سجّل', controls: ''),
        throwsArgumentError,
      );
    });
  });
}
