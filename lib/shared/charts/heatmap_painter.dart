import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The colour of one heatmap cell: [base] when empty, [peak] at the busiest
/// cell, a straight lerp between.
Color heatmapColor(Color base, Color peak, int minutes, int maxMinutes) {
  if (maxMinutes <= 0 || minutes <= 0) return base;
  return Color.lerp(base, peak, minutes / maxMinutes)!;
}

/// A 7×24 grid of rounded cells, Monday (or the first weekday) on top, hours
/// across. Callers build the matrix with `buildHeatmap`.
class HeatmapPainter extends CustomPainter {
  HeatmapPainter({
    required this.matrix,
    required this.base,
    required this.peak,
    this.gap = 2,
  }) : assert(
         matrix.length == 7 && matrix.every((row) => row.length == 24),
         'The heatmap matrix must be 7 rows of 24 hours',
       );

  final List<List<int>> matrix;
  final Color base;
  final Color peak;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final maxMinutes = matrix.fold(
      0,
      (max, row) => math.max(max, row.fold(0, math.max)),
    );
    final cellWidth = (size.width - gap * 23) / 24;
    final cellHeight = (size.height - gap * 6) / 7;
    final paint = Paint()..style = PaintingStyle.fill;
    for (var row = 0; row < 7; row++) {
      for (var col = 0; col < 24; col++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              col * (cellWidth + gap),
              row * (cellHeight + gap),
              cellWidth,
              cellHeight,
            ),
            const Radius.circular(2),
          ),
          paint..color = heatmapColor(base, peak, matrix[row][col], maxMinutes),
        );
      }
    }
  }

  bool _matrixEqual(List<List<int>> a, List<List<int>> b) {
    for (var row = 0; row < 7; row++) {
      for (var col = 0; col < 24; col++) {
        if (a[row][col] != b[row][col]) return false;
      }
    }
    return true;
  }

  @override
  bool shouldRepaint(covariant HeatmapPainter oldDelegate) =>
      !_matrixEqual(oldDelegate.matrix, matrix) ||
      oldDelegate.base != base ||
      oldDelegate.peak != peak ||
      oldDelegate.gap != gap;
}
