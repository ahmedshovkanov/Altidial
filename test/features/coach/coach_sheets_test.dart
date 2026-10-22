import 'package:energy_clock/app/theme/app_theme.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/providers.dart';
import 'package:energy_clock/data/repositories/coach_repository.dart';
import 'package:energy_clock/features/clock/providers.dart';
import 'package:energy_clock/features/coach/widgets/intent_sheet.dart';
import 'package:energy_clock/features/coach/widgets/review_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';

class _FakeCoachRepository implements CoachRepository {
  DateTime? lastIntentDay;
  String? lastFocusGoal;
  int? lastPredictedEnergy;
  DateTime? lastReviewDay;
  int? lastEnergy;
  String? lastWinText;
  bool failNextSave = false;

  @override
  Stream<CoachIntentRow?> watchIntent(DateTime day) => Stream.value(null);

  @override
  Future<void> saveIntent({
    required DateTime day,
    required String focusGoal,
    int? predictedEnergy,
  }) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('save failed');
    }
    lastIntentDay = day;
    lastFocusGoal = focusGoal;
    lastPredictedEnergy = predictedEnergy;
  }

  @override
  Stream<CoachReviewRow?> watchReview(DateTime day) => Stream.value(null);

  @override
  Future<void> saveReview({
    required DateTime day,
    required int energy,
    String? winText,
  }) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('save failed');
    }
    lastReviewDay = day;
    lastEnergy = energy;
    lastWinText = winText;
  }

  @override
  Stream<List<CoachInsightRow>> watchWeekInsights(int isoYear, int isoWeek) =>
      Stream.value(const []);

  @override
  Future<void> ensureWeek(int isoYear, int isoWeek) async {}
}

Future<void> _pumpSheet(
  WidgetTester tester,
  Widget sheet, {
  required DateTime now,
  _FakeCoachRepository? fake,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coachRepositoryProvider.overrideWithValue(
          fake ?? _FakeCoachRepository(),
        ),
        clockProvider.overrideWith(() => FakeClock(now)),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: sheet),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

FilledButton _saveButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.widgetWithText(FilledButton, Strings.save),
);

void main() {
  group('validateFocusGoal', () {
    test('rejects empty and overlong, accepts valid', () {
      expect(validateFocusGoal('   '), Strings.coachFocusError);
      expect(validateFocusGoal('x' * 121), Strings.coachFocusError);
      expect(validateFocusGoal('Finish portfolio draft'), isNull);
    });
  });

  group('validateWinText', () {
    test('allows empty, rejects overlong', () {
      expect(validateWinText(null), isNull);
      expect(validateWinText('   '), isNull);
      expect(validateWinText('Shipped the draft'), isNull);
      expect(validateWinText('x' * 141), Strings.coachWinHint);
    });
  });

  testWidgets('intent sheet disables Save until the goal is valid', (
    tester,
  ) async {
    final day = DateTime(2026, 10, 12);
    await _pumpSheet(
      tester,
      IntentSheet(day: day),
      now: DateTime(2026, 10, 12, 10, 30),
    );

    expect(find.text(Strings.coachSetIntent), findsOneWidget);
    // Empty goal: inline error visible, Save disabled.
    expect(find.text(Strings.coachFocusError), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Finish portfolio draft');
    await tester.pump();
    expect(find.text(Strings.coachFocusError), findsNothing);
    expect(_saveButton(tester).onPressed, isNotNull);

    await tester.enterText(find.byType(TextField), 'x' * 121);
    await tester.pump();
    expect(find.text(Strings.coachFocusError), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNull);
  });

  testWidgets('intent sheet saves the trimmed goal via the repository', (
    tester,
  ) async {
    final fake = _FakeCoachRepository();
    final day = DateTime(2026, 10, 12);
    await _pumpSheet(
      tester,
      IntentSheet(day: day),
      now: DateTime(2026, 10, 12, 10, 30),
      fake: fake,
    );

    await tester.enterText(find.byType(TextField), '  Finish portfolio draft ');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, Strings.save));
    await tester.pumpAndSettle();

    expect(fake.lastIntentDay, day);
    expect(fake.lastFocusGoal, 'Finish portfolio draft');
  });

  testWidgets('intent sheet shows a SnackBar when saving fails', (
    tester,
  ) async {
    final fake = _FakeCoachRepository()..failNextSave = true;
    await _pumpSheet(
      tester,
      IntentSheet(day: DateTime(2026, 10, 12)),
      now: DateTime(2026, 10, 12, 10, 30),
      fake: fake,
    );

    await tester.enterText(find.byType(TextField), 'Finish portfolio draft');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, Strings.save));
    await tester.pumpAndSettle();

    expect(find.text(Strings.coachSaveFailed), findsOneWidget);
    expect(fake.lastFocusGoal, isNull);
  });

  testWidgets('review sheet requires an energy pick before saving', (
    tester,
  ) async {
    final fake = _FakeCoachRepository();
    final day = DateTime(2026, 10, 12);
    await _pumpSheet(
      tester,
      ReviewSheet(day: day),
      now: DateTime(2026, 10, 12, 10, 30),
      fake: fake,
    );

    expect(find.text(Strings.coachReviewTitle), findsOneWidget);
    expect(find.text(Strings.coachEnergyError), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNull);

    await tester.tap(find.bySemanticsLabel('Energy 3 of 5'));
    await tester.pump();
    expect(find.text(Strings.coachEnergyError), findsNothing);
    expect(_saveButton(tester).onPressed, isNotNull);

    await tester.enterText(find.byType(TextField), 'Shipped the draft');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, Strings.save));
    await tester.pumpAndSettle();

    expect(fake.lastReviewDay, day);
    expect(fake.lastEnergy, 3);
    expect(fake.lastWinText, 'Shipped the draft');
  });

  testWidgets('review sheet rejects an overlong win', (tester) async {
    await _pumpSheet(
      tester,
      ReviewSheet(day: DateTime(2026, 10, 12)),
      now: DateTime(2026, 10, 12, 10, 30),
    );

    await tester.tap(find.bySemanticsLabel('Energy 5 of 5'));
    await tester.pump();
    expect(find.text(Strings.coachWinHint).evaluate().length, 1);

    await tester.enterText(find.byType(TextField), 'x' * 141);
    await tester.pump();

    // The validator reuses the hint string as the overlong error (verbatim
    // per the brief), so hint + error render the same text twice.
    expect(find.text(Strings.coachWinHint).evaluate().length, 2);
    expect(_saveButton(tester).onPressed, isNull);
  });

  testWidgets('past-day sheets are read-only', (tester) async {
    await _pumpSheet(
      tester,
      IntentSheet(day: DateTime(2026, 10, 12)),
      now: DateTime(2026, 10, 13, 10, 30),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.readOnly, isTrue);
    expect(_saveButton(tester).onPressed, isNull);
  });
}
