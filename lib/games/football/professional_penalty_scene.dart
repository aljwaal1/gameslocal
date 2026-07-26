import 'package:flutter/material.dart';

import 'penalty_shootout_game.dart' show FootballTeam;
import 'realistic_penalty_scene.dart';

/// Compatibility entry point used by the penalty game.
///
/// The previous implementation painted the player and goalkeeper directly on
/// a Canvas. The new implementation delegates to image-based SVG sprites with
/// separate animation poses while preserving the public scene contract.
class ProfessionalPenaltyScene extends StatelessWidget {
  const ProfessionalPenaltyScene({
    super.key,
    required this.shotProgress,
    required this.ambientProgress,
    required this.shootingTeam,
    required this.targetX,
    required this.targetY,
    required this.keeperX,
    required this.keeperY,
    required this.shotPower,
    required this.goal,
    required this.enabled,
    required this.onShoot,
  });

  final double shotProgress;
  final double ambientProgress;
  final FootballTeam shootingTeam;
  final double targetX;
  final double targetY;
  final double keeperX;
  final double keeperY;
  final double shotPower;
  final bool goal;
  final bool enabled;
  final void Function(double x, double y) onShoot;

  @override
  Widget build(BuildContext context) {
    return RealisticPenaltyScene(
      shotProgress: shotProgress,
      ambientProgress: ambientProgress,
      shootingTeam: shootingTeam,
      targetX: targetX,
      targetY: targetY,
      keeperX: keeperX,
      keeperY: keeperY,
      shotPower: shotPower,
      goal: goal,
      enabled: enabled,
      onShoot: onShoot,
    );
  }
}
