import 'package:flutter/material.dart';

import 'battle_arena_screen.dart';

class BattleModeScreen extends StatefulWidget {
  const BattleModeScreen({super.key});

  @override
  State<BattleModeScreen> createState() => _BattleModeScreenState();
}

class _BattleModeScreenState extends State<BattleModeScreen> {
  int players = 2;
  String mode = 'فردي';
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

  void _setPlayers(int value) {
    setState(() {
      players = value;
      if (mode == 'فرق' && players != 4) mode = 'فردي';
    });
  }

  void _setMode(String value) {
    setState(() {
      mode = value;
      if (mode == 'فرق') players = 4;
    });
  }

  void _startMatch() {
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
            const Text('اختر الشخصية وعدد اللاعبين ثم ادخل الساحة الأولى القابلة للعب.'),
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
                              Text(item.$1, style: const TextStyle(fontWeight: FontWeight.bold)),
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
            _OptionCard(
              title: 'عدد اللاعبين',
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 2, label: Text('2')),
                  ButtonSegment(value: 3, label: Text('3')),
                  ButtonSegment(value: 4, label: Text('4')),
                ],
                selected: {players},
                onSelectionChanged: (value) => _setPlayers(value.first),
              ),
            ),
            const SizedBox(height: 10),
            _OptionCard(
              title: 'نمط اللعب',
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'فردي', label: Text('فردي')),
                  ButtonSegment(value: 'فرق', label: Text('فرق 2 ضد 2')),
                ],
                selected: {mode},
                onSelectionChanged: (value) => _setMode(value.first),
              ),
            ),
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
              players: players,
              mode: mode,
              botLevel: botLevel,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _startMatch,
              icon: const Icon(Icons.play_arrow),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('ابدأ المباراة'),
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
    required this.players,
    required this.mode,
    required this.botLevel,
  });

  final String characterName;
  final String characterStyle;
  final int players;
  final String mode;
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
              const Text('ملخص المباراة', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Text('الشخصية: $characterName • الأسلوب: $characterStyle'),
          const SizedBox(height: 4),
          Text('النمط: $mode • اللاعبون: $players • الروبوت: $botLevel'),
          if (players > 2) ...[
            const SizedBox(height: 8),
            const Text(
              'تنبيه: الساحة الحالية تجريبية وتبدأ بمواجهة مباشرة مع روبوت واحد، وسيُضاف باقي اللاعبين لاحقًا.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
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
