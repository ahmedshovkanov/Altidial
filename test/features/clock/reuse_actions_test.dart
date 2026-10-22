import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/features/clock/widgets/reuse_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;

  final yesterday = DateTime(2026, 10, 6);
  final today = DateTime(2026, 10, 7);

  setUp(() {
    harness = ClockHarness();
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
    await harness.repository.createEvent(
      day: day,
      title: 'Lunch walk',
      tone: Tone.life,
      range: const MinuteRange(750, 795),
    );
  }

  /// Mounts one button that runs [action] on [today] and taps it.
  Future<void> run(
    WidgetTester tester,
    Future<void> Function(BuildContext, WidgetRef, DateTime) action,
  ) async {
    await tester.pumpWidget(
      harness.app(
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => action(context, ref, today),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  group('saveDayAsTemplate', () {
    testWidgets('saves the day under the name and says so', (tester) async {
      await addDay(today);
      await run(tester, saveDayAsTemplate);

      await tester.enterText(find.byType(TextField), 'Office day');
      await tester.tap(find.text(Strings.save));
      await tester.pumpAndSettle();

      final template = harness.reuse.templates.single;
      expect(template.name, 'Office day');
      expect(template.eventCount, 2);
      expect(find.text(Strings.templateSaved('Office day')), findsOneWidget);
    });

    testWidgets('cancelling the name saves nothing', (tester) async {
      await addDay(today);
      await run(tester, saveDayAsTemplate);

      await tester.tap(find.text(Strings.cancel));
      await tester.pumpAndSettle();

      expect(harness.reuse.templates, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a day with nothing on it says it could not save', (
      tester,
    ) async {
      await run(tester, saveDayAsTemplate);

      await tester.enterText(find.byType(TextField), 'Empty');
      await tester.tap(find.text(Strings.save));
      await tester.pumpAndSettle();

      expect(harness.reuse.templates, isEmpty);
      expect(find.text(Strings.templateSaveFailed), findsOneWidget);
    });
  });

  group('copyPreviousDay', () {
    testWidgets('copies yesterday onto the day', (tester) async {
      await addDay(yesterday);
      await run(tester, copyPreviousDay);

      final copied = await harness.repository.eventsForDay(today);
      expect(copied.map((event) => event.title), ['Deep work', 'Lunch walk']);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a day that already has events is left alone and says so', (
      tester,
    ) async {
      await addDay(yesterday);
      await harness.repository.createEvent(
        day: today,
        title: 'Already here',
        tone: Tone.inbox,
        range: const MinuteRange(900, 960),
      );
      await run(tester, copyPreviousDay);

      expect(await harness.repository.eventsForDay(today), hasLength(1));
      expect(find.text(Strings.dayNotEmpty), findsOneWidget);
    });
  });
}
