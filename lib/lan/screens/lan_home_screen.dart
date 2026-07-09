import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio_feedback.dart';
import '../../design/app_theme.dart';
import '../engine/lan_engine.dart';
import '../models/lan_room.dart';

class LanHomeScreen extends StatefulWidget {
  const LanHomeScreen({super.key});

  @override
  State<LanHomeScreen> createState() => _LanHomeScreenState();
}

class _LanHomeScreenState extends State<LanHomeScreen> {
  final engine = LanEngine.instance;
  final nameController = TextEditingController(text: 'لاعب');
  final List<LanRoom> rooms = [];
  StreamSubscription<LanRoom>? roomSub;
  bool searching = false;
  bool hosting = false;
  LanRoom? hostedRoom;
  String selectedGame = 'xo';

  final games = const [
    ('xo', 'إكس أو'),
    ('domino', 'الدومينو'),
    ('checkers', 'الضامة'),
    ('cards', 'الشدة'),
    ('chess', 'الشطرنج'),
  ];

  @override
  void dispose() {
    roomSub?.cancel();
    nameController.dispose();
    super.dispose();
  }

  Future<void> startSearch() async {
    GameFeedback.tap();
    rooms.clear();
    setState(() => searching = true);
    roomSub ??= engine.discoveredRooms.listen((room) {
      final index = rooms.indexWhere((r) => r.code == room.code);
      setState(() {
        if (index >= 0) {
          rooms[index] = room;
        } else {
          rooms.add(room);
        }
      });
    });
    await engine.searchRooms();
  }

  Future<void> createRoom() async {
    GameFeedback.tap();
    final room = await engine.createRoom(gameId: selectedGame, hostName: nameController.text.trim().isEmpty ? 'لاعب' : nameController.text.trim());
    setState(() {
      hostedRoom = room;
      hosting = true;
    });
  }

  Future<void> joinRoom(LanRoom room) async {
    GameFeedback.tap();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم اختيار غرفة ${room.code}. ربط اللعب الفعلي سيكون في المرحلة التالية.')),
    );
  }

  Future<void> stopHost() async {
    GameFeedback.tap();
    await engine.stopAll();
    setState(() {
      hosting = false;
      hostedRoom = null;
      searching = false;
      rooms.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اللعب عبر الشبكة المحلية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('اسم اللاعب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.person), border: OutlineInputBorder(), hintText: 'اكتب اسمك'),
                  ),
                  const SizedBox(height: 12),
                  const Text('اختر اللعبة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedGame,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: [for (final game in games) DropdownMenuItem(value: game.$1, child: Text(game.$2))],
                    onChanged: hosting ? null : (value) => setState(() => selectedGame = value ?? 'xo'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (hosting && hostedRoom != null) _HostedRoomCard(room: hostedRoom!, onStop: stopHost) else FilledButton.icon(onPressed: createRoom, icon: const Icon(Icons.add_circle), label: const Text('إنشاء غرفة على نفس الشبكة')),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: startSearch, icon: const Icon(Icons.search), label: Text(searching ? 'إعادة البحث عن الغرف' : 'البحث عن الغرف')),
          const SizedBox(height: 14),
          const Text('الغرف الموجودة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          if (!searching)
            const _EmptyBox(text: 'اضغط البحث لعرض الغرف الموجودة على نفس الشبكة')
          else if (rooms.isEmpty)
            const _EmptyBox(text: 'لا توجد غرف حتى الآن')
          else
            for (final room in rooms) _RoomCard(room: room, onJoin: () => joinRoom(room)),
        ],
      ),
    );
  }
}

class _HostedRoomCard extends StatelessWidget {
  const _HostedRoomCard({required this.room, required this.onStop});
  final LanRoom room;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primary.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الغرفة جاهزة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text('كود الغرفة: ${room.code}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
            const SizedBox(height: 6),
            Text('اللعبة: ${room.gameId}'),
            Text('المنفذ: ${room.port}'),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: onStop, icon: const Icon(Icons.stop_circle), label: const Text('إيقاف الغرفة')),
          ],
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, required this.onJoin});
  final LanRoom room;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.wifi)),
        title: Text('${room.hostName} - ${room.gameId}'),
        subtitle: Text('كود: ${room.code} • لاعبين: ${room.players.length}'),
        trailing: FilledButton(onPressed: onJoin, child: const Text('دخول')),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
    );
  }
}
