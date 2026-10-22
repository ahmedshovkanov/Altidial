import 'package:energy_clock/features/calendar/calendar_layout.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a phone is limited by its width: seven cells across the card', () {
    final layout = CalendarLayout.forArea(const Size(402, 900));

    expect(layout.cardPadding, 12);
    // (402 - 2 * 16 margin - 2 * 12 padding) / 7.
    expect(layout.cellSize, closeTo(346 / 7, 1e-9));
    expect(layout.cardWidth, closeTo(7 * layout.cellSize + 24, 1e-9));
  });

  test(
    'the narrowest window shrinks the card padding to keep cells near 40',
    () {
      final layout = CalendarLayout.forArea(const Size(320, 900));

      expect(layout.cardPadding, 4);
      expect(layout.cellSize, closeTo(40, 1e-9));
      expect(layout.cardWidth, lessThanOrEqualTo(320 - 32));
    },
  );

  test('a wide window stops at the largest cell and the content width', () {
    final layout = CalendarLayout.forArea(const Size(1194, 1000));

    expect(layout.cellSize, CalendarLayout.maxCell);
    expect(layout.cardWidth, lessThanOrEqualTo(640));
  });

  test('a short window makes the cells smaller, but not under the minimum', () {
    final roomy = CalendarLayout.forArea(const Size(402, 900));
    final tight = CalendarLayout.forArea(const Size(402, 400));
    final tiny = CalendarLayout.forArea(const Size(402, 200));

    expect(tight.cellSize, lessThan(roomy.cellSize));
    expect(tiny.cellSize, CalendarLayout.minCell);
  });

  test('larger text asks for more room, so the cells never grow with it', () {
    final normal = CalendarLayout.forArea(const Size(834, 560));
    final large = CalendarLayout.forArea(const Size(834, 560), textScale: 1.3);

    expect(large.cellSize, lessThanOrEqualTo(normal.cellSize));
  });

  test('text above 130% asks for no more room than 130%', () {
    final capped = CalendarLayout.forArea(const Size(834, 560), textScale: 1.3);
    final huge = CalendarLayout.forArea(const Size(834, 560), textScale: 3.12);

    expect(huge.cellSize, capped.cellSize);
  });

  test('the card always fits inside the window', () {
    for (final width in [320.0, 375.0, 402.0, 744.0, 834.0, 1194.0]) {
      final layout = CalendarLayout.forArea(Size(width, 700));
      expect(layout.cardWidth, lessThanOrEqualTo(width), reason: '$width');
    }
  });
}
