import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'battle_arena_screen.dart';

class BattleModeScreen extends StatefulWidget {
  const BattleModeScreen({super.key});

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
    ('برق', Icons.bolt, 'سريع'),
    ('صخر', Icons.shield, 'دفاعي'),
    ('لهب', Icons.local_fire_department, 'قوي'),
    ('موج', Icons.water_drop, 'متوازن'),
  ];

  String get selectedCharacterName => characters[character].$1;
  String get selectedCharacterStyle => characters[character].$3;

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
          ),
        ),
      ),
    );
  }

  void _startQuickMatch() {
    setState(() {
      character = _random.nextInt(characters.length);
      botLevel = ['سهل', 'متوسط', 'صعب'][_random.nextInt(3)];
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
            const Text('اختر الشخصية ومستوى الروبوت، أو ابدأ مباراة سريعة مباشرة.'),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _startQuickMatch,
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
            const _SupportedModeCard(),
            const SizedBox(height: 10),
            _OptionCard(
              title: 'مستوى الروبوت',
              child: DropdownButtonFormField<String>(
                value: botLevel,
                items: const [
                  DropdownMenuItem(value: 'سهل', child: Text('سهل')),
                  DropdownMenuItem(value: 'متوسط', child: Text('متوسط')),
                  DropdownMenuItem(value: 'صعب', child: Text('صعب')),
                ],
                onChanged: (value) => setState(() => botLevel = value ?? botLevel),
              ),
            ),
            const SizedBox(height: 12),
            _MatchPreviewCard(
              characterName: selectedCharacterName,
              characterStyle: selectedCharacterStyle,
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
  const _SupportedModeCard();

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
                    'النمط المتاح حاليًا: 1 ضد 1',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'لاعب واحد ضد روبوت. اللعب الجماعي ونمط الفرق سيظهران بعد اكتمال دعمهما داخل الساحة.',
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
    required this.botLevel,
  });

  final String characterName;
  final String characterStyle;
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
