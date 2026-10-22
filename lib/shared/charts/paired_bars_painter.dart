import 'dart:math' as math;

import 'package:energy_clock/core/tone.dart';
import 'package:flutter/material.dart';

/// Planned against completed minutes for one tone.
typedef PlannedActualRow = ({Tone tone, int planned, int completed});

/// Each bar's share of the shared maximum. Zero when the maximum is 0.
({double planned, double completed}) pairedFractions(
  PlannedActualRow row,
  int maxValue,
) {
  if (maxValue <= 0) return (planned: 0, completed: 0);
  return (planned: row.planned / maxValue, completed: row.completed / maxValue);
}

/// Two bars per tone — planned in [plannedColor], completed in the tone
/// colour — heights relative to the largest value anywhere.
class PairedBarsPainter extends CustomPainter {
  PairedBarsPainter({
    required this.rows,
    required this.colors,
    required this.plannedColor,
    this.barRadius = 3,
  });

  final List<PlannedActualRow> rows;
  final Map<Tone, Color> colors;
  final Color plannedColor;
  final double barRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (rows.isEmpty) return;
    final maxValue = math.max(
      1,
      rows.fold(
        0,
        (max, row) => math.max(max, math.max(row.planned, row.completed)),
      ),
    );
    final slot = size.width / rows.length;
    final barWidth = math.min((slot - 12) / 2, 22).toDouble();
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < rows.length; i++) {
      final fractions = pairedFractions(rows[i], maxValue);
      final groupX = slot * i + (slot - barWidth * 2 - 4) / 2;
      _bar(
        canvas,
        paint,
        Rect.fromLTWH(
          groupX,
          size.height * (1 - fractions.planned),
          barWidth,
          size.height * fractions.planned,
        ),
        plannedColor,
      );
      _bar(
        canvas,
        paint,
        Rect.fromLTWH(
          groupX + barWidth + 4,
          size.height * (1 - fractions.completed),
          barWidth,
          size.height * fractions.completed,
        ),
        colors[rows[i].tone] ?? plannedColor,
      );
    }
  }

  void _bar(Canvas canvas, Paint paint, Rect rect, Color color) {
    if (rect.height <= 0) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(barRadius)),
      paint..color = color,
    );
  }

  bool _rowsEqual(List<PlannedActualRow> a, List<PlannedActualRow> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].tone != b[i].tone ||
          a[i].planned != b[i].planned ||
          a[i].completed != b[i].completed) {
        return false;
      }
    }
    return true;
  }

  @override
  bool shouldRepaint(covariant PairedBarsPainter oldDelegate) =>
      !_rowsEqual(oldDelegate.rows, rows) ||
      oldDelegate.colors != colors ||
      oldDelegate.plannedColor != plannedColor ||
      oldDelegate.barRadius != barRadius;
}
