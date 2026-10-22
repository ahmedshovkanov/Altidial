// Golden images of the Profile tab, with the floating tab bar: an iPhone in
// light and dark, and an iPad in landscape, all with a streak, a score, three
// badges and two archived weeks. Animations are off, and
// `test/flutter_test_config.dart` loads Nunito, so every image is
// deterministic and shows real text.
import 'package:altidial/app/navigation/tab_scaffold.dart';
import 'package:altidial/app/theme/app_theme.dart';
import 'package:altidial/core/roundup/roundup_payload.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';
import '../../support/fake_coach_repository.dart';

const screenKey = ValueKey('profile-screen-golden');

void main() {
  late ClockHarness harness;
  late FakeCoachRepository coach;

  setUp(() {
    // Empty coach state: the teaser shows its set-intent CTA without ever
    // touching the real database (which has no plugin implementation in
    // widget tests and would throw MissingPluginException asynchronously).
    coach = FakeCoachRepository();
    harness = ClockHarness(
      overrides: [
        coachRepositoryProvider.overrideWithValue(coach),
        // ClockTab (index 0, built at startup) watches this; the real
        // scheduler opens the on-device database, which has no plugin
        // implementation in widget tests. No UI reads it.
        foregroundRefreshProvider.overrideWith((ref) {}),
      ],
    );
    final today = startOfDay(DateTime.now());
    harness.progress.setProgress(
      ProgressRow(
        id: 1,
        xp: 250,
        level: 2,
        currentStreak: 6,
        longestStreak: 14,
        lastStreakDate: today,
      ),
    );
    harness.progress.setScore(
      today,
      DayScoreRow(
        date: today,
        energyScore: 88,
        adherencePoints: 45,
        focusPoints: 23,
        balancePoints: 20,
        focusMinutes: 140,
        lifeMinutes: 45,
        inboxMinutes: 30,
        plannedMinutes: 300,
        completedMinutes: 215,
        computedAt: DateTime.now(),
      ),
    );
    harness.progress.emitBadges([
      BadgeUnlockRow(
        badgeId: 'first_session',
        unlockedAt: DateTime(2026, 9, 30),
      ),
      BadgeUnlockRow(badgeId: 'streak_7', unlockedAt: DateTime(2026, 10, 6)),
      BadgeUnlockRow(badgeId: 'early_bird', unlockedAt: DateTime(2026, 10, 7)),
    ]);
    harness.roundups.setArchive([
      (isoYear: 2026, isoWeek: 41, generatedAt: DateTime(2026, 10, 13)),
      (isoYear: 2026, isoWeek: 40, generatedAt: DateTime(2026, 10, 6)),
    ]);
    RoundupPayload payload({required int week, required DateTime start}) =>
        RoundupPayload(
          isoYear: 2026,
          isoWeek: week,
          weekStart: start,
          adherencePercent: 83,
          plannedMinutes: 900,
          completedMinutes: 750,
          totalMinutes: 750,
          focusMinutes: 480,
          lifeMinutes: 180,
          inboxMinutes: 90,
          bestFocusDay: DateTime(2026, 10, 8),
          bestFocusMinutes: 200,
          currentStreak: 5,
          longestStreak: 9,
          badgesUnlocked: const ['streak_7'],
          xpEarned: 400,
          previousAdherencePercent: 71,
        );
    harness.roundups.payloads[(2026, 41)] = payload(
      week: 41,
      start: DateTime(2026, 10, 5),
    );
    harness.roundups.payloads[(2026, 40)] = payload(
      week: 40,
      start: DateTime(2026, 9, 28),
    );
  });

  tearDown(() {
    harness.dispose();
    coach.dispose();
  });

  Future<void> check(
    WidgetTester tester, {
    required Size size,
    required ThemeData theme,
    required String file,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: RepaintBoundary(
          key: screenKey,
          child: MaterialApp(
            theme: theme,
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const TabScaffold(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tab-3')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(screenKey),
      matchesGoldenFile('goldens/$file'),
    );
  }

  testWidgets('iPhone 17 Pro, light', (tester) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.light,
      file: 'profile_iphone_light.png',
    );
  });

  testWidgets('iPhone 17 Pro, dark', (tester) async {
    await check(
      tester,
      size: const Size(402, 874),
      theme: AppTheme.dark,
      file: 'profile_iphone_dark.png',
    );
  });

  testWidgets('iPad 11" landscape, light', (tester) async {
    await check(
      tester,
      size: const Size(1194, 834),
      theme: AppTheme.light,
      file: 'profile_ipad_landscape_light.png',
    );
  });
}
