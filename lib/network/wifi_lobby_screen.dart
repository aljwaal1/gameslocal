import 'package:flutter/material.dart';

import '../design/app_theme.dart';

class WifiLobbyScreen extends StatefulWidget {
  const WifiLobbyScreen({super.key});

  @override
  State<WifiLobbyScreen> createState() => _WifiLobbyScreenState();
}

class _WifiLobbyScreenState extends State<WifiLobbyScreen> {
  bool hosting = true;
  String roomCode = 'LOCAL-1234';
  String status = 'جاهز لإنشاء غرفة على نفس شبكة الواي فاي أو الهوتسبوت';

  void createRoom() {
    setState(() {
      hosting = true;
      roomCode = 'LOCAL-${DateTime.now().second.toString().padLeft(2, '0')}${DateTime.now().minute.toString().padLeft(2, '0')}';
      status = 'تم إنشاء غرفة تجريبية. اجعل الجهازين على نفس Wi‑Fi أو Hotspot.';
    });
  }

  void joinRoom() {
    setState(() {
      hosting = false;
      status = 'وضع الانضمام مفعّل. في التحديث القادم سيتم البحث الفعلي عن المضيف.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اللعب عبر Wi‑Fi')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.wifi, color: AppColors.primary, size: 34),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text('غرفة محلية', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(status, style: const TextStyle(height: 1.5)),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          const Text('رمز الغرفة', style: TextStyle(color: AppColors.muted)),
                          const SizedBox(height: 6),
                          Text(roomCode, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: createRoom,
                            icon: const Icon(Icons.wifi_tethering),
                            label: const Text('إنشاء'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: joinRoom,
                            icon: const Icon(Icons.login),
                            label: const Text('انضمام'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  hosting
                      ? 'مفعّل الآن كواجهة وتجهيز. الخطوة القادمة: فتح Socket محلي وإرسال حركة اللعبة بين جهازين.'
                      : 'مفعّل الآن كواجهة انضمام. الخطوة القادمة: البحث عن غرفة داخل نفس الشبكة.',
                  style: const TextStyle(height: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
