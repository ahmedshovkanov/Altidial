import 'package:altidial/app/navigation/tab_bar_inset.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/data/repositories/reuse_repository.dart';
import 'package:altidial/features/clock/clock_screen.dart';
import 'package:altidial/features/clock/widgets/template_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';
import '../../support/dial_pump.dart';

/// A menu item by its label. On an empty day the buttons beneath the dial use
/// the same words, so a plain text finder can match twice.
Finder menuItem(String label) => find.descendant(
  of: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
  matching: find.text(label),
);

void main() {
  late ClockHarness harness;

  // Wednesday 7 October 2026.
  final today = DateTime(2026, 10, 7);

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  int addOffice() => harness.reuse.addTemplate('Office day', const [
    TemplateItem(
      title: 'Deep work',
      tone: Tone.focus,
      range: MinuteRange(540, 660),
    ),
    TemplateItem(
      title: 'Lunch walk',
      tone: Tone.life,
      range: MinuteRange(750, 795),
    ),
  ]);

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness.app(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => TemplatePickerSheet.show(context, day: today),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists the templates, newest first, with their summary', (
    tester,
  ) async {
    addOffice();
    harness.reuse.addTemplate('Quiet day', const [
      TemplateItem(
        title: 'Read',
        tone: Tone.life,
        range: MinuteRange(600, 660),
      ),
    ]);
    await open(tester);

    expect(find.text(Strings.applyTemplate), findsOneWidget);
    expect(find.text('Office day'), findsOneWidget);
    expect(find.text('Quiet day'), findsOneWidget);
    expect(find.text('2 events · 2h 45m'), findsOneWidget);
    expect(find.text('1 event · 1h'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Quiet day')).dy,
      lessThan(tester.getTopLeft(find.text('Office day')).dy),
    );
  });

  testWidgets('shows a dot for each tone a template uses', (tester) async {
    final id = addOffice();
    await open(tester);

    expect(find.byKey(ValueKey('template-dot-$id-focus')), findsOneWidget);
    expect(find.byKey(ValueKey('template-dot-$id-life')), findsOneWidget);
    expect(find.byKey(ValueKey('template-dot-$id-inbox')), findsNothing);
  });

  testWidgets('a row is read as one button with its summary', (tester) async {
    final handle = tester.ensureSemantics();
    addOffice();
    await open(tester);

    expect(
      tester.getSemantics(
        find.bySemanticsLabel('Office day, 2 events, 2 hours 45 minutes'),
      ),
      matchesSemantics(
        label: 'Office day, 2 events, 2 hours 45 minutes',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('with no templates it explains how to make one', (tester) async {
    await open(tester);

    expect(find.text(Strings.templatesEmptyTitle), findsOneWidget);
    expect(find.text(Strings.templatesEmptyBody), findsOneWidget);
  });

  testWidgets('tapping a template puts its events on the day and closes', (
    tester,
  ) async {
    addOffice();
    await open(tester);

    await tester.tap(find.text('Office day'));
    await tester.pumpAndSettle();

    expect(find.byType(TemplatePickerSheet), findsNothing);
    final events = await harness.repository.eventsForDay(today);
    expect(events.map((event) => event.title), ['Deep work', 'Lunch walk']);
  });

  testWidgets('a day that filled up meanwhile closes the sheet and says so', (
    tester,
  ) async {
    addOffice();
    await open(tester);
    await harness.repository.createEvent(
      day: today,
      title: 'Already here',
      tone: Tone.inbox,
      range: const MinuteRange(900, 960),
    );

    await tester.tap(find.text('Office day'));
    await tester.pumpAndSettle();

    expect(find.byType(TemplatePickerSheet), findsNothing);
    expect(find.text(Strings.dayNotEmpty), findsOneWidget);
    expect(await harness.repository.eventsForDay(today), hasLength(1));
  });

  testWidgets('deleting asks first, and confirming removes the template', (
    tester,
  ) async {
    addOffice();
    await open(tester);

    await tester.tap(find.byTooltip(Strings.deleteTemplate));
    await tester.pumpAndSettle();

    expect(find.text(Strings.deleteTemplateTitle), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, Strings.delete));
    await tester.pumpAndSettle();

    expect(harness.reuse.templates, isEmpty);
    expect(find.text('Office day'), findsNothing);
    expect(find.text(Strings.templatesEmptyTitle), findsOneWidget);
  });

  testWidgets('cancelling the delete keeps the template', (tester) async {
    addOffice();
    await open(tester);

    await tester.tap(find.byTooltip(Strings.deleteTemplate));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, Strings.cancel));
    await tester.pumpAndSettle();

    expect(harness.reuse.templates, hasLength(1));
    expect(find.text('Office day'), findsOneWidget);
  });

  testWidgets('the delete button is at least 44 x 44', (tester) async {
    addOffice();
    await open(tester);

    final size = tester.getSize(find.byTooltip(Strings.deleteTemplate));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('a long list scrolls inside the sheet', (tester) async {
    for (var i = 0; i < 25; i++) {
      harness.reuse.addTemplate('Template $i', const [
        TemplateItem(
          title: 'Block',
          tone: Tone.focus,
          range: MinuteRange(540, 600),
        ),
      ]);
    }
    await open(tester);

    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('Template 0'), findsOneWidget);
  });

  for (final width in [320.0, 402.0, 834.0]) {
    for (final textScale in [1.0, 2.0, 3.12]) {
      testWidgets(
        'fits a ${width.toInt()} pt window at text ${(textScale * 100).toInt()}%',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          addOffice();
          harness.reuse.addTemplate(
            'A template with a rather long name that has to wrap somewhere',
            const [
              TemplateItem(
                title: 'Block',
                tone: Tone.inbox,
                range: MinuteRange(540, 600),
              ),
            ],
          );
          await tester.pumpWidget(
            harness.app(
              Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      TemplatePickerSheet.show(context, day: today),
                  child: const Text('open'),
                ),
              ),
              textScale: textScale,
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  group('from the Clock screen', () {
    testWidgets('an empty day offers Apply template and fills from it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addOffice();
      await tester.pumpWidget(
        harness.app(
          const TabBarInset(height: 84, child: ClockScreen()),
          reduceMotion: true,
        ),
      );
      await pumpDial(tester);

      await tester.tap(find.byTooltip(Strings.moreActions));
      await tester.pumpAndSettle();
      await tester.tap(menuItem(Strings.applyTemplate));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Office day'));
      await tester.pumpAndSettle();

      expect(find.byType(TemplatePickerSheet), findsNothing);
      expect(await harness.repository.eventsForDay(today), hasLength(2));
    });

    testWidgets('a day with events does not offer it', (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await harness.repository.createEvent(
        day: today,
        title: 'Deep work',
        tone: Tone.focus,
        range: const MinuteRange(540, 660),
      );
      await tester.pumpWidget(
        harness.app(const TabBarInset(height: 84, child: ClockScreen())),
      );
      await pumpDial(tester);

      await tester.tap(find.byTooltip(Strings.moreActions));
      await tester.pumpAndSettle();

      expect(menuItem(Strings.applyTemplate), findsNothing);
      expect(menuItem(Strings.saveAsTemplate), findsOneWidget);
    });
  });
}
