import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/geometry/minute_range.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/clock/data/event_repository.dart'
    show CalendarEvent, EventStatus;
import 'package:energy_clock/features/flight_deck/flight_deck_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_event_repository.dart';
import '../../support/fake_settings_repository.dart';

CalendarEvent flightOn(DateTime day, int start) => CalendarEvent(
  id: start,
  seriesId: null,
  date: DateTime(day.year, day.month, day.day),
  title: 'LH715',
  tone: Tone.inbox,
  range: MinuteRange(start, start + 120),
  status: EventStatus.planned,
  isFlight: true,
  flightNumber: 'LH715',
  fromCode: 'SOF',
  toCode: 'BER',
);

Widget host({
  required FakeEventRepository events,
  required ValueChanged<DateTime> onOpenDay,
}) => ProviderScope(
  overrides: [
    eventRepositoryProvider.overrideWithValue(events),
    settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: FlightDeckScreen(onOpenDay: onOpenDay)),
  ),
);

class FlakyFlightsRepository extends FakeEventRepository {
  int watchCalls = 0;

  @override
  Stream<List<CalendarEvent>> watchFlights(
    DateTime from,
    DateTime toExclusive,
  ) {
    watchCalls++;
    if (watchCalls == 1) return Stream.error(Exception('boom'));
    return super.watchFlights(from, toExclusive);
  }
}

void main() {
  testWidgets('shows the breathing launcher at the top', (tester) async {
    final events = FakeEventRepository();
    addTearDown(events.dispose);
    await tester.pumpWidget(host(events: events, onOpenDay: (_) {}));
    await tester.pumpAndSettle();
    expect(find.text(Strings.deckBreatheTitle), findsOneWidget);
  });

  testWidgets('hero shows next flight and opens its day on tap', (tester) async {
    final events = FakeEventRepository();
    addTearDown(events.dispose);
    final now = DateTime.now();
    final future = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 30));
    await events.createEvent(
      day: future, title: 'LH715', tone: Tone.inbox,
      range: const MinuteRange(625, 745),
      isFlight: true, flightNumber: 'LH715', fromCode: 'SOF', toCode: 'BER',
    );
    DateTime? opened;
    await tester.pumpWidget(host(events: events, onOpenDay: (d) => opened = d));
    await tester.pumpAndSettle();
    expect(find.text('Next flight'), findsOneWidget);
    expect(find.textContaining('SOF→BER'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('deck-hero-open')));
    expect(opened, DateTime(future.year, future.month, future.day));
  });

  testWidgets('empty days show the no-flights empty state', (tester) async {
    final events = FakeEventRepository();
    addTearDown(events.dispose);
    await tester.pumpWidget(host(events: events, onOpenDay: (_) {}));
    await tester.pumpAndSettle();
    expect(find.text('No flights yet'), findsOneWidget);
  });

  testWidgets('saved filter shows only starred cards', (tester) async {
    final events = FakeEventRepository();
    addTearDown(events.dispose);
    await tester.pumpWidget(host(events: events, onOpenDay: (_) {}));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing saved yet'), findsOneWidget);
    await tester.tap(find.text('Facts'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('deck-star')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing saved yet'), findsNothing);
  });

  testWidgets('load error shows retry and recovers on tap', (tester) async {
    final events = FlakyFlightsRepository();
    addTearDown(events.dispose);
    await tester.pumpWidget(host(events: events, onOpenDay: (_) {}));
    await tester.pumpAndSettle();
    expect(find.text(Strings.deckFlightsLoadError), findsOneWidget);
    expect(find.text(Strings.deckRetry), findsOneWidget);
    await tester.tap(find.text(Strings.deckRetry));
    await tester.pumpAndSettle();
    expect(events.watchCalls, greaterThanOrEqualTo(2));
    expect(find.text('No flights yet'), findsOneWidget);
  });
}
