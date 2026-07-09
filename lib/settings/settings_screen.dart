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
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('مستوى الروبوت', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      SegmentedButton<BotDifficulty>(
                        segments: const [
                          ButtonSegment(value: BotDifficulty.easy, label: Text('سهل'), icon: Icon(Icons.sentiment_satisfied)),
                          ButtonSegment(value: BotDifficulty.normal, label: Text('متوسط'), icon: Icon(Icons.smart_toy)),
                          ButtonSegment(value: BotDifficulty.hard, label: Text('صعب'), icon: Icon(Icons.psychology)),
                        ],
                        selected: {settings.botDifficulty},
                        onSelectionChanged: (value) => settings.setBotDifficulty(value.first),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      value: settings.soundEnabled,
                      title: const Text('الأصوات'),
                      subtitle: const Text('تشغيل أو إيقاف أصوات اللعب'),
                      secondary: const Icon(Icons.volume_up, color: AppColors.primary),
                      onChanged: settings.setSoundEnabled,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      value: settings.vibrationEnabled,
                      title: const Text('الاهتزاز'),
                      subtitle: const Text('اهتزاز خفيف عند الدور والحركات المهمة'),
                      secondary: const Icon(Icons.vibration, color: AppColors.primary),
                      onChanged: settings.setVibrationEnabled,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('لون الطاولة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        children: List.generate(4, (index) {
                          final colors = [AppColors.primaryDark, const Color(0xFF6B4F2A), const Color(0xFF1E3A8A), const Color(0xFF111827)];
                          return InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () => settings.setTableColorIndex(index),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: colors[index],
                              child: settings.tableColorIndex == index ? const Icon(Icons.check, color: Colors.white) : null,
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'هذه الإعدادات موحدة، وسيتم ربطها تدريجيًا بكل الألعاب حسب الخطة المتفق عليها.',
                    style: TextStyle(height: 1.5),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
