import 'package:energy_clock/app/navigation/tab_bar_inset.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/features/clock/clock_screen.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';
import '../../support/dial_pump.dart';

Finder moreButton() => find.byTooltip(Strings.moreActions);

/// A menu item by its label. On an empty day the buttons beneath the dial use
/// the same words, so a plain text finder can match twice.
Finder menuItem(String label) => find.descendant(
  of: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
  matching: find.text(label),
);

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

  Future<void> addDay(DateTime day) async {
    await harness.repository.createEvent(
      day: day,
      title: 'Deep work',
      tone: Tone.focus,
      range: const MinuteRange(540, 660),
    );
  }

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Reduced motion stops the empty day's pulsing hint, so the menu can settle.
    await tester.pumpWidget(
      harness.app(
        const TabBarInset(height: 84, child: ClockScreen()),
        reduceMotion: true,
      ),
    );
    await pumpDial(tester);
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(moreButton());
    await tester.pumpAndSettle();
  }

  testWidgets('a day with events offers Save as template only', (tester) async {
    await addDay(today);
    await addDay(yesterday);
    await mount(tester);

    await openMenu(tester);

    expect(menuItem(Strings.saveAsTemplate), findsOneWidget);
    expect(menuItem(Strings.copyYesterday), findsNothing);
    expect(menuItem(Strings.applyTemplate), findsNothing);
  });

  testWidgets('Save as template asks for a name and saves the day', (
    tester,
  ) async {
    await addDay(today);
    await mount(tester);

    await openMenu(tester);
    await tester.tap(menuItem(Strings.saveAsTemplate));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Office day');
    await tester.tap(find.text(Strings.save));
    await tester.pumpAndSettle();

    expect(harness.reuse.templates.single.name, 'Office day');
    expect(find.text(Strings.templateSaved('Office day')), findsOneWidget);
  });

  testWidgets('an empty day after a busy one offers Copy yesterday', (
    tester,
  ) async {
    await addDay(yesterday);
    await mount(tester);

    await openMenu(tester);
    expect(menuItem(Strings.copyYesterday), findsOneWidget);
    expect(menuItem(Strings.saveAsTemplate), findsNothing);

    await tester.tap(menuItem(Strings.copyYesterday));
    await pumpDial(tester);

    expect(await harness.repository.eventsForDay(today), hasLength(1));
    expect(moreButton(), findsOneWidget);
  });

  testWidgets('an empty day after an empty one has nothing to copy', (
    tester,
  ) async {
    await mount(tester);
    expect(menuItem(Strings.copyYesterday), findsNothing);
  });

  testWidgets('a past day with events can still be saved as a template', (
    tester,
  ) async {
    await addDay(yesterday);
    harness.container.read(selectedDateProvider.notifier).select(yesterday);
    await mount(tester);

    await openMenu(tester);

    expect(menuItem(Strings.saveAsTemplate), findsOneWidget);
    expect(menuItem(Strings.copyYesterday), findsNothing);
  });

  testWidgets('a past day with no events has no menu', (tester) async {
    harness.container.read(selectedDateProvider.notifier).select(yesterday);
    await mount(tester);

    expect(moreButton(), findsNothing);
  });
}
