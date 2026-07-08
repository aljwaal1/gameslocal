import 'package:flutter/material.dart';

class CardsPlaceholderScreen extends StatelessWidget {
  const CardsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الشدة / السراقة')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'هذا مجلد مستقل للشدة والسراقة. سنحدد القواعد ثم نطور اللعبة هنا فقط.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, height: 1.6),
          ),
        ),
      ),
    );
  }
}
