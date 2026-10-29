import 'package:flutter/material.dart';

import 'game_definition.dart';

Future<void> showGameHelp(BuildContext context, GameDefinition game) {
  final instructions = game.instructions;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'كيف تلعب ${game.name}؟',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            _HelpStep(
              icon: Icons.flag_rounded,
              title: 'الهدف',
              body: instructions.objective,
            ),
            const SizedBox(height: 10),
            _HelpStep(
              icon: Icons.touch_app_rounded,
              title: 'التحكم',
              body: instructions.controls,
            ),
            if (instructions.keyRule.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              _HelpStep(
                icon: Icons.rule_rounded,
                title: 'قاعدة مهمة',
                body: instructions.keyRule,
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('فهمت، ابدأ اللعب'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HelpStep extends StatelessWidget {
  const _HelpStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(.48),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(body, style: const TextStyle(fontSize: 13, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
