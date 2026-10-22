import 'dart:math' as math;

import 'package:altidial/shared/layout/content_width.dart';
import 'package:flutter/painting.dart';

/// How big the month grid is, from the room the window gives it.
///
/// Seven cells fill the card's width; the cells are at most [maxCell] pt and
/// the card at most [ContentWidths.calendar] wide. A short window makes the
/// cells smaller (down to [minCell]), after which the page scrolls. On the
/// narrowest windows the card's padding shrinks too, so the cells stay near
/// 40 pt.
class CalendarLayout {
  const CalendarLayout({required this.cellSize, required this.cardPadding});

  final double cellSize;
  final double cardPadding;

  /// The width of the card holding the grid.
  double get cardWidth => 7 * cellSize + 2 * cardPadding;

  static const double minCell = 36;
  static const double maxCell = 76;

  /// The space either side of the card.
  static const double pageMargin = 16;

  /// The gap between two weeks.
  static const double rowGap = 4;

  /// Height of the weekday labels and of the legend at normal text size.
  static const double weekdayRowHeight = 22;
  static const double legendHeight = 34;

  /// Text sizes above this ask for no more room than this.
  static const double _maxTextScale = 1.3;

  static CalendarLayout forArea(Size area, {double textScale = 1}) {
    final scale = textScale.clamp(1.0, _maxTextScale);
    final cardPadding = area.width < 360 ? 4.0 : 12.0;

    final usableWidth = math.min(
      area.width - 2 * pageMargin,
      ContentWidths.calendar,
    );
    final byWidth = (usableWidth - 2 * cardPadding) / 7;

    // Six weeks is the most a month needs; the rest of the page is chrome: the
    // weekday labels, the card's padding, the gaps between weeks, the legend
    // and the space around them.
    final chrome =
        weekdayRowHeight * scale +
        legendHeight * scale +
        2 * cardPadding +
        5 * rowGap +
        pageMargin * 2;
    final byHeight = (area.height - chrome) / 6;

    final cell = math.min(byWidth, byHeight).clamp(minCell, maxCell);
    return CalendarLayout(cellSize: cell.toDouble(), cardPadding: cardPadding);
  }
}
