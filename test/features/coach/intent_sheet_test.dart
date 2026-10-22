import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/coach/coach_screen.dart';
import 'package:energy_clock/features/coach/providers.dart';
import 'package:energy_clock/features/coach/widgets/intent_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_coach_repository.dart';

final _day = DateTime(2026, 10, 12);

Future<void> _pumpIntentSheet(
  WidgetTester tester, {
  required FakeCoachRepository fake,
  required DateTime now,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coachRepositoryProvider.overrideWithValue(fake),
        clockProvider.overrideWith(() => FakeClock(now)),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: IntentSheet(day: _day)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('intent sheet saves prediction', (tester) async {
    final fake = FakeCoachRepository();
    addTearDown(fake.dispose);
    await _pumpIntentSheet(
      tester,
      fake: fake,
      now: DateTime(2026, 10, 12, 10, 30),
    );

    await tester.enterText(find.byType(TextField), 'Finish draft');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Predicted energy 4 of 5'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(fake.lastFocusGoal, 'Finish draft');
    expect(fake.lastPredictedEnergy, 4);
  });

  testWidgets('tapping selected prediction dot clears to null', (
    tester,
  ) async {
    final fake = FakeCoachRepository();
    addTearDown(fake.dispose);
    await _pumpIntentSheet(
      tester,
      fake: fake,
      now: DateTime(2026, 10, 12, 10, 30),
    );

    await tester.enterText(find.byType(TextField), 'Finish draft');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Predicted energy 4 of 5'));
    await tester.pump();
    // Tapping the selected dot again clears the optional prediction.
    await tester.tap(find.bySemanticsLabel('Predicted energy 4 of 5'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(fake.lastFocusGoal, 'Finish draft');
    expect(fake.lastPredictedEnergy, isNull);
  });

  testWidgets('past-day intent sheet disables prediction dots', (
    tester,
  ) async {
    final fake = FakeCoachRepository();
    addTearDown(fake.dispose);
    await _pumpIntentSheet(
      tester,
      fake: fake,
      now: DateTime(2026, 10, 13, 10, 30),
    );

    expect(find.bySemanticsLabel('Predicted energy 4 of 5'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Predicted energy 4 of 5'));
    await tester.pump();

    // Read-only: Save stays disabled and nothing is saved.
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, Strings.save),
    );
    expect(save.onPressed, isNull);
    expect(fake.lastPredictedEnergy, isNull);
  });

  testWidgets('hub shows prediction line when intent has predictedEnergy', (
    tester,
  ) async {
    final day = DateTime(2026, 10, 15);
    final intent = CoachIntentRow(
      date: day,
      focusGoal: 'Finish draft',
      predictedEnergy: 4,
      createdAt: day,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWith(
            () => FakeClock(DateTime(2026, 10, 15, 10, 0)),
          ),
          todayIntentProvider.overrideWith((ref) => Stream.value(intent)),
          todayReviewProvider.overrideWith((ref) => Stream.value(null)),
          suggestionsProvider.overrideWithValue(
            const AsyncValue.data([]),
          ),
          weekInsightsProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const CoachScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('${Strings.predictedEnergyLabel} 4/5'),
      findsOneWidget,
    );
  });

  testWidgets('hub hides prediction line when predictedEnergy is null', (
    tester,
  ) async {
    final day = DateTime(2026, 10, 15);
    final intent = CoachIntentRow(
      date: day,
      focusGoal: 'Finish draft',
      createdAt: day,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWith(
            () => FakeClock(DateTime(2026, 10, 15, 10, 0)),
          ),
          todayIntentProvider.overrideWith((ref) => Stream.value(intent)),
          todayReviewProvider.overrideWith((ref) => Stream.value(null)),
          suggestionsProvider.overrideWithValue(
            const AsyncValue.data([]),
          ),
          weekInsightsProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const CoachScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Finish draft'), findsOneWidget);
    expect(
      find.text('${Strings.predictedEnergyLabel} 4/5'),
      findsNothing,
    );
  });
}
