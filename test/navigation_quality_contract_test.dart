import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home keeps the responsive premium navigation contract', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('CustomScrollView'));
    expect(source, contains('SliverGridDelegateWithMaxCrossAxisExtent'));
    expect(source, contains('LAN / Hotspot'));
    expect(source, contains('LanHomeScreen()'));
    expect(source, contains("label: 'فتح لعبة \${game.name}'"));
  });

  test('LAN shortcut routes into the production GameRoom flow', () {
    final source = File(
      'lib/lan/screens/lan_home_screen.dart',
    ).readAsStringSync();

    expect(source, contains('GameRoomScreen(game: game)'));
    expect(source, contains("id: 'football_penalties'"));
    expect(source, contains("id: 'xo'"));
    expect(source, contains("id: 'checkers'"));
    expect(source, contains("id: 'domino'"));
    expect(source, contains("id: 'cards'"));
    expect(source, contains("id: 'name_animal_object'"));
    expect(source, contains("id: 'sheikh_beard'"));
    expect(source, contains("id: 'dots_boxes'"));
    expect(source, isNot(contains('ربط اللعب الفعلي سيكون في المرحلة التالية')));
  });

  test('game room exposes clear offline, difficulty, LAN and retry choices', () {
    final source = File('lib/core/game_room.dart').readAsStringSync();
    expect(source, contains('ضد الروبوت / على الجهاز'));
    expect(source, contains('مستوى الروبوت لهذه اللعبة'));
    expect(source, contains('setBotDifficultyFor(widget.game.id'));
    expect(source, contains('أو العب عبر LAN / Hotspot'));
    expect(source, contains('إعادة الاتصال'));
  });

  test('settings no longer exposes unfinished-product messaging', () {
    final source = File(
      'lib/settings/settings_screen.dart',
    ).readAsStringSync();

    expect(source, contains('مستوى الروبوت'));
    expect(source, contains('الأصوات'));
    expect(source, contains('الاهتزاز'));
    expect(source, contains('لون الطاولة'));
    expect(source, isNot(contains('سيتم ربطها تدريجيًا بكل الألعاب')));
  });
}
