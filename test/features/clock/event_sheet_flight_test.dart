import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/features/clock/widgets/event_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

Future<void> tapSave(WidgetTester tester) async {
  final finder = find.text(Strings.save);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('flight toggle reveals fields and validates codes', (
    tester,
  ) async {
    final harness = ClockHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      harness.app(
        EventSheet(
          day: DateTime(2026, 10, 14),
          initialRange: const MinuteRange(625, 850),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('flight-toggle')), findsOneWidget);
    expect(find.byKey(const Key('flight-from-field')), findsNothing);

    await tester.tap(find.byKey(const Key('flight-toggle')));
    await tester.pump();

    expect(find.byKey(const Key('flight-number-field')), findsOneWidget);
    expect(find.byKey(const Key('flight-from-field')), findsOneWidget);
    expect(find.byKey(const Key('flight-to-field')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('flight-from-field')), 'so');
    await tester.pump();
    expect(find.text(Strings.flightAirportError), findsOneWidget);

    await tester.enterText(find.byKey(const Key('flight-from-field')), 'SOF');
    await tester.enterText(find.byKey(const Key('flight-to-field')), 'BER');
    await tester.pump();
    expect(find.text(Strings.flightAirportError), findsNothing);
  });

  testWidgets('converting a Focus event to a flight forces Inbox tone', (
    tester,
  ) async {
    final harness = ClockHarness();
    addTearDown(harness.dispose);
    final day = DateTime(2026, 10, 14);
    const range = MinuteRange(540, 600);

    final id = await harness.repository.createEvent(
      day: day,
      title: 'Deep work',
      tone: Tone.focus,
      range: range,
    );
    final existing = (await harness.repository.eventsForDay(
      day,
    )).singleWhere((e) => e.id == id);

    await tester.pumpWidget(
      harness.app(
        EventSheet(day: day, initialRange: range, existing: existing),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('flight-toggle')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('flight-from-field')), 'SOF');
    await tester.enterText(find.byKey(const Key('flight-to-field')), 'BER');
    await tester.pump();

    await tapSave(tester);

    final updated = harness.repository.eventById(id)!;
    expect(updated.isFlight, isTrue);
    expect(updated.tone, Tone.inbox);
  });

  testWidgets('invalid flight number shows an error and blocks save', (
    tester,
  ) async {
    final harness = ClockHarness();
    addTearDown(harness.dispose);
    final day = DateTime(2026, 10, 14);

    await tester.pumpWidget(
      harness.app(
        EventSheet(
          day: day,
          initialRange: const MinuteRange(625, 850),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('flight-toggle')));
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'Trip');
    await tester.enterText(find.byKey(const Key('flight-from-field')), 'SOF');
    await tester.enterText(find.byKey(const Key('flight-to-field')), 'BER');
    await tester.enterText(
      find.byKey(const Key('flight-number-field')),
      'LH-715',
    );
    await tester.pump();

    expect(find.text(Strings.flightNumberError), findsOneWidget);

    await tapSave(tester);

    expect(await harness.repository.eventsForDay(day), isEmpty);
  });
}
