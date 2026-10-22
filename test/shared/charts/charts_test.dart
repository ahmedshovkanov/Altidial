import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/shared/charts/donut_painter.dart';
import 'package:energy_clock/shared/charts/heatmap_painter.dart';
import 'package:energy_clock/shared/charts/paired_bars_painter.dart';
import 'package:energy_clock/shared/charts/stacked_bars_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const track = Color(0xFFEEEEEE);
  const focus = Color(0xFF7C5CFF);
  final colors = {for (final tone in Tone.values) tone: focus};

  test('stack fractions share the day total, or are all zero', () {
    final fractions = stackFractions({Tone.focus: 90, Tone.life: 30});
    expect(fractions[Tone.focus], closeTo(0.75, 0.0001));
    expect(fractions[Tone.life], closeTo(0.25, 0.0001));
    expect(fractions[Tone.inbox], 0);
    expect(stackFractions(const {}).values, everyElement(0));
  });

  test('stack geometry divides the width and clamps the bar', () {
    final narrow = stackGeometry(const Size(350, 120), 7);
    expect(narrow.slot, 50);
    expect(narrow.barWidth, lessThanOrEqualTo(28));

    final tiny = stackGeometry(const Size(70, 120), 7);
    expect(tiny.slot, 10);
    expect(tiny.barWidth, 2);
  });

  test('stacked bars repaint only when their inputs change', () {
    final days = [
      {Tone.focus: 60},
    ];
    final first = StackedBarsPainter(
      days: days,
      colors: colors,
      trackColor: track,
    );
    expect(
      first.shouldRepaint(
        StackedBarsPainter(days: days, colors: colors, trackColor: track),
      ),
      isFalse,
    );
    expect(
      first.shouldRepaint(
        StackedBarsPainter(
          days: [
            {Tone.focus: 30},
          ],
          colors: colors,
          trackColor: track,
        ),
      ),
      isTrue,
    );
  });

  test('donut sweeps cover the whole circle, or are empty', () {
    expect(donutSweeps(const []), isEmpty);
    expect(donutSweeps([(tone: Tone.focus, minutes: 0)]), isEmpty);

    final sweeps = donutSweeps([
      (tone: Tone.focus, minutes: 90),
      (tone: Tone.life, minutes: 30),
    ]);
    expect(sweeps.reduce((a, b) => a + b), closeTo(1, 0.0001));
    expect(sweeps.first, closeTo(0.75, 0.0001));
  });

  test('the donut repaints only when its inputs change', () {
    const segments = [(tone: Tone.focus, minutes: 60)];
    final first = DonutPainter(
      segments: segments,
      colors: colors,
      trackColor: track,
    );
    expect(
      first.shouldRepaint(
        DonutPainter(segments: segments, colors: colors, trackColor: track),
      ),
      isFalse,
    );
    expect(
      first.shouldRepaint(
        DonutPainter(
          segments: const [(tone: Tone.focus, minutes: 30)],
          colors: colors,
          trackColor: track,
        ),
      ),
      isTrue,
    );
  });

  test('paired fractions are relative to the shared maximum', () {
    final fractions = pairedFractions((
      tone: Tone.focus,
      planned: 120,
      completed: 90,
    ), 120);
    expect(fractions.planned, 1);
    expect(fractions.completed, closeTo(0.75, 0.0001));

    final zero = pairedFractions((
      tone: Tone.life,
      planned: 0,
      completed: 0,
    ), 0);
    expect(zero, (planned: 0, completed: 0));
  });

  test('paired bars repaint only when their inputs change', () {
    const rows = [(tone: Tone.focus, planned: 120, completed: 90)];
    final first = PairedBarsPainter(
      rows: rows,
      colors: colors,
      plannedColor: track,
    );
    expect(
      first.shouldRepaint(
        PairedBarsPainter(rows: rows, colors: colors, plannedColor: track),
      ),
      isFalse,
    );
    expect(
      first.shouldRepaint(
        PairedBarsPainter(
          rows: const [(tone: Tone.focus, planned: 60, completed: 60)],
          colors: colors,
          plannedColor: track,
        ),
      ),
      isTrue,
    );
  });

  test('heatmap cells run from base to peak', () {
    const base = Color(0xFFEEEEEE);
    const peak = Color(0xFF1A1A1A);
    expect(heatmapColor(base, peak, 0, 60), base);
    expect(heatmapColor(base, peak, 60, 60), peak);
    expect(heatmapColor(base, peak, 30, 60), Color.lerp(base, peak, 0.5));
    expect(heatmapColor(base, peak, 10, 0), base);
  });

  test('the heatmap painter requires a 7 by 24 matrix', () {
    expect(
      () => HeatmapPainter(matrix: const [], base: track, peak: track),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => HeatmapPainter(
        matrix: List.generate(7, (_) => List.filled(23, 0)),
        base: track,
        peak: track,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('the heatmap repaints only when its inputs change', () {
    final matrix = List.generate(7, (_) => List.filled(24, 0));
    final first = HeatmapPainter(matrix: matrix, base: track, peak: track);
    expect(
      first.shouldRepaint(
        HeatmapPainter(matrix: matrix, base: track, peak: track),
      ),
      isFalse,
    );
    expect(
      first.shouldRepaint(
        HeatmapPainter(
          matrix: List.generate(7, (_) => List.filled(24, 1)),
          base: track,
          peak: track,
        ),
      ),
      isTrue,
    );
  });
}
