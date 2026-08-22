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
      status: 'ضد الروبوت بثلاثة مستويات أو لاعب عبر LAN',
      builder: (_, networkCore) => ChessGameScreen(networkCore: networkCore),
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
      builder: (_, networkCore) =>
          NameAnimalObjectGameScreen(networkCore: networkCore),
    ),
    GameDefinition(
      id: 'sheikh_beard',
      name: 'لعبة اللحية',
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
        child: CustomScrollView(
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              sliver: SliverToBoxAdapter(
                child: _HeroCard(gameCount: games.length),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(14, 16, 14, 0),
              sliver: SliverToBoxAdapter(
                child: _SectionHeader(
                  eyebrow: 'طرق اللعب',
                  title: 'ابدأ بالطريقة التي تناسبكم',
                  subtitle: 'على نفس الجهاز، ضد الروبوت، أو عبر الشبكة المحلية.',
                ),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(14, 10, 14, 0),
              sliver: SliverToBoxAdapter(child: _ModeStrip()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 20, 14, 10),
              sliver: SliverToBoxAdapter(
                child: _SectionHeader(
                  eyebrow: 'مكتبة الألعاب',
                  title: '${games.length} ألعاب جاهزة للّعب',
                  subtitle: 'اختر اللعبة ثم حدّد نمط اللعب من غرفتها.',
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 340,
                  mainAxisExtent: 202,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _GameCard(game: games[index]),
                  childCount: games.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.gameCount});

  final int gameCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: AppColors.heroGradient,
          stops: <double>[0, .56, 1],
        ),
        border: Border.all(color: const Color(0x2FFFFFFF)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33073B3A),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          const PositionedDirectional(
            start: -34,
            top: -42,
            child: _GlowOrb(size: 126, color: Color(0x24FFFFFF)),
          ),
          const PositionedDirectional(
            end: -28,
            bottom: -52,
            child: _GlowOrb(size: 150, color: Color(0x1FF5B82E)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x44000000),
                            blurRadius: 14,
                            offset: Offset(0, 7),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.sports_esports_rounded,
                        color: AppColors.primaryDark,
                        size: 34,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'GamesLocal',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.5,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'جلسة لعب واحدة تجمعكم بدون إنترنت',
                            style: TextStyle(
                              color: Color(0xFFEAF7F5),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _HeroActionButton(
                      tooltip: 'الإعدادات',
                      icon: Icons.tune_rounded,
                      onTap: () {
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
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _FeaturePill(
                      icon: Icons.extension_rounded,
                      label: '$gameCount ألعاب',
                    ),
                    const _FeaturePill(
                      icon: Icons.smart_toy_rounded,
                      label: 'روبوت',
                    ),
                    const _FeaturePill(
                      icon: Icons.wifi_tethering_rounded,
                      label: 'LAN / Hotspot',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Ink(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0x18FFFFFF),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: const Color(0x36FFFFFF)),
            ),
            child: Icon(icon, color: Colors.white, size: 25),
          ),
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x16FFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x30FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          eyebrow,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: .3,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _ModeStrip extends StatelessWidget {
  const _ModeStrip();

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      _ModeActionCard(
        icon: Icons.smart_toy_rounded,
        title: 'ضد الروبوت',
        subtitle: 'ابدأ فورًا بدون لاعب ثانٍ',
        accent: AppColors.secondary,
        onTap: () {
          GameFeedback.tap();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'اختر كرة القدم أو إكس أو أو الضامة أو الدومينو أو الشدة للعب ضد الروبوت.',
              ),
            ),
          );
        },
      ),
      _ModeActionCard(
        icon: Icons.wifi_tethering_rounded,
        title: 'شبكة LAN',
        subtitle: 'هواتف متعددة على نفس الشبكة',
        accent: AppColors.primary,
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
      _ModeActionCard(
        icon: Icons.router_rounded,
        title: 'Wi‑Fi كلاسيكي',
        subtitle: 'مدخل التوافق للشبكة القديمة',
        accent: AppColors.cyan,
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
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 680;
        if (stacked) {
          return Column(
            children: <Widget>[
              actions[0],
              const SizedBox(height: 9),
              actions[1],
              const SizedBox(height: 9),
              actions[2],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: actions[0]),
            const SizedBox(width: 10),
            Expanded(child: actions[1]),
            const SizedBox(width: 10),
            Expanded(child: actions[2]),
          ],
        );
      },
    );
  }
}

class _ModeActionCard extends StatelessWidget {
  const _ModeActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 92),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.hairline),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x120F172A),
                  blurRadius: 14,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(.11),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: accent.withOpacity(.18)),
                  ),
                  child: Icon(icon, color: accent, size: 26),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: accent.withOpacity(.72),
                  size: 17,
                ),
              ],
            ),
          ),
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
        'chess',
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
      experimental ? const Color(0xFFD97706) : AppColors.success;

  IconData get icon {
    switch (game.id) {
      case 'football_penalties':
        return Icons.sports_soccer_rounded;
      case 'xo':
        return Icons.close_rounded;
      case 'checkers':
        return Icons.grid_4x4_rounded;
      case 'chess':
        return Icons.account_tree_rounded;
      case 'domino':
        return Icons.dashboard_customize_rounded;
      case 'cards':
        return Icons.style_rounded;
      case 'name_animal_object':
        return Icons.edit_note_rounded;
      case 'sheikh_beard':
        return Icons.linear_scale_rounded;
      case 'dots_boxes':
        return Icons.grid_on_rounded;
      default:
        return Icons.extension_rounded;
    }
  }

  Color get color {
    switch (game.id) {
      case 'football_penalties':
        return const Color(0xFF087A46);
      case 'xo':
        return const Color(0xFFD9485F);
      case 'checkers':
        return AppColors.primary;
      case 'domino':
        return const Color(0xFFD97706);
      case 'chess':
        return const Color(0xFF334155);
      case 'cards':
        return const Color(0xFFB42358);
      case 'name_animal_object':
        return AppColors.secondary;
      case 'sheikh_beard':
        return const Color(0xFF7C3AED);
      case 'dots_boxes':
        return AppColors.cyan;
      default:
        return AppColors.secondary;
    }
  }

  String get connectionLabel {
    if (game.id == 'chess') return 'محلي';
    if (usesGameRoom) return 'محلي / شبكة';
    return 'محلي';
  }

  void _open(BuildContext context) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'فتح لعبة ${game.name}',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _open(context),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.hairline),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x160F172A),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: <Color>[color, color.withOpacity(.68)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: color.withOpacity(.20),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 28),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: releaseColor.withOpacity(.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: releaseColor.withOpacity(.22)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: releaseColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            releaseLabel,
                            style: TextStyle(
                              color: releaseColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  game.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  game.status,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const Spacer(),
                Row(
                  children: <Widget>[
                    Icon(Icons.people_alt_rounded, color: color, size: 16),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        game.playersText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.inkSoft,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(.08),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        connectionLabel,
                        style: TextStyle(
                          color: color,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
