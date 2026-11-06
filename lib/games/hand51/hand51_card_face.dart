import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Readable indices on both exposed corners, including a distinct joker.
class Hand51CardFace extends StatelessWidget {
  const Hand51CardFace({
    super.key,
    required this.rank,
    required this.suit,
    this.joker = false,
    this.compact = false,
    this.picked = false,
  });

  final String rank;
  final String suit;
  final bool joker;
  final bool compact;
  final bool picked;

  @override
  Widget build(BuildContext context) {
    final scale = math.max(1.0, MediaQuery.textScalerOf(context).scale(1));
    final ink = joker
        ? const Color(0xFF68157D)
        : suit == '♥' || suit == '♦'
            ? const Color(0xFFB01025)
            : const Color(0xFF111827);
    final rankText = joker ? 'J★' : rank;
    Widget corner() => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(rankText,
                maxLines: 1,
                style: TextStyle(
                  color: ink,
                  fontSize: compact ? 14 : 19,
                  fontWeight: FontWeight.w900,
                  height: 1,
                )),
            Text(joker ? '★' : suit,
                style: TextStyle(
                  color: ink,
                  fontSize: compact ? 14 : 19,
                  fontWeight: FontWeight.w900,
                  height: 1,
                )),
          ],
        );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: (compact ? 50 : 76) * scale,
      height: (compact ? 76 : 112) * scale,
      decoration: BoxDecoration(
        color: joker ? const Color(0xFFFFF0C2) : const Color(0xFFFFFEFA),
        borderRadius: BorderRadius.circular(compact ? 7 : 10),
        border: Border.all(
            color: picked ? const Color(0xFFFFD166) : const Color(0xFFCCC5B8),
            width: picked ? 2.4 : 1),
        boxShadow: [
          BoxShadow(
              color: picked ? const Color(0x66FFD166) : Colors.black26,
              blurRadius: picked ? 10 : 5,
              offset: const Offset(0, 3))
        ],
      ),
      child: Stack(children: [
        Positioned(top: 5, left: 5, child: corner()),
        Center(
            child: joker
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.auto_awesome,
                        color: ink, size: (compact ? 21 : 31) * scale),
                    Text('JOKER',
                        style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w900,
                            fontSize: compact ? 8 : 10)),
                  ])
                : Text(suit,
                    style: TextStyle(
                        color: ink,
                        fontSize: compact ? 26 : 38,
                        fontWeight: FontWeight.w800))),
        Positioned(
            bottom: 5,
            right: 5,
            child: Transform.rotate(angle: math.pi, child: corner())),
      ]),
    );
  }
}
