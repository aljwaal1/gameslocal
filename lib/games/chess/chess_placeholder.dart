import 'package:flutter/material.dart';

class ChessPlaceholderScreen extends StatelessWidget {
  const ChessPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderGameScreen(
      title: 'الشطرنج',
      description: 'هذا مجلد مستقل للشطرنج. عندما نبدأ الشطرنج سنعدل ملفات chess فقط.',
    );
  }
}

class _PlaceholderGameScreen extends StatelessWidget {
  const _PlaceholderGameScreen({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(description, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, height: 1.6)),
        ),
      ),
    );
  }
}
