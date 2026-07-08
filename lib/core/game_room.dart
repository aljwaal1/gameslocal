import 'package:flutter/material.dart';

import 'game_definition.dart';

class GameRoomScreen extends StatefulWidget {
  const GameRoomScreen({super.key, required this.game});

  final GameDefinition game;

  @override
  State<GameRoomScreen> createState() => _GameRoomScreenState();
}

class _GameRoomScreenState extends State<GameRoomScreen> {
  bool isHost = true;
  int players = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('غرفة ${widget.game.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.game.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('عدد اللاعبين: ${widget.game.playersText}'),
                  const SizedBox(height: 16),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('إنشاء غرفة'), icon: Icon(Icons.wifi_tethering)),
                      ButtonSegment(value: false, label: Text('انضمام'), icon: Icon(Icons.login)),
                    ],
                    selected: {isHost},
                    onSelectionChanged: (value) => setState(() => isHost = value.first),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isHost
                        ? 'في النسخة القادمة سيتم تشغيل Host على الشبكة المحلية أو Hotspot.'
                        : 'في النسخة القادمة سيتم البحث عن غرفة داخل نفس الشبكة.',
                    style: const TextStyle(height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('اللاعبون', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const ListTile(leading: Icon(Icons.person), title: Text('اللاعب 1'), subtitle: Text('جاهز')),
                  const ListTile(leading: Icon(Icons.person_outline), title: Text('اللاعب 2'), subtitle: Text('محلي للتجربة')),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('ابدأ اللعب'),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: widget.game.builder));
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _ConnectionPlanCard(),
        ],
      ),
    );
  }
}

class _ConnectionPlanCard extends StatelessWidget {
  const _ConnectionPlanCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'خطة الاتصال: أولًا Wi-Fi/Hotspot لأنه أثبت من البلوتوث. بعد نجاح الغرف والحركات نضيف Bluetooth كطبقة ثانية بدون تغيير الألعاب.',
          style: TextStyle(height: 1.5),
        ),
      ),
    );
  }
}
