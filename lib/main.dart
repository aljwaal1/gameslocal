import 'package:flutter/material.dart';

import 'core/audio_feedback.dart';
import 'core/app_settings.dart';
import 'core/game_definition.dart';
import 'core/game_room.dart';
import 'design/app_theme.dart';
import 'games/cards/cards_game.dart';
import 'games/checkers/checkers_game.dart';
import 'games/chess/chess_game.dart';
import 'games/domino/domino_game.dart';
import 'games/football/professional_penalty_game.dart';
import 'games/line_games/line_games.dart';
import 'games/name_animal_object/name_animal_object_game.dart';
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
      builder: (context, child) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => GameFeedback.uiTap(),
        child: child ?? const SizedBox.shrink(),
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
      id: 'football_penalties',
      name: 'ركلات الترجيح',
      playersText: 'لاعب ضد روبوت أو لاعبان LAN',
      status: 'Penalty Arena Pro بمنظور وحركة دقيقة',
      builder: (_, networkCore) =>
          ProPenaltyShootoutGameScreen(networkCore: networkCore),
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
    GameDefinition(
      id: 'name_animal_object',
      name: 'اسم حيوان جماد',
      playersText: 'عدة لاعبين عبر LAN',
      status: 'كل لاعب على هاتفه ضمن نفس Wi-Fi أو Hotspot',
      builder: (_, __) => const NameAnimalObjectGameScreen(),
    ),
    GameDefinition(
      id: 'sheikh_beard',
      name: 'لحية الشيخ',
      playersText: 'لاعبان أو أكثر عبر LAN والآيفون',
      status: 'اختيار نقاط وتكوين خطوط مع أدوار متزامنة',
      builder: (_, networkCore) => LineGameScreen(
        kind: LineGameKind.sheikhBeard,
        networkCore: networkCore,
      ),
    ),
    GameDefinition(
      id: 'dots_boxes',
      name: 'المربعات',
      playersText: 'لاعبان أو أكثر عبر LAN والآيفون',
      status: 'أكمل المربع لتحصل على نقطة ودور إضافي',
      builder: (_, networkCore) => LineGameScreen(
        kind: LineGameKind.dotsBoxes,
        networkCore: networkCore,
      ),
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final columns = width < 390
                        ? 1
                        : width < 850
                            ? 2
                            : width < 1250
                                ? 3
                                : 4;
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: columns == 1 ? 2.05 : 1.20,
                      ),
                      itemCount: games.length,
                      itemBuilder: (context, index) =>
                          _GameCard(game: games[index]),
                    );
                  },
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
      height: 142,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: AppColors.heroGradient,
          stops: <double>[0, .52, 1],
        ),
        border: Border.all(color: const Color(0x33FFFFFF)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x4D075985),
            blurRadius: 28,
            spreadRadius: -5,
            offset: Offset(0, 12),
          ),
          BoxShadow(
            color: Color(0x336D28D9),
            blurRadius: 34,
            spreadRadius: -12,
            offset: Offset(-8, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.accent,
              child: Icon(
                Icons.sports_esports,
                color: AppColors.primaryDark,
                size: 36,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'GamesLocal',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'ألعاب محلية • روبوت • شبكة محلية',
                    style: TextStyle(fontSize: 14, color: Colors.white),
                  ),
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
                  content: Text(
                    'اختر كرة القدم أو إكس أو أو الضامة أو الدومينو أو الشدة للعب ضد الروبوت.',
                  ),
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
  const _ModeChip({
    required this.icon,
    required this.text,
    required this.color,
    required this.onTap,
  });

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
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: <Color>[
              color.withValues(alpha: .18),
              Colors.white,
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: .30)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withValues(alpha: .10),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
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

  bool get usesGameRoom => const <String>{
        'football_penalties',
        'xo',
        'checkers',
        'domino',
        'cards',
        'name_animal_object',
        'sheikh_beard',
        'dots_boxes',
      }.contains(game.id);

  bool get experimental => !const <String>{
        'xo',
        'checkers',
        'domino',
        'football_penalties',
        'name_animal_object',
        'sheikh_beard',
        'dots_boxes',
      }.contains(game.id);
  String get releaseLabel => experimental ? 'تجريبية' : 'جاهزة';
  Color get releaseColor =>
      experimental ? const Color(0xFFFF9F1C) : const Color(0xFF2A9D8F);

  IconData get icon {
    switch (game.id) {
      case 'football_penalties':
        return Icons.sports_soccer;
      case 'xo':
        return Icons.close;
      case 'checkers':
        return Icons.grid_4x4;
      case 'chess':
        return Icons.account_tree;
      case 'domino':
        return Icons.dashboard_customize;
      case 'name_animal_object':
        return Icons.edit_note;
      case 'sheikh_beard':
        return Icons.linear_scale;
      case 'dots_boxes':
        return Icons.grid_on;
      default:
        return Icons.style;
    }
  }

  Color get color {
    switch (game.id) {
      case 'football_penalties':
        return const Color(0xFF0B7A3B);
      case 'xo':
        return const Color(0xFFE63946);
      case 'checkers':
        return const Color(0xFF2A9D8F);
      case 'domino':
        return const Color(0xFFF4A261);
      case 'chess':
        return const Color(0xFF264653);
      case 'name_animal_object':
        return const Color(0xFF7B2CBF);
      case 'sheikh_beard':
        return const Color(0xFF8E44AD);
      case 'dots_boxes':
        return const Color(0xFF247BA0);
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
            builder: (routeContext) => Directionality(
              textDirection: TextDirection.rtl,
              child: usesGameRoom
                  ? GameRoomScreen(game: game)
                  : game.builder(routeContext, null),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: <Color>[
              Color.lerp(color, Colors.white, .90)!,
              Colors.white,
            ],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: color.withValues(alpha: .18)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withValues(alpha: .13),
              blurRadius: 20,
              spreadRadius: -6,
              offset: const Offset(0, 9),
            ),
            const BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
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
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: <Color>[
                        color,
                        Color.lerp(color, AppColors.secondary, .32)!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: color.withValues(alpha: .28),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: AppColors.ink,
              ),
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
