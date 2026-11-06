import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Keeps the table bounded on phones and allows the complete table to be
/// reached in landscape, rather than squeezing cards or clipping controls.
class CardTableViewport extends StatelessWidget {
  const CardTableViewport({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxHeight >= 450) return child;
        final scale = math.max(1.0, MediaQuery.textScalerOf(context).scale(1));
        return SingleChildScrollView(
            child: SizedBox(
          width: constraints.maxWidth,
          height: math.max(constraints.maxHeight, 620 * scale),
          child: child,
        ));
      });
}
