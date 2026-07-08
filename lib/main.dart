import 'package:flutter/material.dart';

import 'core/game_definition.dart';
import 'core/game_room.dart';
import 'games/checkers/checkers_game.dart';
import 'games/chess/chess_placeholder.dart';
import 'games/domino/domino_placeholder.dart';
import 'games/cards/cards_placeholder.dart';

void main() {
  runApp(const GamesLocalApp());
}

class GamesLocalApp extends StatelessWidget {
  const GamesLocalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ألعاب محلية',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF26736A),
        scaffoldBackgroundColor: const Color(0xFFF4F7F6),
        fontFamily: 'Roboto',
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  HomeScreen({super.key});

  final List<GameDefinition> games = [
    GameDefinition(
      id: 'checkers',
      name: 'الضامة',
      playersText: 'لاعبان',
      status: 'جاهزة كبداية محلية',
      builder: (_) => const CheckersGameScreen(),
    ),
    GameDefinition(
      id: 'chess',
      name: 'الشطرنج',
      playersText: 'لاعبان',
      status: 'مجلد مستقل للتطوير لاحقًا',
      builder: (_) => const ChessPlaceholderScreen(),
    ),
    GameDefinition(
      id: 'domino',
      name: 'الدومينو',
      playersText: '2 إلى 4 لاعبين',
      status: 'مجلد مستقل للتطوير لاحقًا',
      builder: (_) => const DominoPlaceholderScreen(),
    ),
    GameDefinition(
      id: 'cards',
      name: 'الشدة / السراقة',
      playersText: '2 إلى 4 لاعبين',
      status: 'مجلد مستقل للتطوير لاحقًا',
      builder: (_) => const CardsPlaceholderScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ألعاب محلية'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _HeroCard(),
          const SizedBox(height: 16),
          for (final game in games) _GameCard(game: game),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'نسخة البداية V1',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'التطبيق مصمم بحيث تكون كل لعبة داخل مجلد مستقل، والاتصال والغرف في core حتى نعدل كل لعبة لوحدها بدون تخريب الباقي.',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game});
  final GameDefinition game;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        title: Text(game.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${game.playersText} • ${game.status}'),
        trailing: const Icon(Icons.arrow_back_ios_new),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Directionality(
                textDirection: TextDirection.rtl,
                child: GameRoomScreen(game: game),
              ),
            ),
          );
        },
      ),
    );
  }
}
