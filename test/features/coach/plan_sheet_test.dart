import 'package:altidial/app/settings/settings_providers.dart';
import 'package:altidial/app/theme/app_theme.dart';
import 'package:altidial/core/coach/planner.dart';
import 'package:altidial/core/geometry/minute_range.dart';
import 'package:altidial/core/strings.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/data/repositories/stats_repository.dart';
import 'package:altidial/features/clock/data/event_repository.dart';
import 'package:altidial/features/clock/providers.dart';
import 'package:altidial/features/coach/providers.dart';
import 'package:altidial/features/coach/widgets/plan_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_event_repository.dart';
import '../../support/fake_settings_repository.dart';
import '../../support/fake_stats_repository.dart';

const _suggestion = SwapSuggestion(
  eventId: 1,
  fromStartMinute: 840,
  toStartMinute: 540,
  durationMinutes: 120,
  reason: SwapReason.peak,
  evidence: 'Your peak: 9:00',
);

CalendarEvent _event(DateTime day) => CalendarEvent(
  id: 1,
  seriesId: null,
  date: startOfDay(day),
  title: 'Deep work',
  tone: Tone.focus,
  range: const MinuteRange(840, 960),
  status: EventStatus.planned,
);

/// Throws on every move, as a day with three full rings would.
class _OverflowEvents extends FakeEventRepository {
  @override
  Future<void> moveEvent({
    required int id,
    required DateTime day,
    required MinuteRange range,
  }) async {
    throw const RingOverflowException();
  }
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  required DateTime day,
  required DateTime now,
  required List<SwapSuggestion> suggestions,
  required List<CalendarEvent> events,
  required EventRepository eventRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        suggestionsProvider.overrideWithValue(AsyncValue.data(suggestions)),
        dayEventsProvider.overrideWith((ref) => Stream.value(events)),
        eventRepositoryProvider.overrideWithValue(eventRepository),
        clockProvider.overrideWith(() => FakeClock(now)),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: PlanSheet(day: day)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('topPeakHours', () {
    test('returns the top-2 hours by focus minutes', () {
      final snapshot = StatsSnapshot(
        toneByDay: const [],
        plannedByTone: const [],
        focus: const FocusDepth(
          minutes: 0,
          longestSeconds: 0,
          averageSeconds: 0,
          ended: 0,
          abandoned: 0,
        ),
        focusInstants: [
          (startedAt: DateTime(2026, 10, 1, 9, 10), activeSeconds: 3600),
          (startedAt: DateTime(2026, 10, 2, 10, 5), activeSeconds: 1800),
          (startedAt: DateTime(2026, 10, 3, 14, 0), activeSeconds: 600),
        ],
      );
      expect(topPeakHours(snapshot), [9, 10]);
    });

    test('returns empty when there is no focus', () {
      expect(topPeakHours(const StatsSnapshot.empty()), isEmpty);
    });
  });

  group('suggestionsProvider wiring', () {
    test('asks for the 28d window and suggests the heatmap peak', () async {
      final day = DateTime(2026, 10, 15);
      final events = FakeEventRepository();
      await events.createEvent(
        day: day,
        title: 'Deep work',
        tone: Tone.focus,
        range: const MinuteRange(840, 960),
      );
      final stats = FakeStatsRepository(
        snapshot: StatsSnapshot(
          toneByDay: const [],
          plannedByTone: const [],
          focus: const FocusDepth(
            minutes: 0,
            longestSeconds: 0,
            averageSeconds: 0,
            ended: 0,
            abandoned: 0,
          ),
          focusInstants: [
            (startedAt: DateTime(2026, 10, 1, 9, 10), activeSeconds: 3600),
            (startedAt: DateTime(2026, 10, 2, 10, 5), activeSeconds: 1800),
          ],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWith(
            () => FakeClock(DateTime(2026, 10, 15, 10)),
          ),
          eventRepositoryProvider.overrideWithValue(events),
          statsRepositoryProvider.overrideWithValue(stats),
          settingsRepositoryProvider.overrideWithValue(
            FakeSettingsRepository(),
          ),
        ],
      );
      addTearDown(() {
        container.dispose();
        events.dispose();
        stats.dispose();
      });

      // Settle the watched streams before reading the combined provider.
      await container.read(coachWindowProvider.future);
      await container.read(dayEventsProvider.future);
      await container.read(focusTargetProvider.future);

      final suggestions = container.read(suggestionsProvider).valueOrNull;
      expect(suggestions, hasLength(1));
      expect(suggestions!.single.eventId, 1);
      expect(suggestions.single.toStartMinute, 540);

      expect(stats.requests, hasLength(1));
      expect(stats.requests.single.from, DateTime(2026, 9, 18));
      expect(stats.requests.single.to, DateTime(2026, 10, 16));
    });
  });

