// Golden tests for [DialView]. Each PNG is captured from a [RepaintBoundary]
// tightly wrapping a 390x390 dial, so the image pins geometry, colour, ring
// layout and text for the face, ticks, numerals, event arcs, centre text and
// rim marker.
//
// `test/flutter_test_config.dart` loads the bundled Nunito font for every
// test, so numerals and curved arc labels render as real text and a golden can
// show whether labels read the right way up. The clock is fixed at 10:30 on
// 23 August 2026 and animations are off, so every image is deterministic.
import 'package:altidial/app/theme/app_theme.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/features/clock/data/event_repository.dart';
import 'package:altidial/features/clock/model/calendar_event.dart';
import 'package:altidial/features/clock/providers.dart';
import 'package:altidial/features/clock/widgets/dial_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';

CalendarEvent event(int id, MinuteRange range, Tone tone, String title) {
  return CalendarEvent(
    id: id,
    seriesId: null,
    date: DateTime(2026, 8, 23),
    title: title,
    tone: tone,
    range: range,
    status: EventStatus.planned,
  );
}

/// Key on the [RepaintBoundary] the goldens are captured from, so
/// `matchesGoldenFile` grabs a tight 390x390 image of the dial itself
/// instead of the entire (much larger) test window.
const dialGoldenKey = ValueKey('dial-golden');

Widget harness({
  required List<CalendarEvent> events,
  required ThemeData theme,
  DateTime? day,
  bool readOnly = false,
}) {
  return ProviderScope(
    overrides: [
      clockProvider.overrideWith(
        () => FakeClock(DateTime(2026, 8, 23, 10, 30)),
      ),
    ],
    child: MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: dialGoldenKey,
            child: SizedBox(
              width: 390,
              height: 390,
              child: DialView(
                events: events,
                day: day ?? DateTime(2026, 8, 23),
                readOnly: readOnly,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  // One ring: nothing overlaps. Deep work is running at 10:30.
  final separate = [
    event(1, const MinuteRange(540, 720), Tone.focus, 'Deep work'),
    event(2, const MinuteRange(780, 840), Tone.life, 'Lunch'),
    event(3, const MinuteRange(1020, 1080), Tone.inbox, 'Email'),
  ];

  // Two rings.
  final twoLevels = [
    event(1, const MinuteRange(540, 720), Tone.focus, 'Deep work'),
    event(2, const MinuteRange(600, 660), Tone.life, 'Walk'),
  ];

  // Three rings.
  final threeLevels = [
    event(1, const MinuteRange(540, 720), Tone.focus, 'Deep work'),
    event(2, const MinuteRange(600, 660), Tone.life, 'Walk'),
    event(3, const MinuteRange(610, 630), Tone.inbox, 'Call'),
  ];

  // The sample day, whose first two events run back to back on one ring: the
  // second arc's round cap covers the end of the first, and the first arc's
  // label must slide clear of it rather than be clipped or lost.
  final backToBack = [
    event(1, const MinuteRange(540, 660), Tone.focus, 'Deep work'),
    event(2, const MinuteRange(660, 705), Tone.inbox, 'Email and calls'),
    event(3, const MinuteRange(750, 795), Tone.life, 'Lunch walk'),
    event(4, const MinuteRange(840, 960), Tone.focus, 'Writing'),
  ];

  Future<void> check(WidgetTester tester, Widget app, String file) async {
    await tester.pumpWidget(app);
    await tester.pump();
    await expectLater(
      find.byKey(dialGoldenKey),
      matchesGoldenFile('goldens/$file'),
    );
  }

  testWidgets('empty day, light: the hint arc and the face at full size', (
    tester,
  ) async {
    await check(
      tester,
      harness(events: const [], theme: AppTheme.light),
      'dial_empty_light.png',
    );
  });

  testWidgets('one ring, light: arcs, labels, rim marker, centre text', (
    tester,
  ) async {
    await check(
      tester,
      harness(events: separate, theme: AppTheme.light),
      'dial_one_ring_light.png',
    );
  });

  testWidgets('one ring, dark', (tester) async {
    await check(
      tester,
      harness(events: separate, theme: AppTheme.dark),
      'dial_one_ring_dark.png',
    );
  });

  testWidgets('two rings, light: the face shrinks to make room', (
    tester,
  ) async {
    await check(
      tester,
      harness(events: twoLevels, theme: AppTheme.light),
      'dial_two_rings_light.png',
    );
  });

  testWidgets('three rings, light: today\'s size, the smallest face', (
    tester,
  ) async {
    await check(
      tester,
      harness(events: threeLevels, theme: AppTheme.light),
      'dial_three_rings_light.png',
    );
  });

  testWidgets('three rings, dark', (tester) async {
    await check(
      tester,
      harness(events: threeLevels, theme: AppTheme.dark),
      'dial_three_rings_dark.png',
    );
  });

  testWidgets(
    'back-to-back events, light: no label is clipped by a neighbour',
    (tester) async {
      await check(
        tester,
        harness(events: backToBack, theme: AppTheme.light),
        'dial_back_to_back_light.png',
      );
    },
  );

  testWidgets('a past day, light: no marker and no hint', (tester) async {
    await check(
      tester,
      harness(
        events: separate,
        theme: AppTheme.light,
        day: DateTime(2026, 8, 22),
        readOnly: true,
      ),
      'dial_past_day_light.png',
    );
  });

  testWidgets('an empty past day, light: just the face', (tester) async {
    await check(
      tester,
      harness(
        events: const [],
        theme: AppTheme.light,
        day: DateTime(2026, 8, 22),
        readOnly: true,
      ),
      'dial_past_empty_light.png',
    );
  });
}
