import 'package:flutter/material.dart';

import '../../core/audio_feedback.dart';
import '../../core/game_definition.dart';
import '../../core/game_room.dart';
import '../../design/app_theme.dart';
import '../../games/cards/cards_game.dart';
import '../../games/checkers/checkers_game.dart';
import '../../games/domino/domino_game.dart';
import '../../games/football/professional_penalty_game.dart';
import '../../games/line_games/line_games.dart';
import '../../games/name_animal_object/name_animal_object_game.dart';
import '../../games/xo/xo_game.dart';

class LanHomeScreen extends StatelessWidget {
  const LanHomeScreen({super.key});

  static final List<GameDefinition> _games = <GameDefinition>[
    GameDefinition(
      id: 'football_penalties',
      name: 'ركلات الترجيح',
      playersText: 'لاعبان على نفس الشبكة',
      status: 'مباراة مباشرة عبر Wi-Fi أو Hotspot',
      builder: (_, networkCore) =>
          ProPenaltyShootoutGameScreen(networkCore: networkCore),
    ),
    GameDefinition(
      id: 'xo',
      name: 'إكس أو',
      playersText: 'لاعبان',
      status: 'تطبيق أو متصفح عبر QR على نفس الشبكة',
      builder: (_, networkCore) => XoGameScreen(networkCore: networkCore),
    ),
    GameDefinition(
      id: 'checkers',
      name: 'الضامة',
      playersText: 'لاعبان',
      status: 'تطبيق أو متصفح عبر QR على نفس الشبكة',
      builder: (_, networkCore) => CheckersGameScreen(networkCore: networkCore),
    ),
    GameDefinition(
      id: 'domino',
      name: 'الدومينو',
      playersText: 'لاعبان عبر الشبكة',
      status: 'غرفة محلية بين جهازين',
      builder: (_, networkCore) => DominoGameScreen(networkCore: networkCore),
    ),
    GameDefinition(
      id: 'cards',
      name: 'الشدة / السراقة',
      playersText: 'لاعبان عبر الشبكة',
      status: 'جولة متزامنة بين المضيف والضيف',
      builder: (_, networkCore) => CardsGameScreen(networkCore: networkCore),
    ),
    GameDefinition(
      id: 'name_animal_object',
      name: 'اسم حيوان جماد',
      playersText: 'عدة لاعبين',
      status: 'كل لاعب على هاتفه أو عبر المتصفح',
      builder: (_, __) => const NameAnimalObjectGameScreen(),
    ),
    GameDefinition(
      id: 'sheikh_beard',
      name: 'لعبة اللحية',
      playersText: 'لاعبان أو أكثر',
      status: 'أدوار متزامنة مع دعم المتصفح عبر QR',
      builder: (_, networkCore) => LineGameScreen(
        kind: LineGameKind.sheikhBeard,
        networkCore: networkCore,
      ),
    ),
    GameDefinition(
      id: 'dots_boxes',
      name: 'المربعات',
      playersText: 'لاعبان أو أكثر',
      status: 'مربعات متزامنة مع دعم المتصفح عبر QR',
      builder: (_, networkCore) => LineGameScreen(
        kind: LineGameKind.dotsBoxes,
        networkCore: networkCore,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اللعب عبر الشبكة المحلية')),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: <Widget>[
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(14, 8, 14, 0),
              sliver: SliverToBoxAdapter(child: _LanHero()),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(14, 18, 14, 10),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'اختر اللعبة',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'افتح غرفة اللعبة مباشرة',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'بعد اختيار اللعبة تستطيع إنشاء غرفة أو البحث عن المضيف على نفس Wi-Fi أو Hotspot.',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 360,
                  mainAxisExtent: 154,
                  crossAxisSpacing: 11,
                  mainAxisSpacing: 11,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _LanGameCard(game: _games[index]),
                  childCount: _games.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanHero extends StatelessWidget {
  const _LanHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: <Color>[
            AppColors.primaryDark,
            AppColors.primary,
            AppColors.cyan,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x28FFFFFF)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x2A073B3A),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0x20FFFFFF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x38FFFFFF)),
                ),
                child: const Icon(
                  Icons.wifi_tethering_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'LAN Play',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'بدون إنترنت • نفس الشبكة المحلية',
                      style: TextStyle(
                        color: Color(0xFFE5F7F5),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x14FFFFFF),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Row(
              children: <Widget>[
                Icon(Icons.info_outline_rounded, color: Color(0xFFCCFBF1)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'اجعل الأجهزة على Wi-Fi نفسه أو فعّل Hotspot، ثم اختر اللعبة وأنشئ غرفة من الجهاز المضيف.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LanGameCard extends StatelessWidget {
  const _LanGameCard({required this.game});

  final GameDefinition game;

  Color get accent {
    switch (game.id) {
      case 'football_penalties':
        return const Color(0xFF087A46);
      case 'xo':
        return const Color(0xFFD9485F);
      case 'checkers':
        return AppColors.primary;
      case 'domino':
        return const Color(0xFFD97706);
      case 'cards':
        return const Color(0xFFB42358);
      case 'name_animal_object':
        return AppColors.secondary;
      case 'sheikh_beard':
        return const Color(0xFF7C3AED);
      case 'dots_boxes':
        return AppColors.cyan;
      default:
        return AppColors.primary;
    }
  }

  IconData get icon {
    switch (game.id) {
      case 'football_penalties':
        return Icons.sports_soccer_rounded;
      case 'xo':
        return Icons.close_rounded;
      case 'checkers':
        return Icons.grid_4x4_rounded;
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
        return Icons.sports_esports_rounded;
    }
  }

  bool get browserQr => const <String>{
        'xo',
        'checkers',
        'name_animal_object',
        'sheikh_beard',
        'dots_boxes',
      }.contains(game.id);

  void _open(BuildContext context) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'فتح غرفة ${game.name}',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(22),
          child: Ink(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(.11),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent.withOpacity(.18)),
                  ),
                  child: Icon(icon, color: accent, size: 26),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              game.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (browserQr)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withOpacity(.08),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.qr_code_2_rounded,
                                    size: 13,
                                    color: AppColors.secondary,
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'QR',
                                    style: TextStyle(
                                      color: AppColors.secondary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        game.status,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: <Widget>[
                          Icon(Icons.people_alt_rounded, color: accent, size: 15),
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
                          Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: accent.withOpacity(.72),
                            size: 15,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
