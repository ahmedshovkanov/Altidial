import 'dart:math' as math;

import 'package:altidial/app/theme/app_theme.dart';
import 'package:altidial/features/session/widgets/countdown_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const trackColor = Color(0xFF111111);
  const fillColor = Color(0xFF222222);

  Future<void> show(
    WidgetTester tester,
    double fraction, {
    String? semanticsLabel,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Center(
          child: CountdownRing(
            diameter: 300,
            fraction: fraction,
            color: fillColor,
            semanticsLabel: semanticsLabel,
            child: const Text('time', textDirection: TextDirection.ltr),
          ),
        ),
      ),
    );
  }

  RenderObject ringPaint(WidgetTester tester) => tester.renderObject(
    find
        .descendant(
          of: find.byType(CountdownRing),
          matching: find.byType(CustomPaint),
        )
        .first,
  );

  testWidgets('a part-filled ring paints an arc from the top, clockwise', (
    tester,
  ) async {
    await show(tester, 0.25);

    expect(
      ringPaint(tester),
      paints
        ..circle() // the track
        ..arc(
          startAngle: -math.pi / 2,
          sweepAngle: math.pi / 2,
          useCenter: false,
          color: fillColor,
        ),
    );
  });

  testWidgets('a full ring paints a whole circle, not an arc', (tester) async {
    await show(tester, 1);

    expect(
      ringPaint(tester),
      paints
        ..circle()
        ..circle(color: fillColor),
    );
  });

  testWidgets('an empty ring paints only the track', (tester) async {
    await show(tester, 0);

    expect(ringPaint(tester), paints..circle());
    expect(ringPaint(tester), isNot(paints..arc()));
  });

  testWidgets('shows its child in the middle', (tester) async {
    await show(tester, 0.5);
    expect(find.text('time'), findsOneWidget);
  });

  testWidgets('is read as the given sentence, and its child is not', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await show(tester, 0.5, semanticsLabel: 'Deep work, 10 minutes left');

    expect(find.bySemanticsLabel('Deep work, 10 minutes left'), findsOneWidget);
    expect(find.bySemanticsLabel('time'), findsNothing);
    handle.dispose();
  });

  group('the painter', () {
    CountdownRingPainter painter({
      double fraction = 0.5,
      double thickness = 10,
      Color color = fillColor,
      Color track = trackColor,
    }) => CountdownRingPainter(
      fraction: fraction,
      thickness: thickness,
      color: color,
      trackColor: track,
    );

    test('repaints only when something it draws changed', () {
      final base = painter();
      expect(base.shouldRepaint(painter()), isFalse);
      expect(base.shouldRepaint(painter(fraction: 0.4)), isTrue);
      expect(base.shouldRepaint(painter(thickness: 12)), isTrue);
      expect(base.shouldRepaint(painter(color: trackColor)), isTrue);
      expect(base.shouldRepaint(painter(track: fillColor)), isTrue);
    });
  });

  test(
    'the ring is thinner than a tenth of the face, and leaves room inside',
    () {
      expect(CountdownRing.thicknessFor(300), lessThan(30));
      expect(CountdownRing.innerWidthFor(300), greaterThan(150));
      expect(CountdownRing.innerWidthFor(300), lessThan(300));
    },
  );
}
