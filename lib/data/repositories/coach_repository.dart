import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:altidial/core/coach/insights_rules.dart';
import 'package:altidial/core/event_status.dart';
import 'package:altidial/core/progress/score.dart';
import 'package:altidial/core/progress/streak.dart';
import 'package:altidial/core/roundup/iso_week.dart';
import 'package:altidial/core/session/session_outcome.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/core/tone.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/repositories/stats_repository.dart';

abstract interface class CoachRepository {
  Stream<CoachIntentRow?> watchIntent(DateTime day);
  Future<void> saveIntent({required DateTime day, required String focusGoal, int? predictedEnergy});
  Stream<CoachReviewRow?> watchReview(DateTime day);
  Future<void> saveReview({required DateTime day, required int energy, String? winText});
  Stream<List<CoachInsightRow>> watchWeekInsights(int isoYear, int isoWeek);
  Future<void> ensureWeek(int isoYear, int isoWeek);
}

class DriftCoachRepository implements CoachRepository {
  DriftCoachRepository(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  @override
  Stream<CoachIntentRow?> watchIntent(DateTime day) =>
      _db.coachDao.watchIntent(startOfDay(day));

  // Spec §1 + §2 (intent sheet top-3 chips): CoachIntents.topEventIds stays
  // unused in v1 — saveIntent intentionally omits it. Follow-up tracked in
  // .superpowers/sdd/2026-10-15-energy-coach/progress.md (wire topEventIds +
  // IntentSheet Focus top-3 chips).
  @override
  Future<void> saveIntent({required DateTime day, required String focusGoal, int? predictedEnergy}) {
    final v = focusGoal.trim();
    if (v.isEmpty || v.length > 120) throw ArgumentError('focusGoal 1-120 chars');
    if (predictedEnergy != null && (predictedEnergy < 1 || predictedEnergy > 5)) {
      throw ArgumentError('predictedEnergy 1-5 or null');
    }
    return _db.coachDao.upsertIntent(date: startOfDay(day), focusGoal: v, predictedEnergy: predictedEnergy);
  }

  @override
  Stream<CoachReviewRow?> watchReview(DateTime day) =>
      _db.coachDao.watchReview(startOfDay(day));

  @override
  Future<void> saveReview({required DateTime day, required int energy, String? winText}) {
    if (energy < 1 || energy > 5) throw ArgumentError('energy 1-5');
    final w = winText?.trim();
    if (w != null && w.length > 140) throw ArgumentError('winText max 140');
    return _db.coachDao.upsertReview(
      date: startOfDay(day), energy: energy,
      winText: (w == null || w.isEmpty) ? null : w,
    );
  }

  @override
  Stream<List<CoachInsightRow>> watchWeekInsights(int isoYear, int isoWeek) =>
      _db.coachDao.watchInsightsForWeek(isoYear, isoWeek);

  /// Builds and freezes the week's insight cards on first call; later calls
  /// re-read the frozen rows and never recompute. Follows
  /// `DriftRoundupRepository.ensureCurrent`/`_generate` verbatim: the ISO
  /// week start comes from `isoWeekStart`, the 28-day window is
  /// `[start-21d, start+7d)` clamped to the past, streaks fold through
  /// `qualifyingDates` + `streaks` as of the week's Sunday, and each card is
  /// stored via `coachDao.insertInsight` as `jsonEncode(card.toJson())`.
  /// Weeks with zero cards write nothing, so the feed shows
  /// `Strings.coachInsightsEmpty`. The current ISO week never generates
  /// before Sunday 18:00 local, when the week's data is still incomplete.
  @override
  Future<void> ensureWeek(int isoYear, int isoWeek) async {
    final now = _now();
    final start = isoWeekStart(isoYear, isoWeek);
    final current = isoWeekOf(now);
    if (current.year == isoYear && current.week == isoWeek) {
      final gate = DateTime(start.year, start.month, start.day + 6, 18);
      if (now.isBefore(gate)) return;
    }
    if ((await _db.coachDao.insightsForWeek(isoYear, isoWeek)).isNotEmpty) {
      return;
    }
    await _db.transaction(() async {
      await _generate(isoYear, isoWeek, start, now);
    });
  }

  Future<void> _generate(
    int isoYear,
    int isoWeek,
    DateTime start,
    DateTime now,
  ) async {
    final from = DateTime(start.year, start.month, start.day - 21);
    final end = DateTime(start.year, start.month, start.day + 7);
    final toExclusive = end.isAfter(now) ? now : end;
    if (!toExclusive.isAfter(from)) return;

    final cells = await _db.statsDao.toneSecondsByDay(from, toExclusive);
    final plannedTone = await _db.statsDao.plannedMinutesByTone(
      from,
      toExclusive,
    );
    final plannedDayRows = await _db.progressDao.plannedMinutesByDay(
      from,
      toExclusive,
    );
    final instants = await _db.statsDao.focusInstants(
      from,
      toExclusive,
      Tone.focus.dbIndex,
    );
    final outcomes = await _db.statsDao.focusOutcomeCounts(
      from,
      toExclusive,
      Tone.focus.dbIndex,
    );

    // Every session of the window with its event's tone: hours bucket in
    // Dart from `startedAt.hour` (same rationale as `buildHeatmap`, whose
    // database stores instants SQLite cannot bucket across timezones/DST),
    // and project minutes fold from the same rows.
    final sessionQuery = _db.select(_db.sessions).join([
      innerJoin(
        _db.events,
        _db.events.id.equalsExp(_db.sessions.eventId),
      ),
    ])..where(
      _db.events.date.isBiggerOrEqualValue(from) &
          _db.events.date.isSmallerThanValue(toExclusive),
    );
    final sessionRows = await sessionQuery.get();

    var endedSessions = 0;
    var inboxAfter16 = 0;
    var abandonedAfter16 = 0;
    var projectSeconds = 0;
    for (final row in sessionRows) {
      final session = row.readTable(_db.sessions);
      final event = row.readTable(_db.events);
      if (event.status == EventStatus.skipped.dbIndex) continue;
      if (session.outcome == SessionOutcome.running.dbIndex) continue;
      endedSessions++;
      if (event.toneIndex == Tone.inbox.dbIndex &&
          session.startedAt.hour >= 16) {
        inboxAfter16++;
        if (session.outcome == SessionOutcome.abandoned.dbIndex) {
          abandonedAfter16++;
        }
      }
      if (event.projectId != null &&
          (session.outcome == SessionOutcome.completed.dbIndex ||
              session.outcome == SessionOutcome.finishedEarly.dbIndex)) {
        projectSeconds += session.activeSeconds;
      }
    }

    // Streaks freeze as of the week's Sunday, verbatim roundup pattern.
    final sunday = DateTime(end.year, end.month, end.day - 1);
    final qualifying = (await _db.progressDao.qualifyingDates())
        .where((day) => !day.isAfter(sunday))
        .toList();
    final evaluated = streaks(qualifying, today: sunday);

    final toneByDay =
        <ToneDayMinutes>[
          for (final cell in cells)
            (
              date: cell.date,
              tone: Tone.fromDbIndex(cell.toneIndex),
              minutes: cell.seconds ~/ 60,
            ),
        ]..sort((a, b) {
          final days = a.date.compareTo(b.date);
          return days != 0 ? days : a.tone.dbIndex.compareTo(b.tone.dbIndex);
        });
    final plannedByToneIndex = <int, int>{
      for (final row in plannedTone) row.toneIndex: row.minutes,
    };
    final completedByTone = <Tone, int>{};
    for (final cell in toneByDay) {
      completedByTone[cell.tone] =
          (completedByTone[cell.tone] ?? 0) + cell.minutes;
    }
    final focusSeconds = instants.fold(
      0,
      (sum, instant) => sum + instant.activeSeconds,
    );

    final focusByDate = <DateTime, int>{};
    for (final cell in cells) {
      if (cell.toneIndex != Tone.focus.dbIndex) continue;
      focusByDate[cell.date] =
          (focusByDate[cell.date] ?? 0) + cell.seconds ~/ 60;
    }
    final windowDays = toExclusive.difference(from).inDays;
    final weekCount = (windowDays / 7).ceil();
    final weeklyFocusMinutes = List.filled(weekCount, 0);
    for (final entry in focusByDate.entries) {
      final index = entry.key.difference(from).inDays ~/ 7;
      if (index >= 0 && index < weekCount) {
        weeklyFocusMinutes[index] += entry.value;
      }
    }

    // The settings table's stored target, or the default. The key literal
    // stays here so `lib/data/` never imports `lib/app/`.
    final stored = int.tryParse(
      await _db.settingsDao.valueFor('daily_focus_target') ?? '',
    );

    final cards = buildInsights(
      CoachInsightInput(
        window28d: StatsSnapshot(
          toneByDay: toneByDay,
          plannedByTone: [
            for (final tone in Tone.values)
              (
                tone: tone,
                plannedMinutes: plannedByToneIndex[tone.dbIndex] ?? 0,
                completedMinutes: completedByTone[tone] ?? 0,
              ),
          ],
          focus: FocusDepth(
            minutes: focusSeconds ~/ 60,
            longestSeconds: instants.fold(
              0,
              (longest, instant) => instant.activeSeconds > longest
                  ? instant.activeSeconds
                  : longest,
            ),
            averageSeconds: instants.isEmpty
                ? 0
                : focusSeconds ~/ instants.length,
            ended: outcomes.ended,
            abandoned: outcomes.abandoned,
          ),
          focusInstants: instants,
        ),
        plannedByDay: {
          for (final row in plannedDayRows) row.date: row.minutes,
        },
        currentStreak: evaluated.current,
        focusTargetMinutes: stored ?? defaultDailyFocusTargetMinutes,
        endedSessions: endedSessions,
        abandonedAfter16: abandonedAfter16,
        inboxAfter16: inboxAfter16,
        toneShare: {
          for (final row in plannedTone)
            Tone.fromDbIndex(row.toneIndex).label: row.minutes,
        },
        streakRisk:
            evaluated.current > 0 &&
            qualifying.every((day) => day != sunday),
        weeklyFocusMinutes: weeklyFocusMinutes,
        projectActualMinutes: projectSeconds ~/ 60,
      ),
    );
    if (cards.isEmpty) return;
    for (final card in cards) {
      await _db.coachDao.insertInsight(
        isoYear: isoYear,
        isoWeek: isoWeek,
        kind: card.kind,
        payloadJson: jsonEncode(card.toJson()),
      );
    }
  }
}
