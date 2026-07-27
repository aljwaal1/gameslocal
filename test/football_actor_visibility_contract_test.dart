import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('professional football scene keeps full player and goalkeeper artwork', () {
    final wrapper = File(
      'lib/games/football/professional_penalty_scene.dart',
    ).readAsStringSync();
    final scene = File(
      'lib/games/football/stable_penalty_scene.dart',
    ).readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final artwork = File('assets/football/pro_penalty_arena.jpg');

    expect(wrapper, contains('StablePenaltyScene'));
    expect(scene, contains("'assets/football/pro_penalty_arena.jpg'"));
    expect(scene, contains('fit: BoxFit.contain'));
    expect(scene, contains("'stable-full-player-keeper-scene'"));
    expect(scene, contains('errorBuilder:'));
    expect(scene, isNot(contains('fit: BoxFit.cover')));
    expect(scene, isNot(contains('Transform.scale')));
    expect(pubspec, contains('- assets/football/'));
    expect(artwork.existsSync(), isTrue);
    expect(artwork.lengthSync(), greaterThan(10000));
  });
}
