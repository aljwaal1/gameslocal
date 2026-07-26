import 'package:flutter/material.dart';

enum FootballSpritePose {
  playerReady,
  playerRun,
  playerKick,
  keeperReady,
  keeperDive,
}

/// A full-bleed photographic action frame.
///
/// These images are real CC0/public-domain football photographs stored locally
/// in the APK. The soft edge and colour treatment let consecutive photographs
/// read as a single broadcast-style sequence instead of rectangular stickers.
class RealisticFootballSprite extends StatelessWidget {
  const RealisticFootballSprite({
    super.key,
    required this.pose,
    required this.primary,
    required this.secondary,
    this.mirror = false,
    this.alignment = Alignment.center,
  });

  final FootballSpritePose pose;
  final Color primary;
  final Color secondary;
  final bool mirror;
  final Alignment alignment;

  String get _assetPath {
    return switch (pose) {
      FootballSpritePose.playerReady =>
        'assets/football/photo/player_ready.png',
      FootballSpritePose.playerRun => 'assets/football/photo/player_run.jpg',
      FootballSpritePose.playerKick => 'assets/football/photo/player_kick.jpg',
      FootballSpritePose.keeperReady =>
        'assets/football/photo/keeper_ready.jpg',
      FootballSpritePose.keeperDive =>
        'assets/football/photo/keeper_dive.jpg',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Transform.flip(
      flipX: mirror,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) {
          return const RadialGradient(
            center: Alignment(0, -0.05),
            radius: 1.08,
            colors: <Color>[
              Colors.white,
              Colors.white,
              Color(0xE8FFFFFF),
              Colors.transparent,
            ],
            stops: <double>[0.0, 0.62, 0.84, 1.0],
          ).createShader(bounds);
        },
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(
            Color.lerp(primary, secondary, 0.35)!.withOpacity(0.12),
            BlendMode.softLight,
          ),
          child: Image.asset(
            _assetPath,
            fit: BoxFit.cover,
            alignment: alignment,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) {
              return const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0xFF162B3A),
                      Color(0xFF07131F),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
