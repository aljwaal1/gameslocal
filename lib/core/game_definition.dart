import 'package:flutter/widgets.dart';

import 'network/local_network_core.dart';

typedef GameScreenBuilder = Widget Function(
  BuildContext context,
  LocalNetworkCore? networkCore,
);

class GameCapabilities {
  const GameCapabilities({
    this.robot = false,
    this.sameDevice = false,
    this.lan = false,
    this.internet = false,
    this.browser = false,
  });

  final bool robot;
  final bool sameDevice;
  final bool lan;
  final bool internet;
  final bool browser;

  bool get hasNetworkMode => lan || internet;
  bool get hasOfflineMode => robot || sameDevice;
}

class GameInstructions {
  GameInstructions({
    required String objective,
    required String controls,
    this.keyRule = '',
  }) : objective = _requiredText(objective, 'objective'),
       controls = _requiredText(controls, 'controls');

  final String objective;
  final String controls;
  final String keyRule;

  static String _requiredText(String value, String field) {
    final cleaned = value.trim();
    if (cleaned.isEmpty)
      throw ArgumentError.value(value, field, 'must not be empty');
    return cleaned;
  }
}

class GameDefinition {
  GameDefinition({
    required this.id,
    required this.name,
    required this.playersText,
    required this.status,
    required this.builder,
    this.capabilities = const GameCapabilities(),
    GameInstructions? instructions,
  }) : instructions =
           instructions ??
           GameInstructions(
             objective: 'حقق هدف اللعبة قبل منافسك.',
             controls: 'اتبع الرسالة الظاهرة داخل اللعبة لتنفيذ دورك.',
           );

  final String id;
  final String name;
  final String playersText;
  final String status;
  final GameScreenBuilder builder;
  final GameCapabilities capabilities;
  final GameInstructions instructions;
}