  testWidgets('plan sheet lists suggestions with accept', (tester) async {
    final day = DateTime(2026, 10, 15);
    final fake = FakeEventRepository();
    await fake.createEvent(
      day: day,
      title: 'Deep work',
      tone: Tone.focus,
      range: const MinuteRange(840, 960),
    );
    addTearDown(fake.dispose);

    await _pumpSheet(
      tester,
      day: day,
      now: DateTime(2026, 10, 15, 10, 30),
      suggestions: const [_suggestion],
      events: [fake.eventById(1)!],
      eventRepository: fake,
    );

    expect(find.text('Deep work'), findsOneWidget);
    expect(find.text('14:00 → 09:00'), findsOneWidget);
    expect(find.text(Strings.coachReasonPeak), findsOneWidget);

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(fake.eventById(1)!.range, const MinuteRange(540, 660));
  });

  testWidgets('plan sheet shows the empty state', (tester) async {
    final fake = FakeEventRepository();
    addTearDown(fake.dispose);

    await _pumpSheet(
      tester,
      day: DateTime(2026, 10, 15),
      now: DateTime(2026, 10, 15, 10, 30),
      suggestions: const [],
      events: const [],
      eventRepository: fake,
    );

    expect(find.text(Strings.coachSuggestionsEmpty), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
  });

  testWidgets('dismiss removes the row without touching the database', (
    tester,
  ) async {
    final day = DateTime(2026, 10, 15);
    final fake = FakeEventRepository();
    await fake.createEvent(
      day: day,
      title: 'Deep work',
      tone: Tone.focus,
      range: const MinuteRange(840, 960),
    );
    addTearDown(fake.dispose);

    await _pumpSheet(
      tester,
      day: day,
      now: DateTime(2026, 10, 15, 10, 30),
      suggestions: const [_suggestion],
      events: [fake.eventById(1)!],
      eventRepository: fake,
    );

    await tester.tap(find.text(Strings.dismiss));
    await tester.pumpAndSettle();

    expect(find.text('Deep work'), findsNothing);
    expect(find.text(Strings.coachSuggestionsEmpty), findsOneWidget);
    // The event itself is untouched.
    expect(fake.eventById(1)!.range, const MinuteRange(840, 960));
  });

  testWidgets('past-day sheet hides Accept buttons', (tester) async {
    final day = DateTime(2026, 10, 12);
    final fake = FakeEventRepository();
    addTearDown(fake.dispose);

    await _pumpSheet(
      tester,
      day: day,
      now: DateTime(2026, 10, 13, 10, 30),
      suggestions: const [_suggestion],
      events: [_event(day)],
      eventRepository: fake,
    );

    expect(find.text('14:00 → 09:00'), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
    expect(find.text(Strings.dismiss), findsOneWidget);
  });

  testWidgets('accept shows a SnackBar when the rings overflow', (
    tester,
  ) async {
    final day = DateTime(2026, 10, 15);
    final fake = _OverflowEvents();
    addTearDown(fake.dispose);

    await _pumpSheet(
      tester,
      day: day,
      now: DateTime(2026, 10, 15, 10, 30),
      suggestions: const [_suggestion],
      events: [_event(day)],
      eventRepository: fake,
    );

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(find.text(Strings.ringOverflow), findsOneWidget);
  });
}
