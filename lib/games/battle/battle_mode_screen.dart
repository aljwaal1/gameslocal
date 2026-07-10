import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Battle Mode')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'إعداد مباراة تجريبية',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text('اختر الشخصية وعدد اللاعبين قبل دخول الساحة الأولى.'),
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
                onSelectionChanged: (value) => setState(() => players = value.first),
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
                onSelectionChanged: (value) => setState(() => mode = value.first),
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
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تم تجهيز: ${characters[character].$1} • $players لاعبين • $mode • روبوت $botLevel',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('تجهيز المباراة'),
              ),
            ),
          ],
        ),
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
