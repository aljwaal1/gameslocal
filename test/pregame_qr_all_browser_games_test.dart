import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared QR lobby is large and non-scrollable', () {
    final source = File('lib/core/pregame_qr_lobby.dart').readAsStringSync();
    expect(source, contains('constraints.maxWidth * .78'));
    expect(source, contains("'امسح QR قبل بدء اللعبة'"));
    expect(source, contains('QrImageView('));
    expect(source, isNot(contains('ListView(')));
    expect(source, isNot(contains('SingleChildScrollView(')));
  });

  test('XO uses pregame QR lobby', () {
    final source = File('lib/games/xo/xo_game.dart').readAsStringSync();
    expect(source, contains("title: 'إكس أو • دعوة لاعب'"));
    expect(source, contains('_showNetworkQrLobby'));
  });

  test('checkers uses pregame QR lobby', () {
    final source = File('lib/games/checkers/checkers_game.dart').readAsStringSync();
    expect(source, contains("title: 'الضامة • دعوة لاعب'"));
    expect(source, contains('_showNetworkQrLobby'));
  });

  test('both line games use the shared pregame QR lobby', () {
    final source = File('lib/games/line_games/line_games.dart').readAsStringSync();
    expect(source, contains("title: '\$title • دعوة لاعب'"));
    expect(source, contains('LineGameKind.sheikhBeard'));
    expect(source, contains('_showNetworkQrLobby'));
  });

  test('name animal object uses pregame QR lobby', () {
    final source = File('lib/games/name_animal_object/name_animal_object_game.dart').readAsStringSync();
    expect(source, contains("title: 'اسم حيوان جماد • دعوة لاعبين'"));
    expect(source, contains('_showNetworkQrLobby'));
  });

  test('game room labels browser QR as a pregame action', () {
    final source = File('lib/core/game_room.dart').readAsStringSync();
    expect(source, contains("'فتح QR الكبير قبل اللعبة'"));
    expect(source, contains("'افتح QR الكبير وشاركه قبل ظهور لوحة اللعب'"));
  });
}
