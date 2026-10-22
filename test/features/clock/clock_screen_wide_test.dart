import 'package:altidial/app/navigation/tab_bar_inset.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/features/clock/clock_screen.dart';
import 'package:altidial/features/clock/widgets/clock_header.dart';
import 'package:altidial/features/clock/widgets/day_load_bar.dart';
import 'package:altidial/features/clock/widgets/dial_view.dart';
import 'package:altidial/features/clock/widgets/event_detail_sheet.dart';
import 'package:altidial/features/clock/widgets/now_card.dart';
import 'package:altidial/features/clock/widgets/todays_plan_list.dart';
import 'package:altidial/features/clock/widgets/week_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';
import '../../support/dial_pump.dart';

Widget screen() => const TabBarInset(height: 84, child: ClockScreen());

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness(); // Wednesday 7 October 2026, 10:30
  });

  tearDown(() {
    harness.dispose();
  });

  Future<void> add(String title, Tone tone, int start, int end) =>
      harness.repository.createEvent(
        day: DateTime(2026, 10, 7),
        title: title,
        tone: tone,
        range: MinuteRange(start, end),
      );

  void setWindow(WidgetTester tester, double width, double height) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('a wide window shows two panes: the dial, then the rest', (
    tester,
  ) async {
    setWindow(tester, 1194, 834); // iPad 11" landscape
    await add('Deep work', Tone.focus, 540, 720);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);

    expect(find.byType(ClockHeader), findsOneWidget);
    expect(find.byType(WeekStrip), findsOneWidget);
    expect(find.byType(DialView), findsOneWidget);
    expect(find.byType(NowCard), findsOneWidget);
    expect(find.byType(DayLoadBar), findsOneWidget);
    expect(find.byType(TodaysPlanList), findsOneWidget);

    final dialRight = tester.getTopRight(find.byType(DialView)).dx;
    final cardLeft = tester.getTopLeft(find.byType(NowCard)).dx;
    expect(dialRight, lessThanOrEqualTo(cardLeft));
  });

  testWidgets('the dial radius is capped at 340', (tester) async {
    setWindow(tester, 1376, 1032); // iPad 13" landscape
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);
    expect(tester.widget<DialView>(find.byType(DialView)).maxRadius, 340);
  });

  testWidgets('the right pane is 36% of the window, between 340 and 440', (
    tester,
  ) async {
    setWindow(tester, 1194, 834);
    await add('Deep work', Tone.focus, 540, 720);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);
    // 0.36 * 1194 = 429.8, less 16 pt of padding on each side of the card.
    expect(
      tester.getSize(find.byType(NowCard)).width,
      closeTo(0.36 * 1194 - 32, 1),
    );

    setWindow(tester, 900, 800);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);
    // 0.36 * 900 = 324, which is below the 340 minimum.
    expect(tester.getSize(find.byType(NowCard)).width, closeTo(340 - 32, 1));

    setWindow(tester, 1376, 1032);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);
    // 0.36 * 1376 = 495, which is above the 440 maximum.
    expect(tester.getSize(find.byType(NowCard)).width, closeTo(440 - 32, 1));
  });

  testWidgets('a medium window keeps the single column and has no plan list', (
    tester,
  ) async {
    setWindow(tester, 834, 1194); // iPad 11" portrait
    await add('Deep work', Tone.focus, 540, 720);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);

    expect(find.byType(TodaysPlanList), findsNothing);
    expect(tester.widget<DialView>(find.byType(DialView)).maxRadius, isNull);
  });

  testWidgets('a narrow window keeps the single column too', (tester) async {
    setWindow(tester, 402, 874);
    await add('Deep work', Tone.focus, 540, 720);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);
    expect(find.byType(TodaysPlanList), findsNothing);
  });

  testWidgets('iPad 13" in portrait is wide too', (tester) async {
    setWindow(tester, 1032, 1376);
    await add('Deep work', Tone.focus, 540, 720);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);
    expect(find.byType(TodaysPlanList), findsOneWidget);
  });

  testWidgets('tapping a row in the plan list opens its details', (
    tester,
  ) async {
    setWindow(tester, 1194, 834);
    await add('Deep work', Tone.focus, 540, 720);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(TodaysPlanList),
        matching: find.text('Deep work'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailSheet), findsOneWidget);
  });

  testWidgets('the window can change class while the screen is open', (
    tester,
  ) async {
    setWindow(tester, 1194, 834);
    await add('Deep work', Tone.focus, 540, 720);
    await tester.pumpWidget(harness.app(screen()));
    await pumpDial(tester);
    expect(find.byType(TodaysPlanList), findsOneWidget);

    // Split View: the window shrinks to a phone-sized width.
    tester.view.physicalSize = const Size(400, 834);
    await pumpDial(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(TodaysPlanList), findsNothing);
    expect(find.byType(DialView), findsOneWidget);
  });

  testWidgets('large text on a wide window drops the bar and the dots', (
    tester,
  ) async {
    setWindow(tester, 1194, 834);
    await add('Deep work', Tone.focus, 540, 720);
    await tester.pumpWidget(harness.app(screen(), textScale: 2));
    await pumpDial(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(DayLoadBar), findsNothing);
    expect(find.byType(TodaysPlanList), findsOneWidget);
  });
}
