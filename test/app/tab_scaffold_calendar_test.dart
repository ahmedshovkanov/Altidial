import 'package:altidial/app/navigation/app_tab_bar.dart';
import 'package:altidial/app/navigation/tab_scaffold.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/features/calendar/calendar_screen.dart';
import 'package:altidial/features/clock/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/clock_harness.dart';
import '../support/dial_pump.dart';

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness(); // Wednesday 7 October 2026
  });

  tearDown(() {
    harness.dispose();
  });

  // Reduced motion stops the empty Clock day's pulsing hint, which stays alive
  // under the Calendar tab, so the tests can settle.
  Widget app() => harness.app(const TabScaffold(), reduceMotion: true);

  int selectedTab(WidgetTester tester) =>
      tester.widget<AppTabBar>(find.byType(AppTabBar)).selectedIndex;

  testWidgets('the Calendar tab shows the month, not a placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await pumpDial(tester);

    await tester.tap(find.byKey(const ValueKey('tab-2')));
    await pumpDial(tester);

    expect(find.byType(CalendarScreen), findsOneWidget);
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text(Strings.comingSoon(Strings.tabCalendar)), findsNothing);
  });

  testWidgets('tapping a day opens it on the Clock tab', (tester) async {
    await tester.pumpWidget(app());
    await pumpDial(tester);
    await tester.tap(find.byKey(const ValueKey('tab-2')));
    await pumpDial(tester);

    await tester.tap(find.byKey(const ValueKey('day-2026-10-20')));
    await pumpDial(tester);

    expect(selectedTab(tester), 0);
    expect(
      harness.container.read(selectedDateProvider),
      DateTime(2026, 10, 20),
    );
    expect(find.text('Tuesday'), findsOneWidget);
    expect(find.text('20 October 2026'), findsOneWidget);
  });

  testWidgets('a past day opens read-only', (tester) async {
    await tester.pumpWidget(app());
    await pumpDial(tester);
    await tester.tap(find.byKey(const ValueKey('tab-2')));
    await pumpDial(tester);

    await tester.tap(find.byKey(const ValueKey('day-2026-10-02')));
    await pumpDial(tester);

    expect(selectedTab(tester), 0);
    expect(find.text(Strings.readOnlyChip), findsWidgets);
  });

  testWidgets('going back to the Calendar keeps the month it was on', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await pumpDial(tester);
    await tester.tap(find.byKey(const ValueKey('tab-2')));
    await pumpDial(tester);
    await tester.tap(find.byTooltip(Strings.nextMonth));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tab-0')));
    await pumpDial(tester);
    await tester.tap(find.byKey(const ValueKey('tab-2')));
    await pumpDial(tester);

    expect(find.text('November 2026'), findsOneWidget);
  });
}
