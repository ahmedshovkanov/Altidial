import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/features/clock/providers.dart';
import 'package:altidial/features/clock/widgets/week_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;

  setUp(() {
    // Wednesday 7 October 2026: its week runs Monday 5 to Sunday 11.
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  Future<void> addEvent(DateTime day, Tone tone, int start) =>
      harness.repository.createEvent(
        day: day,
        title: 'Event',
        tone: tone,
        range: MinuteRange(start, start + 60),
      );

  testWidgets('shows the seven days of the selected week, Monday first', (
    tester,
  ) async {
    await tester.pumpWidget(harness.app(const WeekStrip()));
    await tester.pumpAndSettle();

    for (final label in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
      expect(find.text(label), findsOneWidget);
    }
    for (final date in ['5', '6', '7', '8', '9', '10', '11']) {
      expect(find.text(date), findsOneWidget);
    }
  });

  testWidgets('shows the week Sunday-first when the setting says so', (
    tester,
  ) async {
    harness.settings.values['first_day_of_week'] = '7';
    await tester.pumpWidget(harness.app(const WeekStrip()));
    await tester.pumpAndSettle();

    // The same week, 4–10 October 2026, now starting on Sunday.
    for (final label in ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']) {
      expect(find.text(label), findsOneWidget);
    }
    for (final date in ['4', '5', '6', '7', '8', '9', '10']) {
      expect(find.text(date), findsOneWidget);
    }
  });

  testWidgets('the selected day reads as selected, and today is announced', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(harness.app(const WeekStrip()));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.bySemanticsLabel('Wednesday 7 October, today')),
      matchesSemantics(
        label: 'Wednesday 7 October, today',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    expect(find.semantics.byLabel('Thursday 8 October'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('tapping a day selects it', (tester) async {
    await tester.pumpWidget(harness.app(const WeekStrip()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('9'));
    await tester.pump();

    expect(harness.container.read(selectedDateProvider), DateTime(2026, 10, 9));
  });

  testWidgets('past days can be selected too', (tester) async {
    await tester.pumpWidget(harness.app(const WeekStrip()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('5'));
    await tester.pump();
    expect(harness.container.read(selectedDateProvider), DateTime(2026, 10, 5));
  });

  testWidgets('shows a dot for each tone planned that day', (tester) async {
    await addEvent(DateTime(2026, 10, 7), Tone.focus, 60);
    await addEvent(DateTime(2026, 10, 7), Tone.life, 180);
    await addEvent(DateTime(2026, 10, 7), Tone.focus, 300);
    await tester.pumpWidget(harness.app(const WeekStrip()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('dot-2026-10-07-focus')), findsOneWidget);
    expect(find.byKey(const ValueKey('dot-2026-10-07-life')), findsOneWidget);
    expect(find.byKey(const ValueKey('dot-2026-10-07-inbox')), findsNothing);
    expect(find.byKey(const ValueKey('dot-2026-10-08-focus')), findsNothing);
  });

  testWidgets('the planned tones are part of the spoken label', (tester) async {
    final handle = tester.ensureSemantics();
    await addEvent(DateTime(2026, 10, 8), Tone.focus, 60);
    await addEvent(DateTime(2026, 10, 8), Tone.life, 180);
    await tester.pumpWidget(harness.app(const WeekStrip()));
    await tester.pumpAndSettle();

    expect(
      find.semantics.byLabel('Thursday 8 October, Focus and Life planned'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('a new event adds its dot straight away', (tester) async {
    await tester.pumpWidget(harness.app(const WeekStrip()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dot-2026-10-09-inbox')), findsNothing);

    await addEvent(DateTime(2026, 10, 9), Tone.inbox, 60);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dot-2026-10-09-inbox')), findsOneWidget);
  });

  testWidgets('dots are hidden when showDots is false', (tester) async {
    await addEvent(DateTime(2026, 10, 7), Tone.focus, 60);
    await tester.pumpWidget(harness.app(const WeekStrip(showDots: false)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dot-2026-10-07-focus')), findsNothing);
  });

  testWidgets('dots are hidden at large text sizes', (tester) async {
    await addEvent(DateTime(2026, 10, 7), Tone.focus, 60);
    await tester.pumpWidget(harness.app(const WeekStrip(), textScale: 2));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dot-2026-10-07-focus')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the pills fit the strip at the largest iOS text size', (
    tester,
  ) async {
    // Dynamic Type's largest accessibility size is about 3.1 times normal.
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness.app(const WeekStrip(), textScale: 3.12));
    await tester.pumpAndSettle();
    expect(find.text('Wed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'if the week cannot be read the strip still works, without dots',
    (tester) async {
      harness.dispose();
      harness = ClockHarness(
        overrides: [
          weekTonesProvider.overrideWith(
            (ref, weekStart) => Stream<Map<DateTime, Set<Tone>>>.error(
              StateError('database closed'),
            ),
          ),
        ],
      );
      await addEvent(DateTime(2026, 10, 7), Tone.focus, 60);
      await tester.pumpWidget(harness.app(const WeekStrip()));
      await tester.pumpAndSettle();

      expect(find.text('Wed'), findsOneWidget);
      expect(find.byKey(const ValueKey('dot-2026-10-07-focus')), findsNothing);

      await tester.tap(find.text('8'));
      await tester.pumpAndSettle();
      expect(
        harness.container.read(selectedDateProvider),
        DateTime(2026, 10, 8),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('swiping to the next week moves the selected day by seven days', (
    tester,
  ) async {
    await tester.pumpWidget(harness.app(const WeekStrip()));
    await tester.pumpAndSettle();

    await tester.fling(find.byType(PageView), const Offset(-500, 0), 1500);
    await tester.pumpAndSettle();

    expect(
      harness.container.read(selectedDateProvider),
      DateTime(2026, 10, 14),
    );
    expect(find.text('12'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
  });

  testWidgets('swiping back moves the selected day back by seven days', (
    tester,
  ) async {
    await tester.pumpWidget(harness.app(const WeekStrip()));
    await tester.pumpAndSettle();

    await tester.fling(find.byType(PageView), const Offset(500, 0), 1500);
    await tester.pumpAndSettle();

    expect(harness.container.read(selectedDateProvider), DateTime(2026, 9, 30));
  });

  testWidgets('selecting a date elsewhere moves the strip to its week', (
    tester,
  ) async {
    await tester.pumpWidget(harness.app(const WeekStrip()));
    await tester.pumpAndSettle();

    harness.container
        .read(selectedDateProvider.notifier)
        .select(DateTime(2026, 10, 21));
    await tester.pumpAndSettle();

    expect(find.text('19'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(
      harness.container.read(selectedDateProvider),
      DateTime(2026, 10, 21),
    );
  });

  testWidgets('with reduced motion the strip jumps instead of sliding', (
    tester,
  ) async {
    await tester.pumpWidget(harness.app(const WeekStrip(), reduceMotion: true));
    await tester.pumpAndSettle();

    harness.container
        .read(selectedDateProvider.notifier)
        .select(DateTime(2026, 11, 4));
    await tester.pump();
    expect(find.text('2'), findsOneWidget); // Monday 2 November
  });

  testWidgets('every pill is at least 44 pt wide on a 375 pt phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness.app(const WeekStrip()));
    await tester.pumpAndSettle();

    for (final date in ['5', '6', '7', '8', '9', '10', '11']) {
      final pill = find.ancestor(
        of: find.text(date),
        matching: find.byType(GestureDetector),
      );
      expect(tester.getSize(pill.first).width, greaterThanOrEqualTo(44));
    }
  });

  test('height budget', () {
    expect(WeekStrip.heightFor(1), 60);
    expect(WeekStrip.heightFor(2), 92);
    expect(WeekStrip.heightFor(3), 92); // clamped at 2
  });
}
