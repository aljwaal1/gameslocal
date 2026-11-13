import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameslocal/core/app_settings.dart';
import 'package:gameslocal/games/air_hockey/air_hockey_game.dart';
import 'package:gameslocal/games/cards/cards_game.dart';
import 'package:gameslocal/games/hand51/hand51_game.dart';
import 'package:gameslocal/games/hand51/hand51_card_face.dart';
import 'package:gameslocal/games/hand51/hand51_card_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'sound_enabled': false,
      'vibration_enabled': false,
      'bot_difficulty_cards': BotDifficulty.hard.index,
    });
    await AppSettingsController.instance.load();
  });

  testWidgets(
      'Hand 51 can throw onto an empty pile after drawing its last card',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(1.3),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Hand51GameScreen(),
        ),
      ),
    ));
    final dynamic state = tester.state(find.byType(Hand51GameScreen));
    final originalCount = state.me.length;
    final pile = find.byWidgetPredicate(
        (widget) => widget is Hand51CardFace && widget.compact);
    await tester.tap(pile.first);
    await tester.pumpAndSettle();
    expect(state.discard, isEmpty);
    final hand =
        tester.getTopLeft(find.byKey(const ValueKey('hand51-viewport')));
    await tester.tapAt(hand + const Offset(17, 45));
    await tester.pumpAndSettle();
    expect(state.picks, hasLength(1));
    final dynamic chosen = state.picks.single;
    await tester.tap(find.text('الرمي'));
    await tester.pump();
    expect(state.discard, [same(chosen)]);
    expect(state.me.length, originalCount);
    expect(state.myTurn, isFalse);
    await tester.pump(const Duration(milliseconds: 550));
  });

  testWidgets('Hand 51 can select several cards for a meld', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Hand51GameScreen()));
    final dynamic state = tester.state(find.byType(Hand51GameScreen));
    state.drawDeck();
    await tester.pumpAndSettle();
    final viewport =
        tester.getRect(find.byKey(const ValueKey('hand51-viewport')));
    final layout = Hand51CardLayout(
        cardCount: state.me.length as int, viewportWidth: viewport.width);
    await tester.tapAt(viewport.topLeft + Offset(layout.step / 2, 45));
    await tester.pumpAndSettle();
    await tester.tapAt(viewport.topLeft + Offset(layout.step * 1.5, 45));
    await tester.pumpAndSettle();
    expect(state.picks, hasLength(2));
  });

  testWidgets('playing a Jack collects every rank on the Sarraqa floor',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CardsGameScreen()));
    final dynamic state = tester.state(find.byType(CardsGameScreen));
    const jack = PlayingCardModel(rank: 'J', suit: '♥');
    const seven = PlayingCardModel(rank: '7', suit: '♣');
    const queen = PlayingCardModel(rank: 'Q', suit: '♦');
    const otherJack = PlayingCardModel(rank: 'J', suit: '♠');
    state.playerHand = <PlayingCardModel>[jack];
    state.table = <PlayingCardModel>[seven, queen];
    state.botPile = <PlayingCardModel>[];
    expect(state.canCaptureOrSteal(jack), isTrue);
    state.botPile.add(otherJack);
    state.playPlayerCard(jack);
    expect(state.table, isEmpty);
    expect(state.playerPile, [jack, seven, queen]);
    expect(state.botPile, [otherJack]);
    expect(state.playerScore, 31);
    expect(state.playerBasra, 1);
    await tester.pump(const Duration(milliseconds: 550));
  });

  testWidgets('an exposed Jack and its entire last collection can be stolen',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CardsGameScreen()));
    final dynamic state = tester.state(find.byType(CardsGameScreen));
    const jack = PlayingCardModel(rank: 'J', suit: '♥');
    const rivalJack = PlayingCardModel(rank: 'J', suit: '♣');
    const seven = PlayingCardModel(rank: '7', suit: '♦');
    const rivalSeven = PlayingCardModel(rank: '7', suit: '♠');
    const queen = PlayingCardModel(rank: 'Q', suit: '♥');
    state.botHand = <PlayingCardModel>[rivalSeven, rivalJack];
    state.table = <PlayingCardModel>[seven, queen];
    state.playCard(rivalSeven, state.botHand, state.botPile, state.playerPile,
        isPlayer: false);
    state.playCard(rivalJack, state.botHand, state.botPile, state.playerPile,
        isPlayer: false);
    state.botMove();
    await tester.pump();
    expect(
        find.byKey(const ValueKey('cards-opponent-exposed')), findsOneWidget);
    expect(state.canCaptureOrSteal(jack), isTrue);
    expect(state.canCaptureOrSteal(seven), isFalse);
    state.playerHand = <PlayingCardModel>[jack];
    state.playPlayerCard(jack);
    expect(state.playerPile, [jack, rivalJack, queen]);
    expect(state.botPile, [rivalSeven, seven]);
    expect(state.playerSteals, 1);
    expect(state.playerBasra, 0);
    await tester.pump(const Duration(milliseconds: 550));
  });

  testWidgets('a newer collection covers the previous Jack collection',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CardsGameScreen()));
    final dynamic state = tester.state(find.byType(CardsGameScreen));
    const jack = PlayingCardModel(rank: 'J', suit: '♥');
    const rivalJack = PlayingCardModel(rank: 'J', suit: '♣');
    const seven = PlayingCardModel(rank: '7', suit: '♦');
    const rivalSeven = PlayingCardModel(rank: '7', suit: '♠');
    const floorSeven = PlayingCardModel(rank: '7', suit: '♣');
    const queen = PlayingCardModel(rank: 'Q', suit: '♥');
    state.botHand = <PlayingCardModel>[rivalJack, rivalSeven];
    state.table = <PlayingCardModel>[queen];
    state.playCard(rivalJack, state.botHand, state.botPile, state.playerPile,
        isPlayer: false);
    state.table.add(floorSeven);
    state.playCard(rivalSeven, state.botHand, state.botPile, state.playerPile,
        isPlayer: false);
    expect(state.canCaptureOrSteal(jack), isFalse);
    expect(state.canCaptureOrSteal(seven), isTrue);
    state.playerHand = <PlayingCardModel>[seven];
    state.playPlayerCard(seven);
    expect(state.playerPile, [seven, rivalSeven, floorSeven]);
    expect(state.botPile, [rivalJack, queen]);
    expect(state.canCaptureOrSteal(jack), isTrue);
    await tester.pump(const Duration(milliseconds: 550));
  });

  testWidgets('Sarraqa robot takes an available Basra ahead of a partial match',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CardsGameScreen()));
    final dynamic state = tester.state(find.byType(CardsGameScreen));
    const seven = PlayingCardModel(rank: '7', suit: '♥');
    const king = PlayingCardModel(rank: 'K', suit: '♥');
    const first = PlayingCardModel(rank: '7', suit: '♣');
    const second = PlayingCardModel(rank: '7', suit: '♦');
    const opponentKing = PlayingCardModel(rank: 'K', suit: '♣');
    state.botHand = <PlayingCardModel>[king, seven];
    state.table = <PlayingCardModel>[first, second];
    state.playerPile = <PlayingCardModel>[opponentKing];
    state.botMove();
    expect(state.table, isEmpty);
    expect(state.botPile, containsAll([first, second]));
    expect(state.playerPile, contains(opponentKing));
    expect(state.botBasra, 1);
    expect(state.botScore, 13);
    await tester.pump();
    expect(find.textContaining('الكمبيوتر عمل بسرا'), findsOneWidget);
  });

  testWidgets('a stopped hockey puck stays put without paddle contact',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AirHockeyGameScreen()));
    final dynamic state = tester.state(find.byType(AirHockeyGameScreen));
    await tester.tap(find.text('مع صديق'));
    await tester.pump();
    state.puck = const Offset(.5, .5);
    state.velocity = Offset.zero;
    for (var frame = 0; frame < 80; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(state.puck, const Offset(.5, .5));
    expect((state.velocity as Offset).distance, closeTo(0, 1e-9));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the lower paddle can reach a stationary puck near midfield',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: AirHockeyGameScreen()));
    final dynamic state = tester.state(find.byType(AirHockeyGameScreen));
    await tester.tap(find.text('مع صديق'));
    await tester.pump();
    final field = find.byWidgetPredicate((widget) =>
        widget is CustomPaint &&
        widget.painter.runtimeType.toString() == '_HockeyPainter');
    final bounds = tester.getRect(field);
    Offset at(double y) =>
        Offset(bounds.center.dx, bounds.top + bounds.height * y);
    state.puck = const Offset(.5, .5);
    state.velocity = Offset.zero;
    final drag = await tester.startGesture(at(.8));
    await drag.moveTo(at(.52), timeStamp: const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 16));
    expect((state.velocity as Offset).dy, lessThan(0));
    await drag.up();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tapping directly on the hockey puck does not displace it',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AirHockeyGameScreen()));
    final dynamic state = tester.state(find.byType(AirHockeyGameScreen));
    await tester.tap(find.text('مع صديق'));
    await tester.pump();
    final field = find.byWidgetPredicate((widget) =>
        widget is CustomPaint &&
        widget.painter.runtimeType.toString() == '_HockeyPainter');
    final bounds = tester.getRect(field);
    state.puck = const Offset(.5, .7);
    state.velocity = Offset.zero;
    await tester
        .tapAt(Offset(bounds.center.dx, bounds.top + bounds.height * .7));
    await tester.pump(const Duration(milliseconds: 16));
    expect(state.puck, const Offset(.5, .7));
    expect(state.velocity, Offset.zero);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a fast paddle swipe strikes a puck crossed between touch events',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AirHockeyGameScreen()));
    final dynamic state = tester.state(find.byType(AirHockeyGameScreen));
    await tester.tap(find.text('مع صديق'));
    await tester.pump();
    final field = find.byWidgetPredicate((widget) =>
        widget is CustomPaint &&
        widget.painter.runtimeType.toString() == '_HockeyPainter');
    final bounds = tester.getRect(field);
    Offset at(double x) => Offset(
        bounds.left + bounds.width * x, bounds.top + bounds.height * .72);
    state.puck = const Offset(.5, .72);
    state.velocity = Offset.zero;
    final drag = await tester.startGesture(at(.2));
    await drag.moveTo(at(.8), timeStamp: const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 16));
    expect((state.velocity as Offset).dx, greaterThan(0));
    await drag.up();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('hockey reset waits for contact and a shot keeps its pace',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AirHockeyGameScreen()));
    final dynamic state = tester.state(find.byType(AirHockeyGameScreen));
    await tester.tap(find.text('مع صديق'));
    expect(state.velocity, Offset.zero);
    await tester.pump();
    final Size field = state.fieldSize;
    state.puck = const Offset(.35, .5);
    state.velocity = Offset(300 / field.width, 0);
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final Offset puck = state.puck;
    final Offset velocity = state.velocity;
    expect(puck.dx, greaterThan(.35 + 70 / field.width));
    expect(velocity.dx * field.width, greaterThan(255));
    await tester.pumpWidget(const SizedBox());
  });
}
