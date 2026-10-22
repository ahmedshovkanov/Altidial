import 'package:altidial/app/theme/tone_colors.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/features/clock/model/calendar_event.dart';
import 'package:altidial/features/clock/widgets/now_card.dart';
import 'package:altidial/shared/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;
  CalendarEvent? opened;

  setUp(() {
    opened = null;
  });

  tearDown(() {
    harness.dispose();
  });

  Future<void> add(
    String title,
    Tone tone,
    int start,
    int end, {
    DateTime? day,
  }) => harness.repository.createEvent(
    day: day ?? DateTime(2026, 10, 7),
    title: title,
    tone: tone,
    range: MinuteRange(start, end),
  );

  Future<void> show(
    WidgetTester tester, {
    bool compact = false,
    double textScale = 1,
  }) async {
    // Tight in width and unbounded in height, as in the Clock column, so the
    // card takes its natural height instead of filling the screen.
    await tester.pumpWidget(
      harness.app(
        UnconstrainedBox(
          constrainedAxis: Axis.horizontal,
          alignment: Alignment.topCenter,
          child: NowCard(onOpenEvent: (e) => opened = e, compact: compact),
        ),
        textScale: textScale,
      ),
    );
    await tester.pump();
  }

  Color? cardFill(WidgetTester tester) {
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(AppCard),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    return (box.decoration as ShapeDecoration).color;
  }

  group('today', () {
    testWidgets('free: invites you to plan', (tester) async {
      harness = ClockHarness();
      await show(tester);
      expect(find.text(Strings.emptyDayTitle), findsOneWidget);
      expect(find.text(Strings.emptyDayHint), findsOneWidget);
    });

    testWidgets('active: filled with the tone colour, with time left', (
      tester,
    ) async {
      harness = ClockHarness(); // 10:30
      await add('Deep work', Tone.focus, 540, 720); // 09:00-12:00
      await show(tester);

      expect(find.text('Deep work'), findsOneWidget);
      expect(find.text('Focus'), findsOneWidget);
      expect(find.text('1h 30m left · until 12:00'), findsOneWidget);
      expect(cardFill(tester), ToneColors.light.fillFor(Tone.focus));
      final title = tester.widget<Text>(find.text('Deep work'));
      expect(title.style!.color, ToneColors.light.labelFor(Tone.focus));
    });

    testWidgets('active on Life uses near-black text on the green card', (
      tester,
    ) async {
      harness = ClockHarness();
      await add('Walk', Tone.life, 600, 660);
      await show(tester);
      expect(cardFill(tester), ToneColors.light.fillFor(Tone.life));
      expect(
        tester.widget<Text>(find.text('Walk')).style!.color,
        ToneColors.light.labelFor(Tone.life),
      );
    });

    testWidgets('active with overlaps shows the latest-started and a count', (
      tester,
    ) async {
      harness = ClockHarness();
      await add('Deep work', Tone.focus, 540, 720);
      await add('Call', Tone.inbox, 600, 660);
      await show(tester);

      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Inbox · +1 overlapping'), findsOneWidget);
      expect(cardFill(tester), ToneColors.light.fillFor(Tone.inbox));
    });

    testWidgets('next: a neutral card says when it starts', (tester) async {
      harness = ClockHarness();
      await add('Lunch', Tone.life, 750, 795); // 12:30
      await show(tester);

      expect(find.text(Strings.nowNextUp), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('Starts at 12:30 · in 2h'), findsOneWidget);
      expect(cardFill(tester), isNot(ToneColors.light.fillFor(Tone.life)));
    });

    testWidgets('done: everything has finished', (tester) async {
      harness = ClockHarness(now: DateTime(2026, 10, 7, 20, 0));
      await add('Deep work', Tone.focus, 540, 720);
      await show(tester);

      expect(find.text(Strings.nowDoneTitle), findsOneWidget);
      expect(find.text('1 event · 3h planned'), findsOneWidget);
    });

    testWidgets('moves on by itself when the clock ticks', (tester) async {
      harness = ClockHarness(now: DateTime(2026, 10, 7, 11, 59));
      await add('Deep work', Tone.focus, 540, 720);
      await show(tester);
      expect(find.text('1m left · until 12:00'), findsOneWidget);

      harness.clock.set(DateTime(2026, 10, 7, 12, 0));
      await tester.pump();
      expect(find.text(Strings.nowDoneTitle), findsOneWidget);
    });
  });

  group('other days', () {
    testWidgets('a future day with events is summarised', (tester) async {
      harness = ClockHarness(selected: DateTime(2026, 10, 8)); // Thursday
      await add('A', Tone.focus, 540, 720, day: DateTime(2026, 10, 8));
      await add('B', Tone.life, 780, 825, day: DateTime(2026, 10, 8));
      await show(tester);

      expect(find.text('Thursday · 2 events'), findsOneWidget);
      expect(find.text('3h 45m planned'), findsOneWidget);
    });

    testWidgets('an empty future day invites you to plan', (tester) async {
      harness = ClockHarness(selected: DateTime(2026, 10, 8));
      await show(tester);
      expect(find.text(Strings.emptyDayTitle), findsOneWidget);
    });

    testWidgets('a past day says it is read-only', (tester) async {
      harness = ClockHarness(selected: DateTime(2026, 10, 6));
      await add('A', Tone.focus, 540, 720, day: DateTime(2026, 10, 6));
      await show(tester);

      expect(find.text(Strings.readOnlyChip), findsOneWidget);
      expect(find.text('1 event · 3h'), findsOneWidget);
    });

    testWidgets('an empty past day says nothing was planned', (tester) async {
      harness = ClockHarness(selected: DateTime(2026, 10, 6));
      await show(tester);
      expect(find.text(Strings.pastNothingPlanned), findsOneWidget);
    });
  });

  group('tapping', () {
    testWidgets('opens the running event', (tester) async {
      harness = ClockHarness();
      await add('Deep work', Tone.focus, 540, 720);
      await show(tester);

      await tester.tap(find.byType(NowCard));
      expect(opened?.title, 'Deep work');
    });

    testWidgets('opens the next event', (tester) async {
      harness = ClockHarness();
      await add('Lunch', Tone.life, 750, 795);
      await show(tester);

      await tester.tap(find.byType(NowCard));
      expect(opened?.title, 'Lunch');
    });

    testWidgets('does nothing when there is no event to open', (tester) async {
      harness = ClockHarness();
      await show(tester);
      await tester.tap(find.byType(NowCard));
      expect(opened, isNull);
    });
  });

  group('compact', () {
    testWidgets('is shorter and shows only the title and time left', (
      tester,
    ) async {
      harness = ClockHarness();
      await add('Deep work', Tone.focus, 540, 720);
      await show(tester, compact: true);

      expect(find.text('Deep work'), findsOneWidget);
      expect(find.text('1h 30m left'), findsOneWidget);
      expect(find.text('Focus'), findsNothing);
      expect(
        tester.getSize(find.byType(NowCard)).height,
        lessThan(NowCard.height),
      );
    });

    testWidgets('a free day is one line', (tester) async {
      harness = ClockHarness();
      await show(tester, compact: true);
      expect(find.text(Strings.emptyDayTitle), findsOneWidget);
      expect(find.text(Strings.emptyDayHint), findsNothing);
    });

    testWidgets('does not overflow at double text size', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      harness = ClockHarness();
      await add(
        'A rather long event title for a narrow screen',
        Tone.focus,
        540,
        720,
      );
      await show(tester, compact: true, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('semantics', () {
    testWidgets('a running event reads as one sentence', (tester) async {
      final handle = tester.ensureSemantics();
      harness = ClockHarness();
      await add('Deep work', Tone.focus, 540, 720);
      await show(tester);

      expect(
        tester.getSemantics(
          find.bySemanticsLabel(
            'Now: Deep work, Focus, 1 hour 30 minutes left',
          ),
        ),
        matchesSemantics(
          label: 'Now: Deep work, Focus, 1 hour 30 minutes left',
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('the next event reads as one sentence', (tester) async {
      final handle = tester.ensureSemantics();
      harness = ClockHarness();
      await add('Lunch', Tone.life, 750, 795);
      await show(tester);

      expect(
        find.semantics.byLabel('Next up: Lunch, Life, starts in 2 hours'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('height budgets', () {
    test('the constants', () {
      expect(NowCard.height, 96);
      expect(NowCard.heightFor(1), 96);
      expect(NowCard.heightFor(0.9), 96);
      expect(NowCard.heightFor(1.3), closeTo(108.8, 0.001));
      expect(NowCard.compactHeightFor(1), 52);
      expect(NowCard.compactHeightFor(2), 80);
    });

    // The tallest content: a running event with caption, title, time left and
    // progress bar.
    for (final scale in [1.0, 1.15, 1.3]) {
      testWidgets('the full card fits its budget at $scale', (tester) async {
        harness = ClockHarness();
        await add('Deep work', Tone.focus, 540, 720);
        await show(tester, textScale: scale);
        expect(
          tester.getSize(find.byType(NowCard)).height,
          lessThanOrEqualTo(NowCard.heightFor(scale)),
        );
      });
    }

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('the compact card fits its budget at $scale', (tester) async {
        harness = ClockHarness();
        await add('Deep work', Tone.focus, 540, 720);
        await show(tester, compact: true, textScale: scale);
        expect(
          tester.getSize(find.byType(NowCard)).height,
          lessThanOrEqualTo(NowCard.compactHeightFor(scale)),
        );
      });
    }
  });
}
