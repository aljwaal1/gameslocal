import 'package:flutter/material.dart';

import '../core/app_settings.dart';
import '../design/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsController.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: AnimatedBuilder(
        animation: settings,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
            children: <Widget>[
              const _SettingsHero(),
              const SizedBox(height: 18),
              const _SectionTitle(
                title: 'طريقة اللعب',
                subtitle: 'اضبط مستوى الخصم الآلي للألعاب التي تدعم الروبوت.',
              ),
              const SizedBox(height: 9),
              _SettingsPanel(
                icon: Icons.smart_toy_rounded,
                title: 'مستوى الروبوت',
                subtitle: 'يطبّق هنا على الجميع، ويمكن تخصيصه قبل كل لعبة.',
                child: Padding(
                  padding: const EdgeInsets.only(top: 13),
                  child: SegmentedButton<BotDifficulty>(
                    showSelectedIcon: false,
                    segments: const <ButtonSegment<BotDifficulty>>[
                      ButtonSegment<BotDifficulty>(
                        value: BotDifficulty.easy,
                        label: Text('سهل'),
                        icon: Icon(Icons.sentiment_satisfied_alt_rounded),
                      ),
                      ButtonSegment<BotDifficulty>(
                        value: BotDifficulty.normal,
                        label: Text('متوسط'),
                        icon: Icon(Icons.smart_toy_rounded),
                      ),
                      ButtonSegment<BotDifficulty>(
                        value: BotDifficulty.hard,
                        label: Text('صعب'),
                        icon: Icon(Icons.psychology_alt_rounded),
                      ),
                    ],
                    selected: <BotDifficulty>{settings.botDifficulty},
                    onSelectionChanged: (value) =>
                        settings.setBotDifficultyForAll(value.first),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const _SectionTitle(
                title: 'الصوت والتفاعل',
                subtitle: 'تحكم بردود الفعل أثناء اللعب بدون تغيير قواعد الألعاب.',
              ),
              const SizedBox(height: 9),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.hairline),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x120F172A),
                      blurRadius: 16,
                      offset: Offset(0, 7),
                    ),
                  ],
                ),
                child: Column(
                  children: <Widget>[
                    _PremiumSwitchTile(
                      value: settings.soundEnabled,
                      icon: settings.soundEnabled
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      title: 'الأصوات',
                      subtitle: 'أصوات الحركة والفوز والتنبيهات داخل الألعاب.',
                      onChanged: settings.setSoundEnabled,
                    ),
                    const Divider(height: 1, indent: 68, endIndent: 14),
                    _PremiumSwitchTile(
                      value: settings.vibrationEnabled,
                      icon: Icons.vibration_rounded,
                      title: 'الاهتزاز',
                      subtitle: 'اهتزاز خفيف عند الأدوار والحركات المهمة.',
                      onChanged: settings.setVibrationEnabled,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const _SectionTitle(
                title: 'المظهر',
                subtitle: 'اختر لون الطاولة المشترك للألعاب التي تستخدمه.',
              ),
              const SizedBox(height: 9),
              _SettingsPanel(
                icon: Icons.palette_outlined,
                title: 'لون الطاولة',
                subtitle: 'اختيارك محفوظ تلقائيًا على هذا الجهاز.',
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _TableColorPicker(
                    selectedIndex: settings.tableColorIndex,
                    onSelected: settings.setTableColorIndex,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.verified_user_outlined,
                      color: AppColors.primary,
                      size: 21,
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'تُحفظ الإعدادات محليًا على الجهاز وتُطبّق من النظام المشترك على الألعاب التي تدعم كل خيار.',
                        style: TextStyle(
                          color: AppColors.inkSoft,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsHero extends StatelessWidget {
  const _SettingsHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: AppColors.heroGradient,
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
      child: const Row(
        children: <Widget>[
          _HeroIcon(),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'اضبط تجربتك',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'إعدادات موحدة وبسيطة لجميع جلسات GamesLocal.',
                  style: TextStyle(
                    color: Color(0xFFE9F6F4),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
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

class _HeroIcon extends StatelessWidget {
  const _HeroIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0x20FFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x38FFFFFF)),
      ),
      child: const Icon(Icons.tune_rounded, color: Colors.white, size: 29),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.hairline),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0x120F766E),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary, size: 23),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }
}

class _PremiumSwitchTile extends StatelessWidget {
  const _PremiumSwitchTile({
    required this.value,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  final bool value;
  final IconData icon;
  final String title;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
      secondary: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: value
              ? const Color(0x140F766E)
              : const Color(0x100F172A),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          color: value ? AppColors.primary : AppColors.muted,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.ink,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
    );
  }
}

class _TableColorPicker extends StatelessWidget {
  const _TableColorPicker({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const colors = <Color>[
    AppColors.primaryDark,
    Color(0xFF6B4F2A),
    Color(0xFF1E3A8A),
    Color(0xFF111827),
  ];

  static const labels = <String>['أخضر', 'خشبي', 'أزرق', 'داكن'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List<Widget>.generate(colors.length, (index) {
        final selected = selectedIndex == index;
        return Semantics(
          button: true,
          selected: selected,
          label: 'لون الطاولة ${labels[index]}',
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 68,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: selected
                    ? colors[index].withOpacity(.10)
                    : AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? colors[index] : AppColors.hairline,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: colors[index],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x260F172A),
                          blurRadius: 7,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 19)
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[index],
                    style: TextStyle(
                      color: selected ? colors[index] : AppColors.inkSoft,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
