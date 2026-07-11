import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/network/local_network_core.dart';

import 'battle_arena_screen.dart';
import 'battle_quick_match.dart';

class BattleModeScreen extends StatefulWidget {
  const BattleModeScreen({super.key, this.networkCore});

  final LocalNetworkCore? networkCore;

  @override
  State<BattleModeScreen> createState() => _BattleModeScreenState();
}

class _BattleModeScreenState extends State<BattleModeScreen> {
  final math.Random _random = math.Random();

  static const int players = 2;
  static const String mode = 'فردي';
  String botLevel = 'متوسط';
  int character = 0;

  static const characters = [
    ('برق', Icons.bolt, 'سريع', 'حركة أسرع داخل الساحة', 'اندفاع سريع نحو الروبوت مع ضربة عند الاقتراب'),
    ('صخر', Icons.shield, 'دفاعي', 'صحة أعلى وضرر أقل من الروبوت', 'استعادة 20 نقطة صحة عند الحاجة'),
    ('لهب', Icons.local_fire_department, 'قوي', 'ضرر أكبر في كل ضربة', 'ضربة لهب قوية عند الاقتراب'),
    ('موج', Icons.water_drop, 'متوازن', 'مدى هجوم أبعد', 'موجة بعيدة تدفع الروبوت للخلف'),
  ];

  String get selectedCharacterName => characters[character].$1;
  String get selectedCharacterStyle => characters[character].$3;
  String get selectedCharacterAbility => characters[character].$4;
  String get selectedCharacterSkill => characters[character].$5;

  String get botLevelDescription => switch (botLevel) {
        'سهل' => 'الروبوت أبطأ وأقل اندفاعًا نحو اللاعب.',
        'صعب' => 'الروبوت أسرع وأكثر مطاردة للاعب.',
        _ => 'سرعة ومطاردة متوازنتان للتدريب.',
      };

  void _openArena() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: BattleArenaScreen(
            characterName: selectedCharacterName,
            players: players,
            mode: mode,
            botLevel: botLevel,
            networkCore: widget.networkCore,
          ),
        ),
      ),
    );
  }

  void _startQuickMatch() {
    final choice = buildBattleQuickMatchChoice(
      currentCharacter: character,
      currentBotLevel: botLevel,
      characterRoll: _random.nextInt(characters.length),
      levelRoll: _random.nextInt(battleBotLevels.length),
      characterCount: characters.length,
    );

    setState(() {
      character = choice.characterIndex;
      botLevel = choice.botLevel;
    });
    _openArena();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Battle Mode')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'إعداد المباراة',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(widget.networkCore == null ? 'اختر الشخصية ومستوى الروبوت، أو ابدأ مباراة سريعة مباشرة.' : 'اختر شخصيتك ثم ابدأ مواجهة اللاعب الآخر عبر الشبكة المحلية.'),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: widget.networkCore == null ? _startQuickMatch : null,
              icon: const Icon(Icons.casino_outlined),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('مباراة سريعة عشوائية'),
              ),
            ),
            const SizedBox(height: 18),
            const Text('الشخصية', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.7,
              ),
              itemCount: characters.length,
              itemBuilder: (context, index) {
                final item = characters[index];
                final selected = character == index;
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => setState(() => character = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: selected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Colors.white,
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.black12,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(item.$2, size: 30),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.$1,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(item.$3, style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            _SupportedModeCard(networkGame: widget.networkCore != null),
            const SizedBox(height: 10),
            _OptionCard(
              title: widget.networkCore == null ? 'مستوى الروبوت' : 'نوع المباراة',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.networkCore == null) DropdownButtonFormField<String>(
                    value: botLevel,
                    items: const [
                      DropdownMenuItem(value: 'سهل', child: Text('سهل')),
                      DropdownMenuItem(value: 'متوسط', child: Text('متوسط')),
                      DropdownMenuItem(value: 'صعب', child: Text('صعب')),
                    ],
                    onChanged: (value) => setState(() => botLevel = value ?? botLevel),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.networkCore == null ? botLevelDescription : 'اتصال محلي مباشر بين لاعبين؛ المضيف هو اللاعب الأول.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _MatchPreviewCard(
              characterName: selectedCharacterName,
              characterStyle: selectedCharacterStyle,
              characterAbility: selectedCharacterAbility,
              characterSkill: selectedCharacterSkill,
              botLevel: botLevel,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _openArena,
              icon: const Icon(Icons.play_arrow),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('ابدأ مباراة 1 ضد 1'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportedModeCard extends StatelessWidget {
  const _SupportedModeCard({required this.networkGame});

  final bool networkGame;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(Icons.sports_martial_arts, color: colorScheme.primary),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    networkGame ? 'النمط: لاعب ضد لاعب عبر LAN' : 'النمط المتاح حاليًا: 1 ضد 1',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    networkGame ? 'تتم مزامنة الحركة والهجوم والصحة بين الجهازين.' : 'لاعب واحد ضد روبوت. اللعب الجماعي ونمط الفرق سيظهران بعد اكتمال دعمهما داخل الساحة.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchPreviewCard extends StatelessWidget {
  const _MatchPreviewCard({
    required this.characterName,
    required this.characterStyle,
    required this.characterAbility,
    required this.characterSkill,
    required this.botLevel,
  });

  final String characterName;
  final String characterStyle;
  final String characterAbility;
  final String characterSkill;
  final String botLevel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withOpacity(0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.secondary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check, color: colorScheme.secondary),
              const SizedBox(width: 8),
              const Text(
                'ملخص المباراة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('الشخصية: $characterName • الأسلوب: $characterStyle'),
          const SizedBox(height: 4),
          Text('الميزة الدائمة: $characterAbility'),
          const SizedBox(height: 4),
          Text('المهارة النشطة: $characterSkill'),
          const SizedBox(height: 4),
          const Text('فترة انتظار المهارة: 8 ثوانٍ بعد الاستخدام'),
          const SizedBox(height: 4),
          Text('النمط: فردي 1 ضد 1 • الروبوت: $botLevel'),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
