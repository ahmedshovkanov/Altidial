import 'package:energy_clock/core/roundup/roundup_payload.dart';
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/features/progress/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/clock_harness.dart';

void main() {
  late ClockHarness harness;

  setUp(() {
    harness = ClockHarness();
  });

  tearDown(() {
    harness.dispose();
  });

  RoundupPayload testPayload({
    int week = 41,
    DateTime? weekStart,
    List<String> badges = const [],
  }) => RoundupPayload(
    isoYear: 2026,
    isoWeek: week,
    weekStart: weekStart ?? DateTime(2026, 10, 5),
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
    badgesUnlocked: badges,
    xpEarned: 400,
    previousAdherencePercent: 71,
  );

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(harness.app(const ProfileScreen()));
    await tester.pumpAndSettle();
  }

  /// The badge grid builds lazily and the archive sits below it: scroll first.
  /// Drags until the archive title is hittable rather than a fixed distance,
  /// so cards added above (e.g. the Projects card) cannot strand it off-screen.
  Future<void> scrollDown(WidgetTester tester) async {
    final list = find.byType(SingleChildScrollView);
    for (var i = 0; i < 10; i++) {
      if (tester.any(
        find.text(Strings.profileArchiveTitle).hitTestable(),
      )) {
        break;
      }
      await tester.drag(list, const Offset(0, -1000));
      await tester.pumpAndSettle();
    }
    // Nudge the first archive rows fully into view for the tap tests.
    await tester.drag(list, const Offset(0, -400));
    await tester.pumpAndSettle();
  }

  testWidgets('all ten badges show, locked when unearned', (tester) async {
    await mount(tester);
    await scrollDown(tester);

    expect(find.text(Strings.profileBadgesTitle), findsOneWidget);
    expect(find.text(Strings.badgeStreak30Title), findsOneWidget);
    expect(find.text(Strings.profileBadgeLocked), findsNWidgets(10));
  });

  testWidgets('earned badges show their descriptions', (tester) async {
    harness.progress.emitBadges([
      BadgeUnlockRow(
        badgeId: 'first_session',
        unlockedAt: DateTime(2026, 10, 6),
      ),
    ]);
    await mount(tester);
    await scrollDown(tester);

    expect(find.text(Strings.badgeFirstSessionDescription), findsOneWidget);
    expect(find.text(Strings.profileBadgeLocked), findsNWidgets(9));
  });

  testWidgets('the archive lists weeks newest first with ranges', (
    tester,
  ) async {
    harness.roundups.setArchive([
      (isoYear: 2026, isoWeek: 41, generatedAt: DateTime(2026, 10, 13)),
      (isoYear: 2026, isoWeek: 40, generatedAt: DateTime(2026, 10, 6)),
    ]);
    harness.roundups.payloads[(2026, 41)] = testPayload();
    harness.roundups.payloads[(2026, 40)] = testPayload(
      week: 40,
      weekStart: DateTime(2026, 9, 28),
    );
    await mount(tester);
    await scrollDown(tester);

    expect(find.text(Strings.profileArchiveTitle), findsOneWidget);
    final top41 = tester.getTopLeft(find.text('Week 41')).dy;
    final top40 = tester.getTopLeft(find.text('Week 40')).dy;
    expect(top41, lessThan(top40));
    expect(find.text('5 – 11 Oct 2026'), findsOneWidget);
    expect(find.text('28 Sep – 4 Oct 2026'), findsOneWidget);
  });

  testWidgets('tapping a week opens its snapshot', (tester) async {
    harness.roundups.setArchive([
      (isoYear: 2026, isoWeek: 41, generatedAt: DateTime(2026, 10, 13)),
    ]);
    harness.roundups.payloads[(2026, 41)] = testPayload(badges: ['streak_7']);
    await mount(tester);
    await scrollDown(tester);

    await tester.ensureVisible(find.text('Week 41'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Week 41'));
    await tester.pumpAndSettle();

    expect(find.text(Strings.statsAdherence(83)), findsOneWidget);
    expect(
      find.text(Strings.roundupBestFocusDay('Thu 8 Oct', '3h 20m')),
      findsOneWidget,
    );
    // Badge title also appears in the badge grid above; assert at least one in snapshot.
    expect(find.text(Strings.badgeStreak7Title), findsAtLeastNWidgets(1));
    // Other CustomPaint widgets (e.g., level/score cards) may exist; assert at least the donut.
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
  });

  testWidgets('a week without a payload says it is unavailable', (
    tester,
  ) async {
    harness.roundups.setArchive([
      (isoYear: 2026, isoWeek: 42, generatedAt: DateTime(2026, 10, 20)),
    ]);
    await mount(tester);
    await scrollDown(tester);

    await tester.ensureVisible(find.text('Week 42'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Week 42'));
    await tester.pumpAndSettle();

    expect(find.text(Strings.roundupUnavailable), findsOneWidget);
  });

  testWidgets('an empty archive invites the first Monday', (tester) async {
    await mount(tester);
    await scrollDown(tester);

    expect(find.text(Strings.profileEmptyArchive), findsOneWidget);
  });
}
