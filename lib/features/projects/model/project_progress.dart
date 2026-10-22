// lib/features/projects/model/project_progress.dart
import 'package:energy_clock/core/strings.dart';
import 'package:energy_clock/data/database.dart'
    show ProjectRow, SessionRow;

abstract final class ProjectProgress {
  /// 0.0+ (may exceed 1.0; callers render overflow). Target mode wins when set.
  static double compute({required int plannedMinutes, required int actualMinutes, required int? targetMinutes}) {
    if (targetMinutes != null && targetMinutes > 0) return actualMinutes / targetMinutes;
    if (plannedMinutes <= 0) return 0.0;
    return actualMinutes / plannedMinutes;
  }

  static bool isReadyToComplete(double progress) => progress >= 1.0;

  static bool isOverdue(DateTime? deadline, DateTime now) =>
      deadline != null && _day(deadline).isBefore(_day(now));

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}

/// 'Due Fri' / 'Due in 3d' / 'Overdue 3d' / '' when null. Pure of now for tests.
/// Copy lives in [Strings] (`deadline*` keys); this stays a pure function.
String deadlineLabel(DateTime? deadline, DateTime now) {
  if (deadline == null) return '';
  final a = DateTime(now.year, now.month, now.day);
  final b = DateTime(deadline.year, deadline.month, deadline.day);
  final diff = b.difference(a).inDays;
  if (diff < 0) return Strings.deadlineOverdueDays(-diff);
  if (diff == 0) return Strings.deadlineToday;
  if (diff <= 7) return Strings.deadlineInDays(diff);
  return Strings.deadlineWeekday(
    Strings.deadlineWeekdays[(b.weekday - 1) % 7],
  );
}

/// Hub "worked" label for [when]: '' when never, 'today' / 'yesterday' /
/// 'Nd ago' otherwise (copy in [Strings]). Future stamps read as today.
String relativeDayLabel(DateTime? when, DateTime now) {
  if (when == null) return '';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(when.year, when.month, when.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return Strings.projectsWorkedToday;
  if (diff == 1) return Strings.projectsWorkedYesterday;
  return Strings.projectsWorkedDaysAgo(diff);
}

String? validateProjectTitle(String value) {
  final v = value.trim();
  if (v.isEmpty) return Strings.projectNameRequired;
  if (v.length > 80) return Strings.projectNameTooLong;
  return null;
}

String? validateTargetMinutes(int? value) {
  if (value == null) return null;
  if (value < 15) return Strings.projectTargetMin;
  if (value > 600000) return Strings.projectTargetMax;
  return null;
}

String? validateNotes(String value) {
  if (value.length > 500) return Strings.projectNotesTooLong;
  return null;
}

/// Null means no priority set (valid); otherwise 0–3, matching the
/// `updatePriority` clamp in `ProjectDao`.
String? validatePriority(int? value) {
  if (value == null) return null;
  if (value < 0 || value > 3) return Strings.projectPriorityRange;
  return null;
}

/// Done-minutes per calendar day for the last 7 days, oldest first, ending
/// with today. Per-day seconds are summed then truncated (`~/ 60`), the same
/// rule the project detail uses for totals. The day comes from
/// `endedAt ?? startedAt`; sessions outside the window are ignored.
///
/// [doneSessions] must already be filtered to done outcomes — the caller
/// excludes abandoned and running sessions (which carry no meaningful
/// minutes). Never stored, like the energy score.
List<int> velocityLast7Days({
  required List<SessionRow> doneSessions,
  required DateTime now,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final secondsPerDay = List<int>.filled(7, 0);
  for (final session in doneSessions) {
    final stamp = session.endedAt ?? session.startedAt;
    final day = DateTime(stamp.year, stamp.month, stamp.day);
    final offset = day.difference(today).inDays;
    if (offset < -6 || offset > 0) continue;
    secondsPerDay[offset + 6] += session.activeSeconds;
  }
  return [for (final seconds in secondsPerDay) seconds ~/ 60];
}

/// Pixel height for one velocity bar: [minutes] scaled against the week's
/// [maxMinutes], sitting at [minHeight] when the day is empty. Guards an
/// all-zero week (`maxMinutes == 0`) so the result is never NaN.
double velocityBarHeight({
  required int minutes,
  required int maxMinutes,
  double minHeight = 4,
  double maxHeight = 64,
}) {
  if (maxMinutes <= 0) return minHeight;
  final ratio = (minutes / maxMinutes).clamp(0.0, 1.0);
  return minHeight + ratio * (maxHeight - minHeight);
}

/// Case-insensitive title order, stable on id. Shared tiebreak for the
/// comparators below.
int _compareProjectTitle(ProjectRow a, ProjectRow b) {
  final byTitle =
      a.title.toLowerCase().compareTo(b.title.toLowerCase());
  return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
}

/// Earliest deadline first; projects without a deadline sort last.
int compareByDeadline(ProjectRow a, ProjectRow b) {
  final deadlineA = a.deadline;
  final deadlineB = b.deadline;
  if (deadlineA == null && deadlineB == null) {
    return _compareProjectTitle(a, b);
  }
  if (deadlineA == null) return 1;
  if (deadlineB == null) return -1;
  final byDate = deadlineA.compareTo(deadlineB);
  return byDate != 0 ? byDate : _compareProjectTitle(a, b);
}

int compareByTitle(ProjectRow a, ProjectRow b) =>
    _compareProjectTitle(a, b);

/// Highest progress first. Progress itself is computed by the caller with
/// [ProjectProgress.compute] (it needs each detail's planned/actual minutes
/// plus the row's target); ties fall back to title.
int compareByProgress(
  ProjectRow a,
  ProjectRow b,
  double progressA,
  double progressB,
) {
  final byProgress = progressB.compareTo(progressA);
  return byProgress != 0 ? byProgress : _compareProjectTitle(a, b);
}

/// Most recently worked first; projects never worked sort last. The caller
/// passes each row's `ProjectDetail.lastWorkedAt`; ties fall back to title.
int compareByRecent(
  ProjectRow a,
  ProjectRow b,
  DateTime? lastWorkedAtA,
  DateTime? lastWorkedAtB,
) {
  if (lastWorkedAtA == null && lastWorkedAtB == null) {
    return _compareProjectTitle(a, b);
  }
  if (lastWorkedAtA == null) return 1;
  if (lastWorkedAtB == null) return -1;
  final byRecent = lastWorkedAtB.compareTo(lastWorkedAtA);
  return byRecent != 0 ? byRecent : _compareProjectTitle(a, b);
}
