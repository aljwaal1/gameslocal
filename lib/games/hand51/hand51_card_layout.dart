import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The single source of truth for both the painted hand and its hit regions.
/// Coordinates are logical pixels inside the horizontally scrollable content.
class Hand51CardLayout {
  const Hand51CardLayout({
    required this.cardCount,
    required this.viewportWidth,
    this.textScale = 1,
  }) : assert(cardCount >= 0);

  final int cardCount;
  final double viewportWidth;
  final double textScale;

  double get scale => textScale.isFinite ? math.max(1, textScale) : 1;
  double get cardWidth => 76 * scale;
  double get cardHeight => 112 * scale;
  double get height => cardHeight + 18;
  double get minimumHeader => 32 * scale;
  double get _viewport =>
      viewportWidth.isFinite ? math.max(0, viewportWidth) : 0;

  double get step => cardCount <= 1
      ? cardWidth
      : ((_viewport - cardWidth) / (cardCount - 1))
          .clamp(minimumHeader, cardWidth)
          .toDouble();
  double get _handWidth =>
      cardCount == 0 ? 0 : cardWidth + step * (cardCount - 1);
  double get contentWidth => math.max(_viewport, _handWidth);
  double get _leading => (contentWidth - _handWidth) / 2;

  double leftFor(int index) => _leading + step * index;

  // Flat indices keep every crowded corner completely legible and touchable.
  double angleFor(int index) => 0;

  Rect rectFor(int index, {bool selected = false}) => Rect.fromLTWH(
        leftFor(index),
        height - cardHeight - (selected ? 10 : 0),
        cardWidth,
        cardHeight,
      );

  int? indexAtPoint(Offset point,
      {double scrollOffset = 0, Set<int> selectedIndices = const <int>{}}) {
    final contentPoint = point + Offset(scrollOffset, 0);
    // Stack paints later cards last; their actual rectangles take precedence.
    for (var i = cardCount - 1; i >= 0; i--) {
      if (rectFor(i, selected: selectedIndices.contains(i))
          .contains(contentPoint)) return i;
    }
    return null;
  }

  int? indexAt(double x, {double scrollOffset = 0}) {
    final contentX = x + scrollOffset - _leading;
    if (cardCount == 0 ||
        !contentX.isFinite ||
        contentX < 0 ||
        contentX >= _handWidth) {
      return null;
    }
    return (contentX / step).floor().clamp(0, cardCount - 1);
  }
}

/// A real scroll viewport; overlap and selection always use [Hand51CardLayout].
class Hand51HandView extends StatelessWidget {
  const Hand51HandView({
    super.key,
    required this.cardCount,
    required this.cardBuilder,
    required this.onSelected,
    this.selectedIndices = const <int>{},
    this.controller,
  });

  final int cardCount;
  final Widget Function(BuildContext context, int index) cardBuilder;
  final ValueChanged<int> onSelected;
  final Set<int> selectedIndices;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final layout = Hand51CardLayout(
          cardCount: cardCount,
          viewportWidth: constraints.maxWidth,
          textScale: MediaQuery.textScalerOf(context).scale(1),
        );
        return SizedBox(
          key: const ValueKey('hand51-viewport'),
          height: layout.height,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SingleChildScrollView(
              controller: controller,
              scrollDirection: Axis.horizontal,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  final index = layout.indexAtPoint(details.localPosition,
                      selectedIndices: selectedIndices);
                  if (index != null) onSelected(index);
                },
                child: SizedBox(
                  width: layout.contentWidth,
                  height: layout.height,
                  child: Stack(
                    children: [
                      for (var i = 0; i < cardCount; i++)
                        Positioned.fromRect(
                          rect: layout.rectFor(i,
                              selected: selectedIndices.contains(i)),
                          child: IgnorePointer(
                            child: Semantics(
                              selected: selectedIndices.contains(i),
                              child: cardBuilder(context, i),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      });
}
