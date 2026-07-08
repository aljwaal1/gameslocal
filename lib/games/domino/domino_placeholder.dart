import 'package:flutter/material.dart';

class DominoPlaceholderScreen extends StatelessWidget {
  const DominoPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الدومينو')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'هذا مجلد مستقل للدومينو. عند تطوير الدومينو لن نلمس الضامة أو الشطرنج.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, height: 1.6),
          ),
        ),
      ),
    );
  }
}
