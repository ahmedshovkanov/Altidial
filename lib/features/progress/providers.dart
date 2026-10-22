import 'package:altidial/core/roundup/roundup_payload.dart';
import 'package:altidial/core/time/day_time.dart';
import 'package:altidial/data/database.dart';
import 'package:altidial/data/providers.dart';
import 'package:altidial/data/repositories/roundup_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The cached progress row: level, XP and streaks.
final progressRowProvider = StreamProvider<ProgressRow?>((ref) {
  return ref.watch(progressRepositoryProvider).watchProgress();
});

/// Today's cached day score.
final todayScoreProvider = StreamProvider<DayScoreRow?>((ref) {
  return ref
      .watch(progressRepositoryProvider)
      .watchDayScore(startOfDay(DateTime.now()));
});

/// Badge unlocks, oldest first.
final unlockedBadgesProvider = StreamProvider<List<BadgeUnlockRow>>((ref) {
  return ref.watch(progressRepositoryProvider).watchBadges();
});

/// The roundup archive, newest first. Reading it generates missing weeks.
final roundupArchiveProvider = StreamProvider<List<RoundupSummary>>((ref) {
  return ref.watch(roundupRepositoryProvider).watchArchive();
});

/// One frozen roundup, or null when it was never generated or no longer
/// parses.
final roundupPayloadProvider =
    FutureProvider.family<RoundupPayload?, ({int year, int week})>((ref, key) {
      return ref.watch(roundupRepositoryProvider).payload(key.year, key.week);
    });
