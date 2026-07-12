import 'package:flutter/material.dart';

import 'core/audio_feedback.dart';
import 'core/app_settings.dart';
import 'core/game_definition.dart';
import 'core/game_room.dart';
import 'design/app_theme.dart';
import 'games/battle/battle_mode_screen.dart';
import 'games/cards/cards_game.dart';
import 'games/checkers/checkers_game.dart';
import 'games/chess/chess_game.dart';
import 'games/chicken/chicken_game.dart';
import 'games/domino/domino_game.dart';
import 'games/xo/xo_game.dart';
import 'lan/screens/lan_home_screen.dart';
import 'network/wifi_lobby_screen.dart';
import 'settings/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettingsController.instance.load();
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
      id: 'battle',
      name: 'Battle Mode',
      playersText: '1 ضد 1',
      status: 'ضد الكمبيوتر أو لاعب عبر الشبكة',
      builder: (_, networkCore) => BattleModeScreen(networkCore: networkCore),
    ),
    GameDefinition(
      id: 'xo',
      name: 'إكس أو',
      playersText: 'لاعبان',
      status: 'ضد لاعب أو ضد الكمبيوتر',
      builder: (_, networkCore) => XoGameScreen(networkCore: networkCore),
    ),
    GameDefinition(
      id: 'checkers',
      name: 'الضامة',
      playersText: 'لاعبان',
      status: 'ضد لاعب أو ضد الكمبيوتر',
      builder: (_, networkCore) => CheckersGameScreen(networkCore: networkCore),
    ),
    GameDefinition(
      id: 'domino',
      name: 'الدومينو',
      playersText: '2 عبر الشبكة / 4 محليًا',
      status: 'ضد الكمبيوتر أو لاعب عبر الشبكة أو 4 لاعبين محليًا',
      builder: (_, networkCore) => DominoGameScreen(networkCore: networkCore),
    ),
    GameDefinition(
      id: 'chicken',
      name: 'لعبة الدجاجة',
      playersText: 'لاعب واحد',
      status: 'نسخة أركيد أولى',
      builder: (_, __) => const ChickenGameScreen(),
    ),
    GameDefinition(
      id: 'chess',
      name: 'الشطرنج',
      playersText: 'لاعبان',
      status: 'لعبة محلية كاملة للاعبين',
      builder: (_, __) => const ChessGameScreen(),
    ),
    GameDefinition(
      id: 'cards',
      name: 'الشدة / السراقة',
      playersText: 'لاعبان',
      status: 'السراقة ضد الروبوت أو لاعب عبر الشبكة',
      builder: (_, networkCore) => CardsGameScreen(networkCore: networkCore),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              const _HeroCard(),
              const SizedBox(height: 10),
              const _ModeStrip(),
              const SizedBox(height: 10),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.20,
                  children: [for (final game in games) _GameCard(game: game)],
                ),
              ),
            ],
          ),
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
      height: 128,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF1F6F63), Color(0xFF7B2CBF)],
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.accent,
              child: Icon(Icons.sports_esports, color: AppColors.primaryDark, size: 36),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'GamesLocal',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 4),
                  Text('ألعاب محلية • روبوت • شبكة محلية', style: TextStyle(fontSize: 14, color: Colors.white)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'الإعدادات',
              onPressed: () {
                GameFeedback.tap();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const Directionality(
                      textDirection: TextDirection.rtl,
                      child: SettingsScreen(),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.settings, color: Colors.white),
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
    return Row(
      children: [
        Expanded(
          child: _ModeChip(
            icon: Icons.smart_toy,
            text: 'روبوت',
            color: const Color(0xFF7B2CBF),
            onTap: () {
              GameFeedback.tap();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text('اختر Battle أو إكس أو أو الضامة أو الدومينو أو الشدة للعب ضد الروبوت.'),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ModeChip(
            icon: Icons.wifi_tethering,
            text: 'LAN',
            color: const Color(0xFF00A896),
            onTap: () {
              GameFeedback.tap();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const Directionality(
                    textDirection: TextDirection.rtl,
                    child: LanHomeScreen(),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ModeChip(
            icon: Icons.wifi,
            text: 'Wi‑Fi قديم',
            color: const Color(0xFFFF9F1C),
            onTap: () {
              GameFeedback.tap();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const Directionality(
                    textDirection: TextDirection.rtl,
                    child: WifiLobbyScreen(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.icon, required this.text, required this.color, required this.onTap});

  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
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

  bool get experimental => game.id == 'battle' || game.id == 'chicken';
  String get releaseLabel => experimental ? 'تجريبية' : 'جاهزة';
  Color get releaseColor => experimental ? const Color(0xFFFF9F1C) : const Color(0xFF2A9D8F);

  IconData get icon {
    switch (game.id) {
      case 'battle':
        return Icons.sports_martial_arts;
      case 'xo':
        return Icons.close;
      case 'checkers':
        return Icons.grid_4x4;
      case 'chess':
        return Icons.account_tree;
      case 'domino':
        return Icons.dashboard_customize;
      case 'chicken':
        return Icons.egg_alt;
      default:
        return Icons.style;
    }
  }

  Color get color {
    switch (game.id) {
      case 'battle':
        return const Color(0xFFD62828);
      case 'xo':
        return const Color(0xFFE63946);
      case 'checkers':
        return const Color(0xFF2A9D8F);
      case 'domino':
        return const Color(0xFFF4A261);
      case 'chess':
        return const Color(0xFF264653);
      case 'chicken':
        return const Color(0xFFFF9F1C);
      default:
        return const Color(0xFF7B2CBF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        GameFeedback.tap();
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
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 5)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color, color.withOpacity(0.65)]),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: releaseColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: releaseColor.withOpacity(0.35)),
                  ),
                  child: Text(
                    releaseLabel,
                    style: TextStyle(
                      color: releaseColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              game.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.ink),
            ),
            const SizedBox(height: 3),
            Text(
              game.playersText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
