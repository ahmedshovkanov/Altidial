import 'package:drift/drift.dart';
import 'package:energy_clock/core/progress/badges.dart';
import 'package:energy_clock/core/progress/score.dart';
import 'package:energy_clock/core/progress/streak.dart';
import 'package:energy_clock/core/progress/xp.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';

/// What Profile reads and what the session screen advances.
abstract interface class ProgressRepository {
  Stream<ProgressRow?> watchProgress();
  Stream<DayScoreRow?> watchDayScore(DateTime date);
  Stream<List<BadgeUnlockRow>> watchBadges();

  /// A session on [eventDate] just ended: finalise that day (and today, if
  /// different), then recompute streaks, XP, level and badges.
  Future<void> onSessionEnded(DateTime eventDate);

  /// After launch and when the app returns to the foreground: finalise
  /// yesterday if the day has rolled over, then recompute today.
  Future<void> ensureFresh();

  /// Wipe the caches and rebuild every day from source. Past edits never
  /// trigger this on their own; only the Profile row calls it.
  Future<void> recalculateAll();
}

class DriftProgressRepository implements ProgressRepository {
  DriftProgressRepository(
    this._db, {
    DateTime Function()? now,
    Future<int?> Function()? readFocusTarget,
  }) : _now = now ?? DateTime.now {
    _readFocusTarget = readFocusTarget;
  }

  final AppDatabase _db;
  final DateTime Function() _now;
  late final Future<int?> Function()? _readFocusTarget;

  /// The settings table's stored target, or null. The key is declared as
  /// `dailyFocusTargetKey` in `lib/app/settings/settings_providers.dart`;
  /// the literal stays here so `lib/data/` never imports `lib/app/`.
  Future<int> _focusTarget() async {
    final read = _readFocusTarget;
    final stored = read == null
        ? int.tryParse(
            await _db.settingsDao.valueFor('daily_focus_target') ?? '',
          )
        : await read();
    return stored ?? defaultDailyFocusTargetMinutes;
  }

  @override
  Stream<ProgressRow?> watchProgress() => _db.progressDao.watchProgress();

  @override
  Stream<DayScoreRow?> watchDayScore(DateTime date) =>
      _db.progressDao.watchDayScore(date);

  @override
  Stream<List<BadgeUnlockRow>> watchBadges() => _db.progressDao.watchBadges();

  @override
  Future<void> onSessionEnded(DateTime eventDate) => _db.transaction(() async {
    final day = startOfDay(eventDate);
    final today = startOfDay(_now());
    await _recalcDay(day);
    if (day != today) await _recalcDay(today);
    await _recompute(today);
  });

  @override
  Future<void> ensureFresh() => _db.transaction(() async {
    final today = startOfDay(_now());
    final last = (await _db.progressDao.progressRow())?.lastStreakDate;
    if (last == null || last.isBefore(previousDay(today))) {
      // The day has rolled over (or nothing was ever computed): finalise
      // yesterday — `_recalcDay` writes nothing when the day has no data —
      // then recompute today.
      await _recalcDay(previousDay(today));
    }
    if (last == null || last.isBefore(today)) {
      await _recalcDay(today);
      await _recompute(today);
    }
  });

  @override
  Future<void> recalculateAll() => _db.transaction(() async {
    await _db.progressDao.clearDayScores();
    for (final date in await _db.progressDao.datesWithData()) {
      await _recalcDay(date);
    }
    await _recompute(startOfDay(_now()));
  });

