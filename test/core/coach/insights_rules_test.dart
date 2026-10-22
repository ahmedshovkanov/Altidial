// test/core/coach/insights_rules_test.dart
import 'package:altidial/core/coach/insights_rules.dart';
import 'package:altidial/data/repositories/stats_repository.dart';
import 'package:flutter_test/flutter_test.dart';

StatsSnapshot empty() => const StatsSnapshot.empty();

StatsSnapshot focusWindow({required int ended, required int minutes}) =>
    StatsSnapshot(
      toneByDay: const [],
      plannedByTone: const [],
      focus: FocusDepth(
        minutes: minutes,
        longestSeconds: minutes * 60,
        averageSeconds: minutes > 0 && ended > 0 ? (minutes * 60 ~/ ended) : 0,
        ended: ended,
        abandoned: 0,
      ),
      focusInstants: const [],
    );

CoachInsightInput base({
  StatsSnapshot? window,
  Map<DateTime, int>? plannedByDay,
  int currentStreak = 0,
  int focusTargetMinutes = 180,
  int endedSessions = 0,
  int abandonedAfter16 = 0,
  int inboxAfter16 = 0,
  Map<String, int>? toneShare,
  bool streakRisk = false,
  List<int>? weeklyFocusMinutes,
  int projectActualMinutes = 0,
}) => CoachInsightInput(
  window28d: window ?? empty(),
  plannedByDay: plannedByDay ?? {},
  currentStreak: currentStreak,
  focusTargetMinutes: focusTargetMinutes,
  endedSessions: endedSessions,
  abandonedAfter16: abandonedAfter16,
  inboxAfter16: inboxAfter16,
  toneShare: toneShare ?? {},
  streakRisk: streakRisk,
  weeklyFocusMinutes: weeklyFocusMinutes ?? [],
  projectActualMinutes: projectActualMinutes,
);

void main() {
  test('empty window yields no insights, never fake numbers', () {
    final cards = buildInsights(CoachInsightInput(
      window28d: empty(), plannedByDay: {}, currentStreak: 0,
      focusTargetMinutes: 180, endedSessions: 0, abandonedAfter16: 0,
      inboxAfter16: 0, toneShare: {}, streakRisk: false,
      weeklyFocusMinutes: [], projectActualMinutes: 0,
    ));
    expect(cards, isEmpty);
  });

  test('late-abandon rule fires with evidence', () {
    final cards = buildInsights(CoachInsightInput(
      window28d: empty(), plannedByDay: {}, currentStreak: 3,
      focusTargetMinutes: 180, endedSessions: 20, abandonedAfter16: 9,
      inboxAfter16: 20, toneShare: {}, streakRisk: false,
      weeklyFocusMinutes: [], projectActualMinutes: 0,
    ));
    expect(cards.map((c) => c.kind), contains('late-abandon'));
    expect(cards.firstWhere((c) => c.kind == 'late-abandon').evidence, contains('45%'));
  });

  group('peak-hours threshold', () {
    test('fires at exactly 5 ended', () {
      final cards = buildInsights(
        base(window: focusWindow(ended: 5, minutes: 120)),
      );
      expect(cards.map((c) => c.kind), contains('peak-hours'));
    });

    test('omitted at 4 ended', () {
      final cards = buildInsights(
        base(window: focusWindow(ended: 4, minutes: 120)),
      );
      expect(cards.map((c) => c.kind), isNot(contains('peak-hours')));
    });
  });

  group('balance-drift threshold', () {
    Map<DateTime, int> sevenDays() => {
      for (var d = 1; d <= 7; d++) DateTime(2026, 9, d): 60,
    };

    test('fires at exactly 70%', () {
      final cards = buildInsights(
        base(
          plannedByDay: sevenDays(),
          toneShare: {'Focus': 70, 'Life': 20, 'Inbox': 10},
        ),
      );
      expect(cards.map((c) => c.kind), contains('balance-drift'));
    });

    test('omitted at 69%', () {
      final cards = buildInsights(
        base(
          plannedByDay: sevenDays(),
          toneShare: {'Focus': 69, 'Life': 20, 'Inbox': 11},
        ),
      );
      expect(cards.map((c) => c.kind), isNot(contains('balance-drift')));
    });
  });

  group('streak-at-risk', () {
    test('omitted when streak is 0 even if at risk', () {
      final cards = buildInsights(
        base(currentStreak: 0, streakRisk: true),
      );
      expect(cards.map((c) => c.kind), isNot(contains('streak-at-risk')));
    });

    test('fires with a live streak at risk', () {
      final cards = buildInsights(
        base(currentStreak: 4, streakRisk: true),
      );
      expect(cards.map((c) => c.kind), contains('streak-at-risk'));
    });
  });

  group('target-hit-rate', () {
    test('fires with 2 weeks of data', () {
      final cards = buildInsights(
        base(weeklyFocusMinutes: [180, 90], focusTargetMinutes: 180),
      );
      expect(cards.map((c) => c.kind), contains('target-hit-rate'));
      expect(
        cards
            .firstWhere((c) => c.kind == 'target-hit-rate')
            .evidence,
        contains('1 of 2 weeks'),
      );
    });

    test('omitted with fewer than 2 weeks', () {
      final cards = buildInsights(base(weeklyFocusMinutes: [200]));
      expect(cards.map((c) => c.kind), isNot(contains('target-hit-rate')));
    });
  });

  group('project-velocity', () {
    test('omitted at 0 project minutes', () {
      final cards = buildInsights(base(projectActualMinutes: 0));
      expect(cards.map((c) => c.kind), isNot(contains('project-velocity')));
    });

    test('fires with any project minutes', () {
      final cards = buildInsights(base(projectActualMinutes: 45));
      expect(cards.map((c) => c.kind), contains('project-velocity'));
    });
  });
}
