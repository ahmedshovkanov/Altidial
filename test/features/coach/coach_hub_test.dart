import 'dart:convert';

import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/coach/insights_rules.dart';
import 'package:energy_clock/core/coach/planner.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/coach_repository.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/coach/coach_screen.dart';
import 'package:energy_clock/features/coach/providers.dart';
import 'package:energy_clock/features/coach/widgets/coach_card.dart';
import 'package:energy_clock/features/coach/widgets/insight_card.dart';
import 'package:energy_clock/features/progress/widgets/coach_teaser_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';

class _FakeCoachRepository implements CoachRepository {
  _FakeCoachRepository({this.intent});

  CoachIntentRow? intent;

  @override
  Stream<CoachIntentRow?> watchIntent(DateTime day) => Stream.value(intent);

  @override
  Future<void> saveIntent({
    required DateTime day,
    required String focusGoal,
    int? predictedEnergy,
  }) async {
    intent = CoachIntentRow(
      date: day,
      focusGoal: focusGoal,
      predictedEnergy: predictedEnergy,
      createdAt: day,
    );
  }

  @override
  Stream<CoachReviewRow?> watchReview(DateTime day) => Stream.value(null);

  @override
  Future<void> saveReview({
    required DateTime day,
    required int energy,
    String? winText,
  }) async {}

  @override
  Stream<List<CoachInsightRow>> watchWeekInsights(
    int isoYear,
    int isoWeek,
  ) => Stream.value(const []);

  @override
  Future<void> ensureWeek(int isoYear, int isoWeek) async {}
}

const _suggestion = SwapSuggestion(
  eventId: 1,
  fromStartMinute: 840,
  toStartMinute: 540,
  durationMinutes: 120,
  reason: SwapReason.peak,
  evidence: 'Your peak: 9:00',
);

CoachIntentRow _intentRow(DateTime day, String goal) => CoachIntentRow(
  date: day,
  focusGoal: goal,
  createdAt: day,
);

CoachReviewRow _reviewRow(DateTime day) => CoachReviewRow(
  date: day,
  energy: 4,
  winText: 'Shipped the draft',
  createdAt: day,
);

CoachInsightRow _insightRow({
  required String kind,
  required String payloadJson,
}) => CoachInsightRow(
  isoYear: 2026,
  isoWeek: 42,
  kind: kind,
  payloadJson: payloadJson,
  generatedAt: DateTime(2026, 10, 12),
);

