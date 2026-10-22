// lib/core/coach/insights_rules.dart
import 'package:altidial/data/repositories/stats_repository.dart';

class CoachInsightInput {
  const CoachInsightInput({
    required this.window28d,
    required this.plannedByDay,
    required this.currentStreak,
    required this.focusTargetMinutes,
    required this.endedSessions,
    required this.abandonedAfter16,
    required this.inboxAfter16,
    required this.toneShare,
    required this.streakRisk,
    required this.weeklyFocusMinutes,
    required this.projectActualMinutes,
  });
  final StatsSnapshot window28d;
  final Map<DateTime, int> plannedByDay;
  final int currentStreak;
  final int focusTargetMinutes;
  final int endedSessions;
  final int abandonedAfter16;
  final int inboxAfter16;
  final Map<String, int> toneShare;
  final bool streakRisk;
  final List<int> weeklyFocusMinutes;
  final int projectActualMinutes;
}

class CoachInsight {
  const CoachInsight({required this.kind, required this.title, required this.body, required this.evidence});
  final String kind;
  final String title;
  final String body;
  final String evidence;
  Map<String, Object?> toJson() => {'kind': kind, 'title': title, 'body': body, 'evidence': evidence};
  static CoachInsight fromJson(Map<String, Object?> json) => CoachInsight(
    kind: json['kind'] as String, title: json['title'] as String,
    body: json['body'] as String, evidence: json['evidence'] as String,
  );
}

/// Pure. Each rule declares minData; below it the rule is omitted.
List<CoachInsight> buildInsights(CoachInsightInput input) {
  final out = <CoachInsight>[];
  // late-abandon: min 10 ended sessions.
  if (input.endedSessions >= 10 && input.inboxAfter16 > 0) {
    final pct = (input.abandonedAfter16 * 100 / input.inboxAfter16).round();
    if (pct >= 30) {
      out.add(CoachInsight(
        kind: 'late-abandon',
        title: 'Afternoons cost you',
        body: 'Inbox work scheduled after 16:00 gets abandoned far more often.',
        evidence: '$pct% of Inbox abandoned after 16:00 over last 28d (${input.abandonedAfter16} of ${input.inboxAfter16})',
      ));
    }
  }
  // peak-hours: min 5 ended focus sessions.
  final focus = input.window28d.focus;
  if (focus.ended >= 5 && focus.minutes > 0) {
    out.add(CoachInsight(
      kind: 'peak-hours',
      title: 'Your peak holds',
      body: 'Protect the morning block — most focus lands there.',
      evidence: '${focus.minutes} focus minutes, longest ${focus.longestSeconds ~/ 60}m over 28d',
    ));
  }
  // balance-drift: min 7 planned days.
  if (input.plannedByDay.length >= 7) {
    final total = input.toneShare.values.fold(0, (a, b) => a + b);
    if (total > 0) {
      final top = input.toneShare.values.reduce((a, b) => a > b ? a : b) * 100 ~/ total;
      if (top >= 70) {
        out.add(CoachInsight(
          kind: 'balance-drift',
          title: 'One tone is eating the month',
          body: 'A single tone above 70% drags your energy score balance component.',
          evidence: 'Top tone $top% of planned minutes over 28d',
        ));
      }
    }
  }
  // streak-at-risk: needs a live streak.
  if (input.streakRisk && input.currentStreak > 0) {
    out.add(CoachInsight(
      kind: 'streak-at-risk',
      title: 'Streak needs one session',
      body: 'No completed session today yet — a short focus block keeps it alive.',
      evidence: '${input.currentStreak}-day streak at risk today',
    ));
  }
  // target-hit-rate: min 7 planned days.
  if (input.weeklyFocusMinutes.length >= 2) {
    final hits = input.weeklyFocusMinutes.where((m) => m >= input.focusTargetMinutes).length;
    out.add(CoachInsight(
      kind: 'target-hit-rate',
      title: 'Target discipline',
      body: 'How often weekly focus clears your daily target pace.',
      evidence: '$hits of ${input.weeklyFocusMinutes.length} weeks hit ${input.focusTargetMinutes}m pace',
    ));
  }
  // project-velocity: any project minutes.
  if (input.projectActualMinutes > 0) {
    out.add(CoachInsight(
      kind: 'project-velocity',
      title: 'Projects are moving',
      body: 'Linked sessions are turning plans into progress.',
      evidence: '${input.projectActualMinutes} project minutes over 28d',
    ));
  }
  return out;
}
