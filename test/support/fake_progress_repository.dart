import 'dart:async';

import 'package:energy_clock/data/database.dart';
import 'package:energy_clock/data/repositories/progress_repository.dart';

/// In-memory [ProgressRepository] for widget tests. Tests seed [progress],
/// [scores] and [badges] (or call the setters, which re-emit) and read the
/// call counters to assert the triggers fired.
class FakeProgressRepository implements ProgressRepository {
  FakeProgressRepository({
    ProgressRow? progress,
    Map<DateTime, DayScoreRow>? scores,
    List<BadgeUnlockRow>? badges,
  }) : progress =
           progress ??
           ProgressRow(
             id: 1,
             xp: 0,
             level: 1,
             currentStreak: 0,
             longestStreak: 0,
           ),
       scores = scores ?? {},
       badges = badges ?? [];

  ProgressRow? progress;
  final Map<DateTime, DayScoreRow> scores;
  final List<BadgeUnlockRow> badges;

  int ensureFreshCalls = 0;
  int recalculateAllCalls = 0;

  /// Makes [onSessionEnded] throw, as an unwritable database would.
  bool failOnSessionEnded = false;

  /// Every `eventDate` passed to [onSessionEnded].
  final List<DateTime> endedDates = [];

  final _progressUpdates = StreamController<ProgressRow?>.broadcast();
  final _scoreUpdates =
      StreamController<({DateTime date, DayScoreRow? score})>.broadcast();
  final _badgeUpdates = StreamController<List<BadgeUnlockRow>>.broadcast();

  @override
  Stream<ProgressRow?> watchProgress() async* {
    yield progress;
    yield* _progressUpdates.stream;
  }

  @override
  Stream<DayScoreRow?> watchDayScore(DateTime date) async* {
    yield scores[date];
    await for (final update in _scoreUpdates.stream) {
      if (update.date == date) yield update.score;
    }
  }

  @override
  Stream<List<BadgeUnlockRow>> watchBadges() async* {
    yield badges;
    yield* _badgeUpdates.stream;
  }

  @override
  Future<void> onSessionEnded(DateTime eventDate) async {
    if (failOnSessionEnded) throw StateError('progress is unwritable');
    endedDates.add(eventDate);
  }

  @override
  Future<void> ensureFresh() async {
    ensureFreshCalls++;
  }

  @override
  Future<void> recalculateAll() async {
    recalculateAllCalls++;
  }

  void setProgress(ProgressRow? row) {
    progress = row;
    _progressUpdates.add(row);
  }

  void setScore(DateTime date, DayScoreRow? score) {
    if (score == null) {
      scores.remove(date);
    } else {
      scores[date] = score;
    }
    _scoreUpdates.add((date: date, score: score));
  }

  void emitBadges(List<BadgeUnlockRow> rows) {
    badges
      ..clear()
      ..addAll(rows);
    _badgeUpdates.add(badges);
  }

  void dispose() {
    _progressUpdates.close();
    _scoreUpdates.close();
    _badgeUpdates.close();
  }
}
