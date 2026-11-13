import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/core/app_settings.dart';
import 'package:gameslocal/games/cards/cards_game.dart';
import 'package:gameslocal/games/hand51/hand51_card_face.dart';
import 'package:gameslocal/games/hand51/hand51_card_layout.dart';
import 'package:gameslocal/games/hand51/hand51_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  final directory = Platform.environment['CARD_CAPTURE_DIR'];
  if (directory == null) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    final fontPath = Platform.environment['CARD_CAPTURE_FONT'];
    if (fontPath != null) {
      final bytes = await File(fontPath).readAsBytes();
      final font = FontLoader('Roboto')
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await font.load();
      final iconPath = Platform.environment['CARD_CAPTURE_ICON_FONT'];
      if (iconPath != null) {
        final iconBytes = await File(iconPath).readAsBytes();
        final icons = FontLoader('MaterialIcons')
          ..addFont(Future.value(ByteData.sublistView(iconBytes)));
        await icons.load();
      }
    }
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues(
        {'sound_enabled': false, 'vibration_enabled': false});
    await AppSettingsController.instance.load();
  });
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(844, 390)
  ]) {
    for (final game in ['cards', 'hand51']) {
      testWidgets('$game fits $size at text scale 1.3', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(MaterialApp(
            home: MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(1.3)),
          child: RepaintBoundary(
              key: key,
              child: game == 'cards'
                  ? const CardsGameScreen()
                  : const Hand51GameScreen()),
        )));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (game == 'cards') {
          expect(find.byType(PlayingCardHand), findsOneWidget);
          final hand =
              tester.widget<PlayingCardHand>(find.byType(PlayingCardHand));
          expect(hand.cards.length, 4);
          if (size.width == 320) {
            final tableCard = find.byType(PlayingCardView).first;
            final tableViewport = find
                .ancestor(
                    of: tableCard, matching: find.byType(SingleChildScrollView))
                .first;
            expect(tester.getSize(tableViewport).height,
                greaterThanOrEqualTo(tester.getSize(tableCard).height));
          }
        }
        await capture(
            tester, key, '$game-${size.width.toInt()}x${size.height.toInt()}');
      });
    }
  }
  testWidgets('long Hand51 meld stays inside its table at 320', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(
          size: Size(320, 640), textScaler: TextScaler.linear(1.3)),
      child: const Hand51GameScreen(),
    )));
    final dynamic state = tester.state(find.byType(Hand51GameScreen));
    // Build an actual eight-card run from the game's existing deck model.
    state.deck.addAll(state.me);
    state.deck.addAll(state.bot);
    state.deck.addAll(state.discard);
    final run = state.deck
        .where((dynamic card) => card.suit == '♠' && card.rank <= 8)
        .toList();
    expect(run.length, 8);
    state.melds.add(run);
    state.drawDeck();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('all hand51 face identities are legible including joker',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    final ranks = ['A', '10', 'J', 'Q', 'K', 'JOKER'];
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(
          size: Size(320, 640), textScaler: TextScaler.linear(1.3)),
      child: RepaintBoundary(
          key: key,
          child: Scaffold(
              body: SingleChildScrollView(
                  child: Column(children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final rank in ranks)
                Hand51CardFace(rank: rank, suit: '♥', joker: rank == 'JOKER')
            ]),
            Hand51HandView(
                cardCount: 20,
                onSelected: (_) {},
                cardBuilder: (context, index) => Hand51CardFace(
                    rank: ranks[index % ranks.length],
                    suit: index.isEven ? '♥' : '♠',
                    joker: index % ranks.length == 5)),
          ])))),
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'hand51-identities-and-20-cards');
  });
}
