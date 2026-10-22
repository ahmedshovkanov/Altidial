import 'dart:convert';

import 'package:energy_clock/core/progress/streak.dart';
import 'package:energy_clock/core/progress/xp.dart';
import 'package:energy_clock/core/roundup/iso_week.dart';
import 'package:energy_clock/core/roundup/roundup_payload.dart';
import 'package:energy_clock/core/time/day_time.dart';
import 'package:energy_clock/core/tone.dart';
import 'package:energy_clock/data/database.dart';

/// One archived week: its ISO number and when it was generated.
typedef RoundupSummary = ({int isoYear, int isoWeek, DateTime generatedAt});

/// What Profile's archive reads. Finished weeks generate their frozen payload
/// on first read; the current week never generates (spec §9.6).
abstract interface class RoundupRepository {
  /// Generates every missing finished week, then emits the archive newest
  /// first, re-emitting on every database change.
  Stream<List<RoundupSummary>> watchArchive();

  /// The frozen payload, or null when the week was never generated or its
  /// JSON no longer parses.
  Future<RoundupPayload?> payload(int isoYear, int isoWeek);

  /// Generates every finished week that has no row yet.
  Future<void> ensureCurrent();
}

class DriftRoundupRepository implements RoundupRepository {
  DriftRoundupRepository(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  @override
  Stream<List<RoundupSummary>> watchArchive() async* {
    await ensureCurrent();
    yield* _db.roundupDao.watchArchive().map(
      (rows) => [
        for (final row in rows)
          (
            isoYear: row.isoYear,
            isoWeek: row.isoWeek,
            generatedAt: row.generatedAt,
          ),
      ],
    );
  }

  @override
  Future<RoundupPayload?> payload(int isoYear, int isoWeek) async {
    final row = await _db.roundupDao.roundupFor(isoYear, isoWeek);
    if (row == null) return null;
    try {
      return RoundupPayload.fromJson(
        Map<String, Object?>.from(jsonDecode(row.payloadJson) as Map),
      );
    } on Object {
      // A corrupt row archives as unopenable, never as a crash.
      return null;
    }
  }

  @override
  Future<void> ensureCurrent() => _db.transaction(() async {
    final today = startOfDay(_now());
    final dataDates = await _db.progressDao.datesWithData();
    if (dataDates.isEmpty) return;

    final first = isoWeekOf(dataDates.first);
    final firstStart = isoWeekStart(first.year, first.week);

    final current = isoWeekOf(today);
    final currentStart = isoWeekStart(current.year, current.week);

    var week = firstStart;
    while (week.isBefore(currentStart)) {
      final number = isoWeekOf(week);
      if (await _db.roundupDao.roundupFor(number.year, number.week) == null) {
        await _generate(number.year, number.week, week);
      }
      week = DateTime(week.year, week.month, week.day + 7);
    }
  });

  /// Builds and stores one finished week's frozen payload.
  Future<void> _generate(int isoYear, int isoWeek, DateTime start) async {
    final end = DateTime(start.year, start.month, start.day + 7);
    final cells = await _db.statsDao.toneSecondsByDay(start, end);
    final plannedRows = await _db.progressDao.plannedMinutesByDay(start, end);

    final completedByTone = <Tone, int>{};
    var bestDay = 0;
    var bestDate = start;
    for (final cell in cells) {
      final minutes = cell.seconds ~/ 60;
      final tone = Tone.fromDbIndex(cell.toneIndex);
      completedByTone[tone] = (completedByTone[tone] ?? 0) + minutes;
      if (tone == Tone.focus && minutes > bestDay) {
        bestDay = minutes;
        bestDate = cell.date;
      }
    }
    final planned = plannedRows.fold(0, (sum, row) => sum + row.minutes);
    final completed = completedByTone.values.fold(0, (a, b) => a + b);

    final sunday = DateTime(end.year, end.month, end.day - 1);
    final qualifying = (await _db.progressDao.qualifyingDates())
        .where((day) => !day.isAfter(sunday))
        .toList();
    final evaluated = streaks(qualifying, today: sunday);

    final unlocks = await _db.roundupDao.unlocksInWeek(start, end);
    var sessionPoints = 0;
    for (final cell in cells) {
      sessionPoints += sessionXpMinutes(
        cell.seconds ~/ 60,
        focus: cell.toneIndex == Tone.focus.dbIndex,
      );
    }

    final previousStart = DateTime(start.year, start.month, start.day - 7);
    final previousAdherence = await _adherence(previousStart, start);

    await _db.roundupDao.insertRoundup(
      isoYear: isoYear,
      isoWeek: isoWeek,
      payloadJson: jsonEncode(
        RoundupPayload(
          isoYear: isoYear,
          isoWeek: isoWeek,
          weekStart: start,
          adherencePercent: planned == 0
              ? null
              : (completed * 100 / planned).round(),
          plannedMinutes: planned,
          completedMinutes: completed,
          totalMinutes: completed,
          focusMinutes: completedByTone[Tone.focus] ?? 0,
          lifeMinutes: completedByTone[Tone.life] ?? 0,
          inboxMinutes: completedByTone[Tone.inbox] ?? 0,
          bestFocusDay: bestDay == 0 ? null : bestDate,
          bestFocusMinutes: bestDay,
          currentStreak: evaluated.current,
          longestStreak: evaluated.longest,
          badgesUnlocked: unlocks,
          xpEarned: sessionPoints + badgeXp(unlocks.length),
          previousAdherencePercent: previousAdherence,
        ).toJson(),
      ),
      generatedAt: _now(),
    );
  }

  /// One week's adherence without writing a row: null when nothing was
  /// planned.
  Future<int?> _adherence(DateTime from, DateTime toExclusive) async {
    final cells = await _db.statsDao.toneSecondsByDay(from, toExclusive);
    final plannedRows = await _db.progressDao.plannedMinutesByDay(
      from,
      toExclusive,
    );
    final planned = plannedRows.fold(0, (sum, row) => sum + row.minutes);
    if (planned == 0) return null;
    final completed = cells.fold(0, (sum, cell) => sum + cell.seconds ~/ 60);
    return (completed * 100 / planned).round();
  }
}
