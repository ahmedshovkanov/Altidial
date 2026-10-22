import 'package:energy_clock/app/navigation/tab_bar_inset.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/clock_screen.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/clock/widgets/clock_header.dart';
import 'package:energy_clock/features/clock/widgets/day_load_bar.dart';
import 'package:energy_clock/features/clock/widgets/dial_view.dart';
import 'package:energy_clock/features/clock/widgets/event_detail_sheet.dart';
import 'package:energy_clock/features/clock/widgets/now_card.dart';
import 'package:energy_clock/features/clock/widgets/week_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';
import '../../support/dial_pump.dart';

/// What the tab shell reserves for the floating bar on a phone with no home
/// indicator: 64 bar + 12 margin + 8 gap.
const double shellInset = 84;

Widget screen() => const TabBarInset(height: shellInset, child: ClockScreen());

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness(); // Wednesday 7 October 2026, 10:30
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

  void setWindow(WidgetTester tester, double width, double height) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('an empty day shows the invitation', (tester) async {
    setWindow(tester, 402, 874);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);
    expect(find.text(Strings.emptyDayTitle), findsOneWidget);
  });

  testWidgets('a day with events hides the invitation', (tester) async {
    setWindow(tester, 402, 874);
    await add('Deep work', Tone.focus, 540, 720);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);
    expect(find.text(Strings.emptyDayTitle), findsNothing);
  });

  testWidgets('a tall phone shows every piece', (tester) async {
    setWindow(tester, 402, 874);
    await add('Deep work', Tone.focus, 540, 720);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);

    expect(find.byType(ClockHeader), findsOneWidget);
    expect(find.byType(WeekStrip), findsOneWidget);
    expect(find.byType(DialView), findsOneWidget);
    expect(find.byType(NowCard), findsOneWidget);
    expect(find.byType(DayLoadBar), findsOneWidget);
  });

  testWidgets('on a short phone the day-load bar is dropped', (tester) async {
    setWindow(tester, 375, 667);
    await add('Deep work', Tone.focus, 540, 720);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);

    expect(find.byType(NowCard), findsOneWidget);
    expect(find.byType(DayLoadBar), findsNothing);
  });

  testWidgets('the + button opens the new-event sheet', (tester) async {
    setWindow(tester, 402, 874);
    // Reduced motion: on an empty day the dial's hint arc pulses forever, and
    // pumpAndSettle below would never return.
    await tester.pumpWidget(harness.app(screen(), reduceMotion: true));
    await pumpDial(tester);

    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == Strings.addEvent,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(Strings.newEvent), findsOneWidget);
  });

  testWidgets('tapping the Now card opens the running event', (tester) async {
    setWindow(tester, 402, 874);
    await add('Deep work', Tone.focus, 540, 720);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);

    await tester.tap(find.byType(NowCard));
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailSheet), findsOneWidget);
  });

  testWidgets('a past day is read-only: chip shown and no + button', (
    tester,
  ) async {
    setWindow(tester, 402, 874);
    await tester.pumpWidget(harness.app(screen()));
    harness.container
        .read(selectedDateProvider.notifier)
        .select(DateTime(2026, 10, 6));
    await pumpDial(tester);

    expect(find.text(Strings.readOnlyChip), findsWidgets);
    expect(find.byTooltip(Strings.addEvent), findsNothing);
  });

  testWidgets('changing day through the strip updates the Now card', (
    tester,
  ) async {
    setWindow(tester, 402, 874);
    await add('Thursday plan', Tone.life, 540, 600, day: DateTime(2026, 10, 8));
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);
    expect(find.text('Thursday · 1 event'), findsNothing);

    await tester.tap(find.text('8'));
    await pumpDial(tester);
    expect(find.text('Thursday · 1 event'), findsOneWidget);
  });

  testWidgets('a medium window is a centred column', (tester) async {
    setWindow(tester, 834, 1194);
    await add('Deep work', Tone.focus, 540, 720);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);

    final width = tester.getSize(find.byType(NowCard)).width;
    expect(width, lessThanOrEqualTo(560));
    expect(tester.getCenter(find.byType(NowCard)).dx, closeTo(417, 1));
  });

  group('layout matrix, narrow and medium windows', () {
    const sizes = {
      'iPhone SE': Size(375, 667),
      'iPhone 17 Pro': Size(402, 874),
      'iPad mini portrait': Size(744, 1133),
      'iPad 11" portrait': Size(834, 1194),
      'narrow Split View': Size(320, 1000),
    };

    for (final entry in sizes.entries) {
      for (final textScale in const [1.0, 1.3, 2.0]) {
        for (final withEvents in const [false, true]) {
          testWidgets('${entry.key}, text ${textScale * 100}%, '
              '${withEvents ? 'with' : 'without'} events', (tester) async {
            setWindow(tester, entry.value.width, entry.value.height);
            if (withEvents) {
              await add('Deep work', Tone.focus, 540, 720);
              await add('Walk', Tone.life, 600, 660);
              await add('A call with a long title', Tone.inbox, 610, 630);
            }
            await tester.pumpWidget(
              harness.app(screen(), textScale: textScale),
            );
            await pumpDial(tester);

            expect(tester.takeException(), isNull);
            final dial = tester.getSize(find.byType(DialView));
            expect(
              dial.shortestSide,
              greaterThanOrEqualTo(240),
              reason: 'the dial area is ${dial.width} x ${dial.height}',
            );
          });
        }
      }
    }
  });
}
