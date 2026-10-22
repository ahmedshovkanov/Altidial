import 'package:altidial/app/navigation/tab_bar_inset.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/features/clock/clock_screen.dart';
import 'package:altidial/features/clock/providers.dart';
import 'package:altidial/features/clock/widgets/dial_view.dart';
import 'package:altidial/features/clock/widgets/reuse_row.dart';
import 'package:altidial/features/clock/widgets/template_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';
import '../../support/dial_pump.dart';

void main() {
  late ClockHarness harness;

  final yesterday = DateTime(2026, 10, 6);
  final today = DateTime(2026, 10, 7);

  setUp(() {
    harness = ClockHarness(); // Wednesday 7 October 2026, 10:30
  });

  tearDown(() {
    harness.dispose();
  });

  Future<void> addEvent(DateTime day) => harness.repository.createEvent(
    day: day,
    title: 'Deep work',
    tone: Tone.focus,
    range: const MinuteRange(540, 660),
  );

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(402, 874),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness.app(
        const TabBarInset(height: 84, child: ClockScreen()),
        textScale: textScale,
        reduceMotion: true,
      ),
    );
    await pumpDial(tester);
  }

  testWidgets('an empty editable day shows both buttons beneath the dial', (
    tester,
  ) async {
    await addEvent(yesterday);
    await mount(tester);

    expect(find.byType(ReuseRow), findsOneWidget);
    // The row's buttons, not the overflow menu's items (the menu is closed).
    expect(find.text(Strings.copyYesterday), findsOneWidget);
    expect(find.text(Strings.applyTemplate), findsOneWidget);
    expect(find.text(Strings.emptyDayTitle), findsOneWidget);
  });

  testWidgets('with nothing to copy only Apply template is shown', (
    tester,
  ) async {
    await mount(tester);

    expect(find.text(Strings.copyYesterday), findsNothing);
    expect(find.text(Strings.applyTemplate), findsOneWidget);
  });

  testWidgets('Copy yesterday fills the day and the row goes away', (
    tester,
  ) async {
    await addEvent(yesterday);
    await mount(tester);

    await tester.tap(find.text(Strings.copyYesterday));
    await pumpDial(tester);

    expect(await harness.repository.eventsForDay(today), hasLength(1));
    expect(find.byType(ReuseRow), findsNothing);
  });

  testWidgets('Apply template opens the picker', (tester) async {
    await mount(tester);

    await tester.tap(find.text(Strings.applyTemplate));
    await tester.pumpAndSettle();

    expect(find.byType(TemplatePickerSheet), findsOneWidget);
  });

  testWidgets('a day with events shows no row', (tester) async {
    await addEvent(today);
    await addEvent(yesterday);
    await mount(tester);

    expect(find.byType(ReuseRow), findsNothing);
  });

  testWidgets('a past day shows no row', (tester) async {
    harness.container.read(selectedDateProvider.notifier).select(yesterday);
    await mount(tester);

    expect(find.byType(ReuseRow), findsNothing);
  });

  testWidgets('large text drops the row; the menu still has the actions', (
    tester,
  ) async {
    await addEvent(yesterday);
    await mount(tester, textScale: 2);

    expect(find.byType(ReuseRow), findsNothing);
    await tester.tap(find.byTooltip(Strings.moreActions));
    await tester.pumpAndSettle();
    expect(find.text(Strings.copyYesterday), findsOneWidget);
    expect(find.text(Strings.applyTemplate), findsOneWidget);
  });

  testWidgets('a short window drops the row too', (tester) async {
    await addEvent(yesterday);
    // 640 - 84 (the tab bar) leaves 556 pt: a dial of 291 with the row.
    await mount(tester, size: const Size(375, 640));

    expect(find.byType(ReuseRow), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a wide window puts the row in the right pane', (tester) async {
    await addEvent(yesterday);
    await mount(tester, size: const Size(1194, 834));

    expect(find.byType(ReuseRow), findsOneWidget);
    final row = tester.getTopLeft(find.byType(ReuseRow));
    final dial = tester.getCenter(find.byType(DialView));
    expect(row.dx, greaterThan(dial.dx));
    expect(tester.takeException(), isNull);
  });
}