Future<void> _pumpCard(
  WidgetTester tester, {
  required DateTime now,
  CoachIntentRow? intent,
  CoachReviewRow? review,
  List<SwapSuggestion> suggestions = const [],
  List<CoachInsightRow> insights = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWith(() => FakeClock(now)),
        todayIntentProvider.overrideWith((ref) => Stream.value(intent)),
        todayReviewProvider.overrideWith((ref) => Stream.value(review)),
        suggestionsProvider.overrideWithValue(AsyncValue.data(suggestions)),
        weekInsightsProvider.overrideWith((ref) => Stream.value(insights)),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: CoachCard()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpHub(
  WidgetTester tester, {
  required DateTime now,
  CoachIntentRow? intent,
  CoachReviewRow? review,
  List<SwapSuggestion> suggestions = const [],
  List<CoachInsightRow> insights = const [],
  Object? intentError,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWith(() => FakeClock(now)),
        if (intentError != null)
          todayIntentProvider.overrideWith(
            (ref) => Stream.error(intentError),
          )
        else
          todayIntentProvider.overrideWith((ref) => Stream.value(intent)),
        todayReviewProvider.overrideWith((ref) => Stream.value(review)),
        suggestionsProvider.overrideWithValue(AsyncValue.data(suggestions)),
        weekInsightsProvider.overrideWith((ref) => Stream.value(insights)),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const CoachScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'clock coach card shows set-intent CTA in the morning',
    (tester) async {
      await _pumpCard(tester, now: DateTime(2026, 10, 15, 8, 0));
      expect(find.text(Strings.coachSetIntent), findsOneWidget);
    },
  );

  testWidgets('coach card shows suggestions CTA when swaps are ready', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      now: DateTime(2026, 10, 15, 14, 0),
      intent: _intentRow(DateTime(2026, 10, 15), 'Finish draft'),
      suggestions: const [_suggestion],
    );
    expect(find.text(Strings.coachPlanDay), findsOneWidget);
  });

  testWidgets('coach card shows review CTA in the evening', (tester) async {
    await _pumpCard(
      tester,
      now: DateTime(2026, 10, 15, 19, 0),
      intent: _intentRow(DateTime(2026, 10, 15), 'Finish draft'),
    );
    expect(find.text(Strings.coachReviewTitle), findsOneWidget);
  });

  testWidgets('coach card tap opens the hub', (tester) async {
    await _pumpCard(tester, now: DateTime(2026, 10, 15, 8, 0));
    await tester.tap(find.byType(CoachCard));
    await tester.pumpAndSettle();
    expect(find.byType(CoachScreen), findsOneWidget);
  });

  testWidgets('hub shows intent, suggestions and insights sections', (
    tester,
  ) async {
    final insight = const CoachInsight(
      kind: 'peak-hours',
      title: 'Your peak holds',
      body: 'Protect the morning block.',
      evidence: '120 focus minutes over 28d',
    );
    await _pumpHub(
      tester,
      now: DateTime(2026, 10, 15, 10, 0),
      intent: _intentRow(DateTime(2026, 10, 15), 'Finish draft'),
      review: _reviewRow(DateTime(2026, 10, 15)),
      suggestions: const [_suggestion],
      insights: [
        _insightRow(
          kind: 'peak-hours',
          payloadJson: jsonEncode(insight.toJson()),
        ),
      ],
    );
    expect(find.text('Finish draft'), findsOneWidget);
    expect(find.text(Strings.coachPlanDay), findsWidgets);
    expect(find.text('Your peak holds'), findsOneWidget);
  });

  testWidgets('hub shows load error with retry', (tester) async {
    await _pumpHub(
      tester,
      now: DateTime(2026, 10, 15, 10, 0),
      intentError: StateError('boom'),
    );
    expect(find.text(Strings.coachLoadError), findsOneWidget);
    expect(find.text(Strings.deckRetry), findsOneWidget);
    await tester.tap(find.text(Strings.deckRetry));
    await tester.pump();
  });

  testWidgets('hub skips corrupt insight JSON without crashing', (
    tester,
  ) async {
    final valid = const CoachInsight(
      kind: 'peak-hours',
      title: 'Your peak holds',
      body: 'Protect the morning block.',
      evidence: '120 focus minutes over 28d',
    );
    await _pumpHub(
      tester,
      now: DateTime(2026, 10, 15, 10, 0),
      insights: [
        _insightRow(kind: 'broken', payloadJson: 'not-json{{{'),
        _insightRow(
          kind: 'peak-hours',
          payloadJson: jsonEncode(valid.toJson()),
        ),
      ],
    );
    expect(find.text('Your peak holds'), findsOneWidget);
  });

  testWidgets('insight card renders title, body, evidence and kind', (
    tester,
  ) async {
    const insight = CoachInsight(
      kind: 'peak-hours',
      title: 'Your peak holds',
      body: 'Protect the morning block.',
      evidence: '120 focus minutes over 28d',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: InsightCard(insight: insight)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your peak holds'), findsOneWidget);
    expect(find.text('Protect the morning block.'), findsOneWidget);
    expect(find.text('120 focus minutes over 28d'), findsOneWidget);
    expect(find.text('peak-hours'), findsOneWidget);
  });

  testWidgets('teaser shows intent goal and fires onOpen', (tester) async {
    final day = DateTime(2026, 10, 15);
    var opened = false;
    final fake = _FakeCoachRepository(
      intent: _intentRow(day, 'Finish draft'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coachRepositoryProvider.overrideWithValue(fake),
          clockProvider.overrideWith(
            () => FakeClock(DateTime(2026, 10, 15, 10, 0)),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: CoachTeaserCard(onOpen: () => opened = true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Finish draft'), findsOneWidget);
    await tester.tap(find.byType(CoachTeaserCard));
    await tester.pump();
    expect(opened, isTrue);
  });

  testWidgets('teaser shows set-intent CTA when empty', (tester) async {
    final fake = _FakeCoachRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coachRepositoryProvider.overrideWithValue(fake),
          clockProvider.overrideWith(
            () => FakeClock(DateTime(2026, 10, 15, 10, 0)),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: CoachTeaserCard(onOpen: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(Strings.coachSetIntent), findsOneWidget);
  });
}
