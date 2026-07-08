import 'package:flutter/material.dart';

import 'core/game_definition.dart';
import 'core/game_room.dart';
import 'design/app_theme.dart';
import 'games/checkers/checkers_game.dart';
import 'games/chess/chess_placeholder.dart';
import 'games/domino/domino_placeholder.dart';
import 'games/cards/cards_placeholder.dart';
import 'games/xo/xo_game.dart';

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
      theme: AppThemeFactory.light(),
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
      id: 'xo',
      name: 'إكس أو',
      playersText: 'لاعبان',
      status: 'ضد لاعب أو ضد الكمبيوتر',
      builder: (_) => const XoGameScreen(),
    ),
    GameDefinition(
      id: 'checkers',
      name: 'الضامة',
      playersText: 'لاعبان',
      status: 'ضد لاعب أو ضد الكمبيوتر',
      builder: (_) => const CheckersGameScreen(),
    ),
    GameDefinition(
      id: 'chess',
      name: 'الشطرنج',
      playersText: 'لاعبان',
      status: 'قيد التطوير ضمن مجلد مستقل',
      builder: (_) => const ChessPlaceholderScreen(),
    ),
    GameDefinition(
      id: 'domino',
      name: 'الدومينو',
      playersText: '2 إلى 4 لاعبين',
      status: 'قيد التطوير ضمن مجلد مستقل',
      builder: (_) => const DominoPlaceholderScreen(),
    ),
    GameDefinition(
      id: 'cards',
      name: 'الشدة / السراقة',
      playersText: '2 إلى 4 لاعبين',
      status: 'قيد التطوير ضمن مجلد مستقل',
      builder: (_) => const CardsPlaceholderScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _HeroCard(),
            const SizedBox(height: 16),
            const _ModeStrip(),
            const SizedBox(height: 16),
            const Text('الألعاب', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.ink)),
            const SizedBox(height: 10),
            for (final game in games) _GameCard(game: game),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Icon(Icons.sports_esports, color: AppColors.accent, size: 42),
            SizedBox(height: 14),
            Text(
              'GamesLocal',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            SizedBox(height: 8),
            Text(
              'منصة ألعاب محلية احترافية: ضد الكمبيوتر، على نفس الجهاز، ثم عبر Wi‑Fi وBluetooth. كل لعبة مستقلة حتى نطور لعبة لعبة بدون تخريب الباقي.',
              style: TextStyle(fontSize: 15, height: 1.55, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeStrip extends StatelessWidget {
  const _ModeStrip();

  @override
  Widget build(BuildContext context) {
    const items = [
      _ModeChip(icon: Icons.smart_toy, text: 'ضد الكمبيوتر'),
      _ModeChip(icon: Icons.people, text: 'نفس الجهاز'),
      _ModeChip(icon: Icons.wifi, text: 'Wi‑Fi لاحقًا'),
      _ModeChip(icon: Icons.bluetooth, text: 'Bluetooth لاحقًا'),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => items[i],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game});
  final GameDefinition game;

  IconData get icon {
    switch (game.id) {
      case 'xo':
        return Icons.close;
      case 'checkers':
        return Icons.grid_4x4;
      case 'chess':
        return Icons.account_tree;
      case 'domino':
        return Icons.dashboard_customize;
      default:
        return Icons.style;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.10), borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(game.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.ink)),
        subtitle: Text('${game.playersText} • ${game.status}', style: const TextStyle(color: AppColors.muted)),
        trailing: const Icon(Icons.arrow_back_ios_new, color: AppColors.primary),
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
