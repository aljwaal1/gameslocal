import 'package:flutter/widgets.dart';

import 'network/local_network_core.dart';

typedef GameScreenBuilder = Widget Function(BuildContext context, LocalNetworkCore? networkCore);

class GameDefinition {
  const GameDefinition({
    required this.id,
    required this.name,
    required this.playersText,
    required this.status,
    required this.builder,
  });

  final String id;
  final String name;
  final String playersText;
  final String status;
  final GameScreenBuilder builder;
}