  /// Scores [day] from source and upserts its row — or deletes the row when
  /// the day holds nothing. Never touches any other day.
  Future<void> _recalcDay(DateTime day) async {
    final next = nextDay(day);
    final cells = await _db.statsDao.toneSecondsByDay(day, next);
    final plannedRows = await _db.progressDao.plannedMinutesByDay(day, next);
    var focus = 0;
    var life = 0;
    var inbox = 0;
    for (final cell in cells) {
      final minutes = cell.seconds ~/ 60;
      switch (Tone.fromDbIndex(cell.toneIndex)) {
        case Tone.focus:
          focus += minutes;
        case Tone.life:
          life += minutes;
        case Tone.inbox:
          inbox += minutes;
      }
    }
    final planned = plannedRows.fold(0, (sum, row) => sum + row.minutes);
    final completed = focus + life + inbox;
    if (planned == 0 && completed == 0) {
      await _db.progressDao.deleteDayScore(day);
      return;
    }
    final score = scoreFor(
      day: (
        focus: focus,
        life: life,
        inbox: inbox,
        planned: planned,
        completed: completed,
      ),
      focusTargetMinutes: await _focusTarget(),
    );
    await _db.progressDao.upsertDayScore(
      DayScoresCompanion.insert(
        date: day,
        energyScore: score.total,
        adherencePoints: score.adherencePoints,
        focusPoints: score.focusPoints,
        balancePoints: score.balancePoints,
        focusMinutes: Value(focus),
        lifeMinutes: Value(life),
        inboxMinutes: Value(inbox),
        plannedMinutes: Value(planned),
        completedMinutes: Value(completed),
        computedAt: _now(),
      ),
    );
  }

  /// Recomputes streaks, XP, level and badge unlocks from source for [today].
  Future<void> _recompute(DateTime today) async {
    final dao = _db.progressDao;
    final qualifying = await dao.qualifyingDates();
    final evaluated = streaks(qualifying, today: today);

    var sessionPoints = 0;
    for (final input in await dao.sessionXpInputs()) {
      sessionPoints += sessionXpMinutes(
        input.seconds ~/ 60,
        focus: input.toneIndex == Tone.focus.dbIndex,
      );
    }

    final unlocked = await dao.unlockedBadgeIds();
    final fresh = badgesToUnlock(
      BadgeFacts(
        endedSessions: await dao.endedSessionCount(),
        qualifyingDates: qualifying,
        fourHourFocusDays: {
          for (final row in await dao.focusSecondsByDay())
            if (row.seconds >= 4 * 3600) row.date,
        },
        allToneWeeks: _weeksWithAllTones(await dao.tonePresence()),
        cleanWeeks: _cleanWeeks(await dao.dayOutcomes()),
        hasEarlyFocus: (await dao.focusStartTimes()).any(
          (started) => started.hour < 8,
        ),
      ),
      unlocked.toSet(),
    );
    if (fresh.isNotEmpty) await dao.unlockBadges(fresh, _now());

    final total =
        sessionPoints +
        badgeXp(unlocked.length + fresh.length) +
        streakXp(qualifying);
    await dao.upsertProgress(
      ProgressCompanion.insert(
        id: const Value(1),
        xp: Value(total),
        level: Value(levelForXp(total)),
        currentStreak: Value(evaluated.current),
        longestStreak: Value(evaluated.longest),
        lastStreakDate: Value(today),
      ),
    );
  }

  /// Monday starts of weeks whose `countsAsDone` minutes touch all three
  /// tones. Weeks are Monday-based here regardless of the first-day setting.
  Set<DateTime> _weeksWithAllTones(
    List<({DateTime date, int toneIndex, int seconds})> cells,
  ) {
    final byWeek = <DateTime, Set<int>>{};
    for (final cell in cells) {
      if (cell.seconds <= 0) continue;
      (byWeek[startOfWeek(cell.date)] ??= {}).add(cell.toneIndex);
    }
    return {
      for (final entry in byWeek.entries)
        if (entry.value.length >= 3) entry.key,
    };
  }

  /// Monday starts of weeks with at least one ended session and none
  /// abandoned, over every tone.
  Set<DateTime> _cleanWeeks(
    List<({DateTime date, int ended, int abandoned})> days,
  ) {
    final byWeek = <DateTime, ({int ended, int abandoned})>{};
    for (final day in days) {
      final week = startOfWeek(day.date);
      final acc = byWeek[week] ?? (ended: 0, abandoned: 0);
      byWeek[week] = (
        ended: acc.ended + day.ended,
        abandoned: acc.abandoned + day.abandoned,
      );
    }
    return {
      for (final entry in byWeek.entries)
        if (entry.value.ended > 0 && entry.value.abandoned == 0) entry.key,
    };
  }
}
