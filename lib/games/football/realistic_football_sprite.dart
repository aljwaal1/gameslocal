import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Visual poses backed by independent SVG image assets rather than Canvas body
/// primitives. Keeping the poses separate makes motion replacement reviewable.
enum FootballSpritePose {
  playerReady,
  playerRun,
  playerKick,
  keeperReady,
  keeperDive,
}

class RealisticFootballSprite extends StatefulWidget {
  const RealisticFootballSprite({
    super.key,
    required this.pose,
    required this.primary,
    required this.secondary,
    this.mirror = false,
  });

  final FootballSpritePose pose;
  final Color primary;
  final Color secondary;
  final bool mirror;

  @override
  State<RealisticFootballSprite> createState() =>
      _RealisticFootballSpriteState();
}

class _RealisticFootballSpriteState extends State<RealisticFootballSprite> {
  late Future<String> _svgFuture;

  @override
  void initState() {
    super.initState();
    _svgFuture = _loadSvg();
  }

  @override
  void didUpdateWidget(covariant RealisticFootballSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pose != widget.pose ||
        oldWidget.primary != widget.primary ||
        oldWidget.secondary != widget.secondary) {
      _svgFuture = _loadSvg();
    }
  }

  String get _assetPath {
    return switch (widget.pose) {
      FootballSpritePose.playerReady => 'assets/football/player_ready.svg',
      FootballSpritePose.playerRun => 'assets/football/player_run.svg',
      FootballSpritePose.playerKick => 'assets/football/player_kick.svg',
      FootballSpritePose.keeperReady => 'assets/football/keeper_ready.svg',
      FootballSpritePose.keeperDive => 'assets/football/keeper_dive.svg',
    };
  }

  String _rgbHex(Color color) {
    final argb = color.toARGB32();
    final rgb = argb & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Future<String> _loadSvg() async {
    final source = await rootBundle.loadString(_assetPath);
    return source
        .replaceAll('#D7263D', _rgbHex(widget.primary))
        .replaceAll('#F4F4F4', _rgbHex(widget.secondary));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _svgFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.expand();
        }

        return Transform.flip(
          flipX: widget.mirror,
          child: SvgPicture.string(
            snapshot.data!,
            fit: BoxFit.contain,
            alignment: Alignment.bottomCenter,
            excludeFromSemantics: true,
          ),
        );
      },
    );
  }
}
