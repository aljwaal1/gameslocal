import 'package:flutter/material.dart';

class RetroPixels {
  static void draw(
    Canvas canvas,
    Offset center,
    double pixel,
    List<String> rows,
    Map<String, Color> palette, {
    double shadow = 0,
  }) {
    if (rows.isEmpty) return;
    final rowCount = rows.length;
    final colCount = rows.map((r) => r.length).fold<int>(0, (a, b) => a > b ? a : b);
    final origin = Offset(center.dx - colCount * pixel / 2, center.dy - rowCount * pixel / 2);

    if (shadow > 0) {
      final p = Paint()..color = Colors.black.withOpacity(0.42);
      canvas.drawRect(
        Rect.fromLTWH(origin.dx + shadow, origin.dy + shadow, colCount * pixel, rowCount * pixel),
        p,
      );
    }

    for (var y = 0; y < rows.length; y++) {
      final row = rows[y];
      for (var x = 0; x < row.length; x++) {
        final key = row[x];
        final color = palette[key.toString()];
        if (color == null) continue;
        canvas.drawRect(
          Rect.fromLTWH(origin.dx + x * pixel, origin.dy + y * pixel, pixel + 0.15, pixel + 0.15),
          Paint()..color = color,
        );
      }
    }
  }
}
