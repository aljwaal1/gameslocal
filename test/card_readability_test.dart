import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/games/cards/cards_game.dart';
import 'package:gameslocal/games/hand51/hand51_card_layout.dart';

void main() {
  for (final scale in [1.0, 1.3]) {
    testWidgets('large card identities fit at text scale $scale',
        (tester) async {
      for (final compact in [false, true]) {
        for (final rank in ['A', '10', 'J', 'Q', 'K']) {
          await tester.pumpWidget(MaterialApp(
              home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
                body: Center(
                    child: PlayingCardView(
              card: PlayingCardModel(rank: rank, suit: '♥'),
              compact: compact,
            ))),
          )));
          expect(tester.takeException(), isNull);
          final identity =
              tester.widget<Text>(find.byKey(const ValueKey('card-main-rank')));
          final suit =
              tester.widget<Text>(find.byKey(const ValueKey('card-main-suit')));
          expect(identity.style!.fontSize,
              greaterThanOrEqualTo(compact ? 24 : 30));
          expect(suit.style!.fontSize, greaterThanOrEqualTo(compact ? 24 : 32));
          expect(find.byKey(const ValueKey('card-top-corner')), findsOneWidget);
          expect(
              find.byKey(const ValueKey('card-bottom-corner')), findsOneWidget);
        }
      }
    });

    testWidgets('four full cards remain in one touchable row at 320 and $scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final selected = <int>[];
      final cards = ['A', '10', 'Q', 'K']
          .map((r) => PlayingCardModel(rank: r, suit: '♠'))
          .toList();
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
        data: MediaQueryData(
            size: const Size(320, 640), textScaler: TextScaler.linear(scale)),
        child: Scaffold(
            body: Padding(
                padding: const EdgeInsets.all(10),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child:
                      PlayingCardHand(cards: cards, onSelected: selected.add),
                ))),
      )));
      for (var i = 0; i < 4; i++) {
        final target = find.byKey(ValueKey('playing-hand-$i'));
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
      }
      expect(selected, [0, 1, 2, 3]);
      expect(tester.takeException(), isNull);
      final ys = List.generate(4,
          (i) => tester.getTopLeft(find.byKey(ValueKey('playing-hand-$i'))).dy);
      expect(ys.toSet().length, 1);
    });
  }

  test('20 card geometry exposes readable headers and maps scrolled touch', () {
    final layout =
        Hand51CardLayout(cardCount: 20, viewportWidth: 320, textScale: 1.3);
    expect(layout.step, greaterThanOrEqualTo(24));
    expect(layout.contentWidth, greaterThan(320));
    for (var i = 0; i < 20; i++) {
      final x = layout.leftFor(i) + layout.step / 2;
      expect(layout.indexAt(x), i);
      final scroll = (x - 160).clamp(0.0, layout.contentWidth - 320);
      expect(layout.indexAt(x - scroll, scrollOffset: scroll), i);
    }
    expect(layout.angleFor(10).abs(), lessThan(.02));
  });

  testWidgets('20-card hand selects first, middle, last after real scroll',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final selected = <int>[];
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
      child: Scaffold(
          body: Align(
              alignment: Alignment.bottomCenter,
              child: Hand51HandView(
                cardCount: 20,
                controller: controller,
                onSelected: selected.add,
                cardBuilder: (context, index) =>
                    ColoredBox(color: Colors.white, child: Text('$index')),
              ))),
    )));
    final layout =
        Hand51CardLayout(cardCount: 20, viewportWidth: 320, textScale: 1.3);
    final origin =
        tester.getTopLeft(find.byKey(const ValueKey('hand51-viewport')));
    for (final i in [0, 10, 19, 0]) {
      final x = layout.leftFor(i) +
          (i == 19 ? layout.cardWidth / 2 : layout.step / 2);
      final offset = (x - 160).clamp(0.0, controller.position.maxScrollExtent);
      controller.jumpTo(offset);
      await tester.pump();
      await tester.tapAt(origin + Offset(x - offset, layout.height - 30));
      await tester.pump();
    }
    expect(selected, [0, 10, 19, 0]);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'raised selected card remains selectable in overlapping top strip after scroll',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final selected = <int>[];
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
      child: Scaffold(
          body: Align(
              alignment: Alignment.bottomCenter,
              child: Hand51HandView(
                cardCount: 20,
                selectedIndices: const {0, 10},
                controller: controller,
                onSelected: selected.add,
                cardBuilder: (context, index) =>
                    const ColoredBox(color: Colors.white),
              ))),
    )));
    final origin =
        tester.getTopLeft(find.byKey(const ValueKey('hand51-viewport')));
    await tester.tapAt(origin + const Offset(60, 12));
    controller.jumpTo(400);
    await tester.pump();
    await tester.tapAt(origin + const Offset(70, 12));
    expect(selected, [0, 10]);
  });
}
